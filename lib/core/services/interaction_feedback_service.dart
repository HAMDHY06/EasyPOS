import 'package:flutter/services.dart';

class InteractionFeedbackService {
  const InteractionFeedbackService._();

  static Future<void> barcodeScanned() async {
    await Future.wait([
      SystemSound.play(SystemSoundType.click),
      HapticFeedback.mediumImpact(),
    ]);
  }

  static Future<void> productAdded() async {
    await Future.wait([
      SystemSound.play(SystemSoundType.click),
      HapticFeedback.selectionClick(),
    ]);
  }
}
