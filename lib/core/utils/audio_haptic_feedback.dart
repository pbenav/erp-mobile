import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioHapticFeedback {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static Future<void> playSuccessBeep() async {
    try {
      // Intenta vibrar primero
      await HapticFeedback.mediumImpact();
      // Opcionalmente podemos reproducir un asset local: 
      // await _audioPlayer.play(AssetSource('sounds/success_beep.mp3'));
    } catch (e) {
      debugPrint("Error play beep: $e");
    }
  }

  static Future<void> playErrorBeep() async {
    try {
      await HapticFeedback.heavyImpact();
      // await _audioPlayer.play(AssetSource('sounds/error_beep.mp3'));
    } catch (e) {
      debugPrint("Error play error beep: $e");
    }
  }
}
