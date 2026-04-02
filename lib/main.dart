import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Remover',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _status = 'اضغط لرفع ملف صوتي أو فيديو';
  bool _isLoading = false;
  Uint8List? _fileBytes;
  String? _fileName;
  Uint8List? _audioBytes;
  bool _isVideo = false;
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'mp4', 'wav', 'aac', 'm4a'],
      withData: true,
    );

    if (result != null) {
      final file = result.files.single;
      Uint8List? bytes = file.bytes;

      if (bytes == null && file.path != null && !kIsWeb) {
        bytes = await File(file.path!).readAsBytes();
      }

      setState(() {
        _fileBytes = bytes;
        _fileName = file.name;
        _status = 'تم اختيار: ${file.name}';
        _audioBytes = null;
        _isPlaying = false;
        _isVideo = false;
      });
    }
  }

  Future<void> _removeMusic() async {
    if (_fileBytes == null) {
      setState(() => _status = 'اختر ملفاً أولاً!');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'جارٍ إزالة الموسيقى...';
    });

    try {
      final uri = Uri.parse(
        'https://zeyad636-music-remover.hf.space/remove-music',
      );
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes('file', _fileBytes!, filename: _fileName!),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();
        setState(() {
          _audioBytes = bytes;
          _isVideo = _fileName!.toLowerCase().endsWith('.mp4');
          _status = 'تم! اضغط تشغيل أو حفظ أو مشاركة ✓';
        });
      } else {
        setState(() => _status = 'حدث خطأ! حاول مرة ثانية.');
      }
    } catch (e) {
      setState(() => _status = 'خطأ في الاتصال بالسيرفر: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveFile() async {
    if (_audioBytes == null) return;
    if (kIsWeb) {
      setState(() => _status = 'التحميل غير مدعوم على الويب');
      return;
    }
    final dir = Directory('/storage/emulated/0/Download');
    final fileName = _isVideo
        ? 'video_no_music_${DateTime.now().millisecondsSinceEpoch}.mp4'
        : 'audio_no_music_${DateTime.now().millisecondsSinceEpoch}.wav';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(_audioBytes!);
    setState(() => _status = 'تم الحفظ في Downloads ✓');
  }

  Future<void> _saveAndShare() async {
    if (_audioBytes == null) return;
    final dir = await getTemporaryDirectory();
    final fileName = _isVideo ? 'video_no_music.mp4' : 'audio_no_music.wav';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(_audioBytes!);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'مقطع بدون موسيقى - Music Remover',
      ),
    );
  }

  Future<void> _togglePlay() async {
    if (_audioBytes == null) return;
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.setAudioSource(
        AudioSource.uri(Uri.dataFromBytes(_audioBytes!, mimeType: 'audio/wav')),
      );
      await _player.play();
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Music Remover',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 60),
              GestureDetector(
                onTap: _isLoading ? null : _removeMusic,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF7C5CFF), Color(0xFF2A1880)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C5CFF).withOpacity(0.4),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Icon(
                          Icons.music_off,
                          size: 64,
                          color: Colors.white,
                        ),
                ),
              ),
              const SizedBox(height: 40),
              TextButton.icon(
                onPressed: _isLoading ? null : _pickFile,
                icon: const Icon(Icons.upload_file, color: Color(0xFF7C5CFF)),
                label: const Text(
                  'اختر ملف',
                  style: TextStyle(color: Color(0xFF7C5CFF), fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
              if (_audioBytes != null) ...[
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_isVideo)
                      GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green.withOpacity(0.2),
                            border: Border.all(color: Colors.green, width: 2),
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.green,
                            size: 36,
                          ),
                        ),
                      ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: _saveFile,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orange.withOpacity(0.2),
                          border: Border.all(color: Colors.orange, width: 2),
                        ),
                        child: const Icon(
                          Icons.download,
                          color: Colors.orange,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: _saveAndShare,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.withOpacity(0.2),
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: const Icon(
                          Icons.share,
                          color: Colors.blue,
                          size: 36,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
