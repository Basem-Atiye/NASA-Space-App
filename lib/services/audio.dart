import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'progress.dart';

enum Sfx { tap, message, alert, success, fail, star, storm, type, step, breath, radio, sparkle, boop }

/// Sound effects, ambient loops and vibration. Every call is safe to make
/// even if audio fails on a device: errors are swallowed so the game never
/// stops because of sound.
class Audio {
  final Progress progress;
  final List<AudioPlayer> _pool = [];
  int _next = 0;
  AudioPlayer? _music;
  AudioPlayer? _hum;
  AudioPlayer? _alarm;
  bool _alarmOn = false;
  String? _ambient; // 'music' or 'hum'

  Audio(this.progress);

  Future<void> init() async {
    try {
      for (int i = 0; i < 4; i++) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        _pool.add(p);
      }
      _music = AudioPlayer();
      await _music!.setReleaseMode(ReleaseMode.loop);
      _hum = AudioPlayer();
      await _hum!.setReleaseMode(ReleaseMode.loop);
      _alarm = AudioPlayer();
      await _alarm!.setReleaseMode(ReleaseMode.loop);
      await _initTicks();
    } catch (_) {}
  }

  String _file(Sfx s) {
    switch (s) {
      case Sfx.tap:
        return 'sounds/tap.wav';
      case Sfx.message:
        return 'sounds/message.wav';
      case Sfx.alert:
        return 'sounds/alert.wav';
      case Sfx.success:
        return 'sounds/success.wav';
      case Sfx.fail:
        return 'sounds/fail.wav';
      case Sfx.star:
        return 'sounds/star.wav';
      case Sfx.storm:
        return 'sounds/storm.wav';
      case Sfx.type:
        return 'sounds/type.wav';
      case Sfx.step:
        return 'sounds/step.wav';
      case Sfx.breath:
        return 'sounds/breath.wav';
      case Sfx.radio:
        return 'sounds/radio.wav';
      case Sfx.sparkle:
        return 'sounds/sparkle.wav';
      case Sfx.boop:
        return 'sounds/boop.wav';
    }
  }

  // Typing clicks and footsteps have their own small players, so they never
  // cut off a real sound effect, and they are rate-limited.
  final List<AudioPlayer> _tick = [];
  int _tickNext = 0;
  int _lastTypeMs = 0;
  int _lastStepMs = 0;

  Future<void> _initTicks() async {
    for (var i = 0; i < 3; i++) {
      final p = AudioPlayer();
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      _tick.add(p);
    }
  }

  void _tickPlay(Sfx s, double volume) {
    if (_tick.isEmpty) return;
    final p = _tick[_tickNext];
    _tickNext = (_tickNext + 1) % _tick.length;
    try {
      p.stop().then((_) => p.play(AssetSource(_file(s)), volume: volume)).catchError((_) {});
    } catch (_) {}
  }

  /// One soft click while a message types itself (at most ~14 per second).
  /// Very quiet while read-aloud is speaking.
  void typeClick() {
    if (!progress.sound || !progress.typingSound) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTypeMs < 70) return;
    _lastTypeMs = now;
    _tickPlay(Sfx.type, progress.voiceOn ? 0.07 : 0.3);
  }

  /// A footstep heard through the suit.
  void footstep({bool hard = false}) {
    if (!progress.sound) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastStepMs < 160) return;
    _lastStepMs = now;
    _tickPlay(Sfx.step, hard ? 0.45 : 0.22);
  }

  void play(Sfx s, {double volume = 0.8}) {
    if (!progress.sound || _pool.isEmpty) return;
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    try {
      p.stop().then((_) => p.play(AssetSource(_file(s)), volume: volume)).catchError((_) {});
    } catch (_) {}
  }

  void tap() {
    play(Sfx.tap, volume: 0.5);
    haptic(light: true);
  }

  void haptic({bool light = false, bool heavy = false}) {
    if (!progress.haptics) return;
    try {
      if (heavy) {
        HapticFeedback.heavyImpact();
      } else if (light) {
        HapticFeedback.selectionClick();
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }

  /// 'music' on menus, 'hum' inside the base, null for silence.
  Future<void> ambient(String? which) async {
    if (_ambient == which && (which == null || _isPlayingAllowed(which))) return;
    _ambient = which;
    await _applyAmbient();
  }

  bool _isPlayingAllowed(String which) => which == 'music' ? progress.music : progress.sound;

  Future<void> _applyAmbient() async {
    try {
      final m = _music, h = _hum;
      if (m == null || h == null) return;
      if (_ambient == 'music' && progress.music) {
        await h.stop();
        if (m.state != PlayerState.playing) await m.play(AssetSource('sounds/music.wav'), volume: 0.45);
      } else if (_ambient == 'hum' && progress.sound) {
        await m.stop();
        if (h.state != PlayerState.playing) await h.play(AssetSource('sounds/hum.wav'), volume: 0.35);
      } else {
        await m.stop();
        await h.stop();
      }
    } catch (_) {}
  }

  Future<void> refreshSettings() async {
    await _applyAmbient();
    if (!progress.sound) await alarm(false);
  }

  Future<void> alarm(bool on) async {
    if (on == _alarmOn) return;
    _alarmOn = on;
    try {
      final a = _alarm;
      if (a == null) return;
      if (on && progress.sound) {
        await a.play(AssetSource('sounds/alarm.wav'), volume: 0.28);
      } else {
        await a.stop();
      }
    } catch (_) {}
  }

  Future<void> pauseAll() async {
    try {
      await _music?.pause();
      await _hum?.pause();
      await _alarm?.pause();
    } catch (_) {}
  }

  Future<void> resumeAll() async {
    try {
      if (_ambient == 'music' && progress.music) await _music?.resume();
      if (_ambient == 'hum' && progress.sound) await _hum?.resume();
      if (_alarmOn && progress.sound) await _alarm?.resume();
    } catch (_) {}
  }
}
