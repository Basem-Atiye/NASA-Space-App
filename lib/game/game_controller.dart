import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../data/messages.dart';
import '../engine/constants.dart';
import '../engine/mission.dart';
import '../engine/simulation.dart';
import '../services/audio.dart';
import '../services/progress.dart';
import '../ui/theme.dart';

class FeedItem {
  final GameMessage message;
  final int hour;
  final bool isReply;
  const FeedItem(this.message, this.hour, {this.isReply = false});
}

class BannerInfo {
  final String text;
  final Color color;
  final IconData icon;
  final int id;
  const BannerInfo(this.text, this.color, this.icon, this.id);
}

/// Runs one mission in real time: ticks the simulation, turns engine signals
/// into messages, banners, sound and vibration, and keeps the 2D base view in sync.
class GameController extends ChangeNotifier {
  final MissionConfig mission;
  final Audio audio;
  final Progress progress;
  late MissionSim sim;

  int speed = 1; // 1, 2 or 4
  bool userPaused = false;
  bool sheetOpen = false;
  bool finished = false;
  int stars = 0;

  final List<FeedItem> feed = [];
  final Queue<GameMessage> modalQueue = Queue();
  GameMessage? get modal => modalQueue.isEmpty ? null : modalQueue.first;
  List<CargoChoice>? get cargo => sim.pendingCargo;

  BannerInfo? banner;
  int _bannerId = 0;
  int shake = 0; // increments to trigger a screen shake
  int shakeStrength = 1;

  final Map<String, int> _ruleFired = {};
  final Set<int> _scriptFired = {};
  String? _memoryFlag;
  Timer? _timer;
  double _acc = 0;
  int _syncCounter = 0;
  bool _alarm = false;

  GameController({required this.mission, required this.audio, required this.progress}) {
    _setup();
  }

  void _setup() {
    sim = MissionSim(mission);
    feed.clear();
    modalQueue.clear();
    _ruleFired.clear();
    _scriptFired.clear();
    finished = false;
    stars = 0;
    userPaused = false;
    _acc = 0;
    banner = null;
    // Nova remembers one earlier event and mentions it early in the mission.
    _memoryFlag = null;
    for (final line in memoryLines) {
      if (progress.memory.contains(line.flag) && !progress.memoryUsed.contains(line.flag)) {
        _memoryFlag = line.flag;
        break;
      }
    }
    _fireScripted();
    _syncScene(force: true);
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => _frame(0.05));
    audio.ambient('hum');
  }

  /// Stops the clock and the alarm (used when the player quits).
  void stop() {
    _timer?.cancel();
    audio.alarm(false);
    _alarm = false;
  }

  void restart() {
    _setup();
    audio.alarm(false);
    _alarm = false;
    start();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    audio.alarm(false);
    super.dispose();
  }

  bool get running => !finished && !userPaused && !sheetOpen && modal == null && cargo == null;

  /// 0..1 progress through the current game hour (for smooth animation).
  double get hourFraction => (_acc / secondsPerGameHour).clamp(0.0, 1.0).toDouble();

  // ------------------------------------------------------------------ loop

  void _frame(double dt) {
    if (running) {
      _acc += dt * speed;
      while (_acc >= secondsPerGameHour && !finished) {
        _acc -= secondsPerGameHour;
        _tick();
      }
    }
    _syncCounter++;
    if (_syncCounter % 4 == 0) {
      _syncScene();
      if (sim.onEva && running) notifyListeners();
    }
  }

  void _tick() {
    final signals = sim.tick();
    for (final s in signals) {
      _handleSignal(s);
    }
    _fireScripted();
    if (sim.hour == 3 && _memoryFlag != null) {
      final line = memoryLines.firstWhere((l) => l.flag == _memoryFlag);
      _post(line.message);
      progress.markMemoryUsed(line.flag);
      _memoryFlag = null;
    }
    _checkRules();
    _updateAlarm();
    if (sim.outcome != Outcome.running) _finish();
    notifyListeners();
  }

  void _fireScripted() {
    final list = scripted[mission.id];
    if (list == null) return;
    for (int i = 0; i < list.length; i++) {
      final s = list[i];
      if (s.hour == sim.hour && !_scriptFired.contains(i)) {
        _scriptFired.add(i);
        final msg = s.message;
        final important = msg.important && (progress.tutorialHints || msg.speaker == Speaker.nova);
        _post(important ? msg : GameMessage(msg.speaker, msg.text, mood: msg.mood, replies: msg.replies));
      }
    }
  }

  void _checkRules() {
    for (final r in rules) {
      final last = _ruleFired[r.id];
      if (last != null && sim.hour - last < r.cooldown) continue;
      if (r.when(sim)) {
        _ruleFired[r.id] = sim.hour;
        _post(r.build(sim));
        return; // at most one rule message per hour
      }
    }
  }

  void _post(GameMessage m) {
    feed.add(FeedItem(m, sim.hour));
    if (m.important) {
      modalQueue.add(m);
      audio.play(Sfx.alert, volume: 0.6);
      audio.haptic();
    } else {
      audio.play(Sfx.message, volume: 0.55);
    }
  }

  void _showBanner(String text, Color color, IconData icon, {int shakeLevel = 0}) {
    banner = BannerInfo(text, color, icon, ++_bannerId);
    if (shakeLevel > 0) {
      shake++;
      shakeStrength = shakeLevel;
    }
  }

  void _handleSignal(Signal s) {
    final msg = messageForSignal(s, sim);
    switch (s.type) {
      case SignalType.stormWarning:
        _showBanner('SOLAR FLARE DETECTED  ·  ${s.storm?.flareClass ?? ''}', C.amber, Icons.wb_sunny_rounded, shakeLevel: 1);
        audio.haptic(heavy: true);
        break;
      case SignalType.stormStart:
        _showBanner('PROTON STORM ACTIVE', C.red, Icons.flare_rounded, shakeLevel: 3);
        audio.play(Sfx.storm, volume: 0.9);
        audio.haptic(heavy: true);
        break;
      case SignalType.stormEnd:
        _showBanner('STORM PASSED', C.green, Icons.check_circle_rounded);
        audio.play(Sfx.success, volume: 0.5);
        break;
      case SignalType.failure:
        _showBanner('${systemName(s.system ?? SystemId.electrolyzer).toUpperCase()} FAILURE', C.red, Icons.build_circle_rounded, shakeLevel: 2);
        audio.haptic(heavy: true);
        break;
      case SignalType.repaired:
        _showBanner('REPAIRED: ${systemName(s.system ?? SystemId.electrolyzer).toUpperCase()}', C.green, Icons.handyman_rounded);
        audio.play(Sfx.star, volume: 0.6);
        break;
      case SignalType.harvest:
        _showBanner('HARVEST  +${Rates.greenhouseHarvestKg} KG FOOD', C.green, Icons.eco_rounded);
        audio.play(Sfx.star, volume: 0.6);
        break;
      case SignalType.evaComplete:
        _showBanner('EVA COMPLETE', C.cyan, Icons.directions_walk_rounded);
        audio.play(Sfx.success, volume: 0.5);
        break;
      case SignalType.evaRecalled:
        break;
      case SignalType.brownout:
        _showBanner('BATTERY EMPTY  ·  SYSTEMS OFF', C.red, Icons.battery_alert_rounded, shakeLevel: 2);
        audio.haptic(heavy: true);
        break;
      case SignalType.nightStart:
        _showBanner('SUNSET  ·  RUNNING ON BATTERY', C.violet, Icons.nightlight_round);
        break;
      case SignalType.dayStart:
        _showBanner('SUNRISE  ·  SOLAR POWER BACK', C.amber, Icons.wb_twilight_rounded);
        audio.play(Sfx.success, volume: 0.5);
        break;
      case SignalType.dustStorm:
        _showBanner('DUST ON SOLAR PANELS', C.amber, Icons.grain_rounded);
        break;
      case SignalType.cargoArrived:
        _showBanner('CARGO LANDER ARRIVED', C.cyan, Icons.inventory_2_rounded);
        audio.play(Sfx.alert, volume: 0.6);
        break;
      case SignalType.homeMessage:
        _showBanner('MESSAGE FROM HOME', C.cyan, Icons.favorite_rounded);
        break;
      case SignalType.won:
      case SignalType.lost:
        break;
    }
    if (msg != null) _post(msg);
  }

  void _updateAlarm() {
    final on = sim.outcome == Outcome.running &&
        (sim.o2 <= 0 ||
            (sim.o2HoursLeft ?? 999) < 6 ||
            sim.health < 35 ||
            sim.brownout ||
            sim.water <= 0 ||
            sim.dose > mission.doseLimit * 0.85 ||
            (sim.stormActive && sim.onEva));
    if (on != _alarm) {
      _alarm = on;
      audio.alarm(on);
    }
  }

  bool get alarm => _alarm;

  void _finish() {
    if (finished) return;
    finished = true;
    _timer?.cancel();
    audio.alarm(false);
    stars = sim.starsEarned();
    progress.recordResult(mission.id, stars, memoryFlagsFrom(sim));
    if (sim.outcome == Outcome.won) {
      audio.play(Sfx.success);
    } else {
      audio.play(Sfx.fail);
    }
    _syncScene(force: true);
  }

  // ------------------------------------------------------------------ scene

  void _syncScene({bool force = false}) {
    String storm = 'none';
    if (sim.stormWarning) storm = 'warning';
    if (sim.stormActive) storm = 'active';
    final e = sim.eva;
    double evaProgress = 0;
    if (e != null) {
      final total = evaHours(e);
      evaProgress = ((total - sim.evaLeft) + hourFraction) / total;
    }
    view = {
      'hour': sim.hour,
      'sun': sim.sun,
      'power': sim.batteryCap > 0 ? double.parse((sim.battery / sim.batteryCap).toStringAsFixed(2)) : 0,
      'brownout': sim.brownout,
      'alarm': _alarm,
      'storm': storm,
      'dust': double.parse(sim.dust.toStringAsFixed(2)),
      'greenhouse': mission.hasGreenhouse,
      'greenhouseOn': sim.greenhouseOn,
      'eva': e?.name,
      'evaProgress': double.parse(evaProgress.clamp(0.0, 1.0).toStringAsFixed(3)),
      'berm': sim.berm,
      'panelInstalled': sim.panelInstalled,
      'location': sim.location.name,
      'broken': sim.broken.map((s) => s.name).toList(),
      'mode': 'survival',
      'nova': _novaState(),
    };
  }

  /// What the base view draws (day/night, storm, Nova's room and action...).
  Map<String, Object?> view = const {};

  /// Where Nova walks to and what she does there, so the player can see
  /// every order they give being carried out in the base.
  Map<String, Object?> _novaState() {
    if (sim.eva != null) return {'goal': 'airlock', 'action': 'walk'};
    switch (sim.activity) {
      case Activity.rest:
        return {'goal': 'bench', 'action': sim.sun ? 'rest' : 'hidden'};
      case Activity.repair:
        final t = sim.repairTarget ?? (sim.broken.isEmpty ? null : sim.broken.first);
        return {'goal': t == null ? 'bench' : 'repair_${t.name}', 'action': 'repair'};
      case Activity.greenhouse:
        return {'goal': 'greenhouse', 'action': 'work'};
      case Activity.exercise:
        return {'goal': 'gym', 'action': 'exercise'};
      case Activity.science:
        return {'goal': 'lab', 'action': 'work'};
      case Activity.clean:
        return {'goal': 'panels', 'action': 'clean'};
      case Activity.shelter:
        return {'goal': 'shelter', 'action': 'hidden'};
    }
  }

  // ------------------------------------------------------------------ player actions

  void setSpeed(int s) {
    speed = s;
    userPaused = false;
    audio.tap();
    notifyListeners();
  }

  void togglePause() {
    userPaused = !userPaused;
    audio.tap();
    notifyListeners();
  }

  void setSheetOpen(bool open) {
    sheetOpen = open;
    notifyListeners();
  }

  void dismissModal({Reply? reply}) {
    if (modalQueue.isEmpty) return;
    modalQueue.removeFirst();
    audio.tap();
    if (reply != null) {
      feed.add(FeedItem(GameMessage(Speaker.nova, reply.response, mood: Mood.happy), sim.hour, isReply: true));
    }
    notifyListeners();
  }

  void chooseCargo(CargoChoice c) {
    sim.applyCargo(c);
    audio.play(Sfx.star);
    _post(GameMessage(Speaker.nova, 'Got it. ${cargoName(c)} unpacked and stored.', mood: Mood.happy));
    notifyListeners();
  }

  void setActivity(Activity a) {
    sim.setActivity(a);
    audio.tap();
    if (a == Activity.shelter && sim.storm != null) {
      _post(const GameMessage(Speaker.nova, 'Heading to the shelter now. Bringing a book.', mood: Mood.calm));
    }
    _syncScene();
    notifyListeners();
  }

  String? startEva(EvaTarget t) {
    final reason = sim.canStartEva(t);
    if (reason != null) {
      audio.play(Sfx.alert, volume: 0.4);
      return reason;
    }
    sim.startEva(t);
    audio.play(Sfx.message);
    audio.haptic();
    _post(GameMessage(Speaker.nova, 'Airlock cycling. Heading out: ${evaName(t)}.', mood: Mood.happy));
    _syncScene();
    notifyListeners();
    return null;
  }

  void recallEva() {
    sim.recallEva();
    audio.tap();
    final m = messageForSignal(const Signal(SignalType.evaRecalled), sim);
    if (m != null) _post(m);
    _syncScene();
    notifyListeners();
  }

  void setElectrolyzer(bool on) {
    sim.electrolyzerOn = on;
    audio.tap();
    notifyListeners();
  }

  void setElectrolyzerRate(double r) {
    sim.electrolyzerRate = r.clamp(0.0, 1.0).toDouble();
    if (r > 0) sim.electrolyzerOn = true;
    notifyListeners();
  }

  void setRecycler(bool on) {
    sim.recyclerOn = on;
    audio.tap();
    notifyListeners();
  }

  void setGreenhouse(bool on) {
    sim.greenhouseOn = on;
    audio.tap();
    _syncScene();
    notifyListeners();
  }

  void setHeaters(bool on) {
    sim.heatersOn = on;
    audio.tap();
    notifyListeners();
  }

  void setLab(bool on) {
    sim.labOn = on;
    audio.tap();
    notifyListeners();
  }
}

String formatHours(double? h) {
  if (h == null) return 'stable';
  if (h > 24 * 30) return '30d+';
  if (h >= 48) return '${(h / 24).toStringAsFixed(1)}d';
  final whole = h.floor();
  if (whole >= 24) return '${whole ~/ 24}d ${whole % 24}h';
  if (whole < 1) return '<1h';
  return '${whole}h';
}

String missionClock(int hour) {
  final d = hour ~/ 24 + 1;
  final h = hour % 24;
  return 'DAY $d  ${h.toString().padLeft(2, '0')}:00';
}
