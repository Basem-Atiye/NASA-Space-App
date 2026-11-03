import 'package:flutter_tts/flutter_tts.dart';

import 'progress.dart';

/// Reads lines aloud with the phone's own text-to-speech voice. Always on
/// for Cadets (ages 6–10); a setting for everyone else. Fails silently on
/// devices without a speech engine.
class Voice {
  final Progress progress;
  FlutterTts? _tts;
  bool _ready = false;

  Voice(this.progress);

  bool get enabled => progress.voiceOn;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      final t = FlutterTts();
      await t.setLanguage('en-US');
      await t.setSpeechRate(0.45);
      await t.setPitch(1.0);
      _tts = t;
    } catch (_) {
      _tts = null;
    }
  }

  /// Speaks [text], interrupting whatever was being said.
  Future<void> say(String text) async {
    if (!enabled || text.trim().isEmpty) return;
    await _init();
    try {
      await _tts?.stop();
      await _tts?.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
