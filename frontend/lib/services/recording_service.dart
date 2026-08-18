import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordingService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Starts mic audio recording
  Future<void> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        final String path = '${tempDir.path}/user_attempt_${DateTime.now().millisecondsSinceEpoch}.wav';

        const RecordConfig config = RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        );

        await _audioRecorder.start(config, path: path);
        _isRecording = true;
      }
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  /// Stops recording and returns recorded File
  Future<File?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      final String? path = await _audioRecorder.stop();
      _isRecording = false;

      if (path != null) {
        return File(path);
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
    return null;
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}
