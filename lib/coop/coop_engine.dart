/// Co-op missions: the rules, in pure Dart.
///
/// Every mission is a few rounds. In each round the team must press the right
/// buttons (in order, for procedures). The catch: each role sees different
/// information and owns different buttons, so the team only wins by talking.
/// The host phone runs this engine and broadcasts the state; the other phones
/// send their button presses to the host.
library;

import 'dart:math' as math;

enum CoopRole { astronaut, capcom, engineer, surgeon }

extension CoopRoleInfo on CoopRole {
  String get title => const ['Astronaut', 'CAPCOM', 'Flight Engineer', 'Flight Surgeon'][index];
  String get job => const [
        'You are on the Moon. You press the buttons, but you only see what is in front of you.',
        'Mission Control voice. You hold the procedure cards and the manual.',
        'You watch the systems: voltages, pressures, power and batteries.',
        'You watch the crew\'s health: oxygen, heart rate, radiation dose.',
      ][index];
  static CoopRole parse(String? s) => CoopRole.values.firstWhere((r) => r.name == s, orElse: () => CoopRole.astronaut);
}

class CoopAction {
  final String id;
  final String label;
  final CoopRole owner;
  const CoopAction(this.id, this.label, this.owner);
}

class CoopRound {
  final String prompt;

  /// Private information per role (what only they see).
  final Map<CoopRole, String> info;
  final List<CoopAction> actions;

  /// The right action ids. [ordered]: they must happen in this order.
  final List<String> answer;
  final bool ordered;

  /// Shown when the round is solved.
  final String success;

  /// Seconds for the round (0 = no clock).
  final int seconds;

  const CoopRound({required this.prompt, required this.info, required this.actions, required this.answer, this.ordered = true, this.success = 'Round complete!', this.seconds = 0});
}

enum CoopTemplate { sequence, identify, consoles }

class CoopMission {
  final String id;
  final int n;
  final String title;
  final int age; // 0 cadet, 1 explorer, 2 engineer
  final CoopTemplate template;
  final List<CoopRole> roles;
  final String brief;
  final String lesson;
  final String nasaDoes;
  final List<CoopRound> rounds;
  const CoopMission({
    required this.id,
    required this.n,
    required this.title,
    required this.age,
    required this.template,
    required this.roles,
    required this.brief,
    required this.lesson,
    required this.nasaDoes,
    required this.rounds,
  });

  int get minPlayers => 2;
  int get maxPlayers => roles.length;
}

/// The preset quick calls (no free text between children).
const quickCalls = ['Copy that', 'Say again?', 'Which one?', 'I see it!', 'Wait…', 'Go ahead', 'Read me your screen', 'Good job!'];

/// Shares the mission's roles between [players] players (in join order).
/// 2 players: 0 = Astronaut (+ Surgeon), 1 = CAPCOM (+ Engineer). 3: the
/// third takes Engineer (+ Surgeon). 4: one role each.
List<Set<CoopRole>> shareRoles(List<CoopRole> roles, int players) {
  final p = math.max(1, math.min(players, roles.length));
  final out = List.generate(p, (_) => <CoopRole>{});
  for (var i = 0; i < roles.length; i++) {
    out[i % p].add(roles[i]);
  }
  return out;
}

enum CoopPhase { lobby, playing, roundDone, done }

class CoopLogEntry {
  final String text;
  final bool good;
  const CoopLogEntry(this.text, this.good);
}

/// The whole game state. Serialisable, so the host can broadcast it.
class CoopState {
  final CoopMission mission;
  CoopPhase phase = CoopPhase.lobby;
  int round = 0;
  final List<String> done = [];
  int mistakes = 0;
  double elapsed = 0;
  double roundLeft = 0;
  final List<CoopLogEntry> log = [];

  /// player id -> roles
  final Map<String, Set<CoopRole>> roles = {};
  final Map<String, String> names = {};

  CoopState(this.mission);

  CoopRound get current => mission.rounds[math.min(round, mission.rounds.length - 1)];
  bool get finished => phase == CoopPhase.done;

  int get stars => mistakes == 0 ? 3 : (mistakes <= 2 ? 2 : 1);

  /// Assigns roles to everyone present, in the order given (host first).
  void seat(List<String> playerIds, Map<String, String> playerNames) {
    roles.clear();
    names
      ..clear()
      ..addAll(playerNames);
    final shares = shareRoles(mission.roles, playerIds.length);
    for (var i = 0; i < playerIds.length && i < shares.length; i++) {
      roles[playerIds[i]] = shares[i];
    }
  }

  Set<CoopRole> rolesOf(String player) => roles[player] ?? const {};

  void start() {
    phase = CoopPhase.playing;
    round = 0;
    done.clear();
    mistakes = 0;
    elapsed = 0;
    roundLeft = current.seconds.toDouble();
    log.clear();
  }

  /// A player pressed [actionId]. Returns null if ignored, otherwise whether it was right.
  bool? act(String player, String actionId) {
    if (phase != CoopPhase.playing) return null;
    final r = current;
    final a = r.actions.where((x) => x.id == actionId).firstOrNull;
    if (a == null || !rolesOf(player).contains(a.owner) || done.contains(actionId)) return null;
    final who = names[player] ?? a.owner.title;
    final want = r.ordered ? (done.length < r.answer.length ? r.answer[done.length] : null) : null;
    final ok = r.ordered ? actionId == want : r.answer.contains(actionId);
    if (ok) {
      done.add(actionId);
      log.add(CoopLogEntry('$who: ${a.label}', true));
      if (r.answer.every(done.contains)) {
        log.add(CoopLogEntry(r.success, true));
        phase = CoopPhase.roundDone;
      }
    } else {
      mistakes++;
      log.add(CoopLogEntry('$who: ${a.label} · not right${r.ordered ? ' now' : ''}', false));
    }
    if (log.length > 30) log.removeRange(0, log.length - 30);
    return ok;
  }

  /// After a round is solved: the next one, or the end.
  void nextRound() {
    if (phase != CoopPhase.roundDone) return;
    if (round >= mission.rounds.length - 1) {
      phase = CoopPhase.done;
      return;
    }
    round++;
    done.clear();
    roundLeft = current.seconds.toDouble();
    phase = CoopPhase.playing;
  }

  /// The clock. A round that runs out counts a mistake and gives 15 more seconds.
  void tick(double dt) {
    if (phase != CoopPhase.playing) return;
    elapsed += dt;
    if (current.seconds > 0) {
      roundLeft -= dt;
      if (roundLeft <= 0) {
        mistakes++;
        log.add(const CoopLogEntry('Time! Mission Control adds 15 seconds. Talk it through.', false));
        roundLeft = 15;
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'm': mission.id,
        'p': phase.name,
        'r': round,
        'd': done,
        'x': mistakes,
        'e': elapsed,
        'l': roundLeft,
        'log': [for (final e in log) [e.text, e.good]],
        'roles': {for (final e in roles.entries) e.key: [for (final r in e.value) r.name]},
        'names': names,
      };

  void applyJson(Map<String, dynamic> j) {
    phase = CoopPhase.values.firstWhere((p) => p.name == j['p'], orElse: () => phase);
    round = (j['r'] as num?)?.toInt() ?? round;
    done
      ..clear()
      ..addAll([for (final d in (j['d'] as List? ?? const [])) '$d']);
    mistakes = (j['x'] as num?)?.toInt() ?? mistakes;
    elapsed = (j['e'] as num?)?.toDouble() ?? elapsed;
    roundLeft = (j['l'] as num?)?.toDouble() ?? roundLeft;
    log
      ..clear()
      ..addAll([
        for (final e in (j['log'] as List? ?? const []))
          if (e is List && e.length == 2) CoopLogEntry('${e[0]}', e[1] == true),
      ]);
    final rj = j['roles'];
    if (rj is Map) {
      roles
        ..clear()
        ..addAll({for (final e in rj.entries) '${e.key}': {for (final r in (e.value as List)) CoopRoleInfo.parse('$r')}});
    }
    final nj = j['names'];
    if (nj is Map) {
      names
        ..clear()
        ..addAll({for (final e in nj.entries) '${e.key}': '${e.value}'});
    }
  }
}
