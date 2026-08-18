import 'package:just_audio/just_audio.dart';

class AudioPlaybackService {
  final AudioPlayer _player = AudioPlayer();

  /// Plays the custom pronunciation audio provided for a specific alphabet letter (A-Z)
  Future<void> playAlphabetSound(String letter) async {
    try {
      await _player.stop();
      final letterLower = letter.toLowerCase();
      
      // 1. Try loading custom MP3 file provided by user: assets/sounds/a.mp3, b.mp3, etc.
      try {
        await _player.setAsset('assets/sounds/$letterLower.mp3');
        await _player.play();
        return;
      } catch (_) {}

      // 2. Try loading custom WAV file provided by user: assets/sounds/a.wav, b.wav, etc.
      try {
        await _player.setAsset('assets/sounds/$letterLower.wav');
        await _player.play();
        return;
      } catch (_) {}

      // 3. Fallback dev audio stream if asset is not yet placed in folder
      print('Custom audio asset not yet placed for $letter in assets/sounds/, playing dev audio fallback...');
      await _player.setUrl('https://www.soundjay.com/buttons/button-1.mp3');
      await _player.play();

    } catch (e) {
      print('Audio player exception: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
