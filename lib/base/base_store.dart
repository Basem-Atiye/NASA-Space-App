/// Saves Base Commander progress on the phone: stars per mission, badges,
/// the game in progress, Supply Run bonuses and a short history of runs.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../story/story_model.dart';
import 'base_badges.dart';
import 'base_content.dart';
import 'base_engine.dart';

/// The player's age group as a game level.
Level levelFor(AgeMode m) => switch (m) { AgeMode.cadet => Level.littleExplorer, AgeMode.explorer => Level.explorer, AgeMode.engineer => Level.engineer };

class BaseStore extends ChangeNotifier {
  SharedPreferences? _p;
  final Map<int, int> stars = {};
  final Set<String> earned = {};
  int fixedTotal = 0;
  int supplyRuns = 0;
  int supplyBest = 0;
  StartSupplies? bonus;
  final List<Map<String, dynamic>> runs = [];
  bool unlockAll = false;

  /// Badges earned in the last finished mission (shown on the results).
  List<String> justEarned = [];

  BaseStore() {
    ensureBaseContent();
  }

  Future<void> load(SharedPreferences? p) async {
    _p = p;
    if (p == null) return;
    try {
      for (var n = 1; n <= 10; n++) {
        final s = p.getInt('base_stars_$n');
        if (s != null) stars[n] = s;
      }
      earned.addAll(p.getStringList('base_badges') ?? const []);
      fixedTotal = p.getInt('base_fixed') ?? 0;
      supplyRuns = p.getInt('supply_runs') ?? 0;
      supplyBest = p.getInt('supply_best') ?? 0;
      final b = p.getString('base_bonus');
      if (b != null) {
        final m = jsonDecode(b) as Map<String, dynamic>;
        bonus = StartSupplies(power: (m['p'] as num).toDouble(), oxygen: (m['o'] as num).toDouble(), water: (m['w'] as num).toDouble(), food: (m['f'] as num).toDouble(), parts: ((m['k'] ?? 0) as num).toDouble());
      }
      final r = p.getString('base_runs');
      if (r != null) runs.addAll([for (final x in jsonDecode(r) as List) Map<String, dynamic>.from(x as Map)]);
    } catch (e) {
      debugPrint('base store: $e');
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- missions

  bool unlocked(int n) {
    if (unlockAll || n == 1) return true;
    if (n == 6) return [1, 2, 3, 4, 5].every((m) => (stars[m] ?? 0) > 0);
    return (stars[n - 1] ?? 0) > 0;
  }

  bool get moonDone => [1, 2, 3, 4, 5].every((m) => (stars[m] ?? 0) > 0);
  int get moonDoneCount => [1, 2, 3, 4, 5].where((m) => (stars[m] ?? 0) > 0).length;
  int get marsDoneCount => [6, 7, 8, 9, 10].where((m) => (stars[m] ?? 0) > 0).length;

  /// The first mission not yet won (the "current" row).
  int get current {
    for (var n = 1; n <= 10; n++) {
      if ((stars[n] ?? 0) == 0) return n;
    }
    return 10;
  }

  int get totalStars => stars.values.fold(0, (a, b) => a + b);

  // ---------------------------------------------------------------- the game in progress

  BaseState? resume(int n) {
    final raw = _p?.getString('base_save');
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if ((j['mission'] as num).toInt() != n) return null;
      return BaseState.fromJson(j, baseMission);
    } catch (_) {
      return null;
    }
  }

  int? get savedMission {
    final raw = _p?.getString('base_save');
    if (raw == null) return null;
    try {
      return ((jsonDecode(raw) as Map)['mission'] as num).toInt();
    } catch (_) {
      return null;
    }
  }

  Future<void> save(BaseState s) async {
    if (s.outcome != BaseOutcome.running) {
      await _p?.remove('base_save');
      return;
    }
    await _p?.setString('base_save', jsonEncode(s.toJson()));
  }

  Future<void> clearSave() async => _p?.remove('base_save');

  /// Takes the Supply Run bonus for the next mission (it is used once).
  StartSupplies? takeBonus() {
    final b = bonus;
    bonus = null;
    _p?.remove('base_bonus');
    return b;
  }

  // ---------------------------------------------------------------- results

  /// Records a finished mission. Returns the result's data for syncing.
  Future<Map<String, dynamic>> finish(BaseState s, MissionResult r) async {
    final n = s.mission.n;
    if (r.won && r.stars > (stars[n] ?? 0)) {
      stars[n] = r.stars;
      await _p?.setInt('base_stars_$n', r.stars);
    }
    fixedTotal += s.problemsFixed;
    await _p?.setInt('base_fixed', fixedTotal);
    final won = {for (final e in stars.entries) if (e.value > 0) e.key};
    final got = badgesFor(r, s.mission, won: won, fixedTotal: fixedTotal).difference(earned);
    justEarned = got.toList();
    earned.addAll(got);
    await _p?.setStringList('base_badges', earned.toList());
    final record = {
      'mission': n,
      'level': s.level.name,
      'won': r.won,
      'stars': r.stars,
      'day_reached': r.dayReached,
      'days': r.days,
      'crew_health': r.crewHealth.round(),
      'research': r.research.round(),
      'ratings': r.ratings,
      'main_problem': r.mainProblem,
      'best_decision': r.best?.title,
      'lost_cause': s.lostCause,
      'decisions': [for (final l in s.log.where((l) => l.score != 0)) {'day': l.day, 'title': l.title, 'score': l.score}],
      'played_at': DateTime.now().toUtc().toIso8601String(),
    };
    runs.add(record);
    while (runs.length > 40) {
      runs.removeAt(0);
    }
    await _p?.setString('base_runs', jsonEncode(runs));
    await clearSave();
    notifyListeners();
    return record;
  }

  /// Records a Supply Run: its stars and the supplies for the next mission.
  Future<void> finishSupplyRun(int starsWon, StartSupplies add) async {
    supplyRuns++;
    if (starsWon > supplyBest) supplyBest = starsWon;
    final old = bonus ?? const StartSupplies(power: 0, oxygen: 0, water: 0, food: 0);
    bonus = StartSupplies(power: old.power + add.power, oxygen: old.oxygen + add.oxygen, water: old.water + add.water, food: old.food + add.food, parts: old.parts + add.parts);
    await _p?.setString('base_bonus', jsonEncode({'p': bonus!.power, 'o': bonus!.oxygen, 'w': bonus!.water, 'f': bonus!.food, 'k': bonus!.parts}));
    await _p?.setInt('supply_runs', supplyRuns);
    await _p?.setInt('supply_best', supplyBest);
    justEarned = [];
    if (starsWon >= 3 && earned.add('supply_runner')) {
      justEarned = ['supply_runner'];
      await _p?.setStringList('base_badges', earned.toList());
    }
    notifyListeners();
  }

  Future<void> resetAll() async {
    stars.clear();
    earned.clear();
    fixedTotal = 0;
    supplyRuns = 0;
    supplyBest = 0;
    bonus = null;
    runs.clear();
    for (final k in [for (var n = 1; n <= 10; n++) 'base_stars_$n', 'base_badges', 'base_fixed', 'supply_runs', 'supply_best', 'base_bonus', 'base_runs', 'base_save']) {
      await _p?.remove(k);
    }
    notifyListeners();
  }
}
