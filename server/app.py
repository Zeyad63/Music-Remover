import os
import uuid
import subprocess
from flask import Flask, request, send_file, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

UPLOAD_FOLDER = 'uploads'
OUTPUT_FOLDER = 'outputs'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(OUTPUT_FOLDER, exist_ok=True)

@app.route('/remove-music', methods=['POST'])
def remove_music():
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400

    file = request.files['file']
    unique_id = str(uuid.uuid4())
    input_path = os.path.join(UPLOAD_FOLDER, f'{unique_id}_{file.filename}')
    file.save(input_path)

    try:
        wav_path = input_path + '.wav'
        subprocess.run([
            'ffmpeg', '-y', '-i', input_path,
            '-ar', '44100', '-ac', '2', wav_path
        ], check=True)

        subprocess.run([
            'python3', '-m', 'demucs',
            '--two-stems', 'vocals',
            '-o', OUTPUT_FOLDER,
            wav_path
        ], check=True)

        base_name = os.path.splitext(os.path.basename(wav_path))[0]
        vocals_path = os.path.join(OUTPUT_FOLDER, 'htdemucs', base_name, 'vocals.wav')

        is_video = file.filename.lower().endswith(('.mp4', '.mov', '.avi', '.mkv'))

        if is_video:
            output_video = os.path.join(OUTPUT_FOLDER, f'{unique_id}_output.mp4')
            subprocess.run([
                'ffmpeg', '-y',
                '-i', input_path,
                '-i', vocals_path,
                '-c:v', 'copy',
                '-map', '0:v:0',
                '-map', '1:a:0',
                '-shortest',
                output_video
            ], check=True)
            return send_file(output_video, as_attachment=True, download_name='video_no_music.mp4')
        else:
            return send_file(vocals_path, as_attachment=True, download_name='vocals.wav')

    except Exception as e:
        return jsonify({'error': str(e)}), 500

    finally:
        if os.path.exists(input_path):
            os.remove(input_path)

if __name__ == '__main__':
    app.run(debug=False, port=7860, host='0.0.0.0')