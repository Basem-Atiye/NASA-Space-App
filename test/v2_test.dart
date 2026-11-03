import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton_station/cloud/link.dart';
import 'package:shackleton_station/coop/coop_engine.dart';
import 'package:shackleton_station/coop/coop_missions.dart';
import 'package:shackleton_station/data/catalogue.dart';
import 'package:shackleton_station/data/readiness.dart';
import 'package:shackleton_station/data/story.dart';
import 'package:shackleton_station/services/sync_queue.dart';
import 'package:shackleton_station/story/campaign.dart';
import 'package:shackleton_station/story/game_physics.dart';
import 'package:shackleton_station/story/level_record.dart';
import 'package:shackleton_station/story/sims.dart';
import 'package:shackleton_station/story/story_model.dart';
import 'package:shackleton_station/story/story_run.dart';
import 'package:shackleton_station/world/world_model.dart';

const _props = {'lander', 'habitat', 'battery', 'cable', 'panels', 'antenna', 'crate', 'rover', 'greenhouse', 'pad', 'drill', 'rocket', 'rim', 'crater', 'sites'};

bool _placed(String id) => worldLayout.containsKey(id) || worldAliases.containsKey(id);

void _playWell(StoryRun r) {
  final s = r.step;
  switch (s.kind) {
    case StepKind.talk:
      r.continueTalk();
    case StepKind.goTo:
      r.arrive(s.target);
      r.use();
    case StepKind.collect:
      for (final i in s.items) {
        r.arrive(i.startsWith('site:') ? i : 'pickup:$i');
      }
    case StepKind.choice:
      r.choose(s.options.firstWhere((o) => !o.mistake).id);
    case StepKind.game:
      final data = <String, Object>{};
      if (s.id == 't2_materials') data['shielding'] = 6;
      if (s.id == 't4_rations') {
        data['food'] = 0.55;
        data['water'] = 2.1;
      }
      r.finishGame(GameResult(mistakes: 0, data: data));
  }
}

void main() {
  test('three campaigns: 12, 15 and 15 levels, numbered, with lessons and catalogue ids', () {
    expect(campaignFor(AgeMode.cadet).length, 12);
    expect(campaignFor(AgeMode.explorer).length, 15);
    expect(campaignFor(AgeMode.engineer).length, 15);
    for (final c in campaigns) {
      expect(c.infos.length, c.length, reason: c.title);
      for (var n = 1; n <= c.length; n++) {
        expect(c.task(n).n, n, reason: '${c.title} $n');
        expect(c.info(n).n, n, reason: '${c.title} info $n');
        final e = catalogueEntry(c.levelIdFor(n));
        expect(e, isNotNull, reason: c.levelIdFor(n));
        expect(e!.title, c.task(n).title, reason: c.levelIdFor(n));
        expect(c.info(n).minutes.length, 3);
      }
      expect(campaignEntries(c.id).length, c.length, reason: c.title);
    }
  });

  test('every target, pickup and prop of every level exists in the world', () {
    for (final c in campaigns) {
      for (final t in c.tasks) {
        final sc = t.scene;
        if (sc != null) {
          for (final p in sc.props) {
            expect(_props.contains(p), isTrue, reason: '${t.title}: prop $p');
          }
          for (final p in sc.pickups) {
            expect(_placed(p), isTrue, reason: '${t.title}: pickup $p');
            expect(pickupInfo.containsKey(p), isTrue, reason: 'pickupInfo $p');
          }
        }
        for (final s in t.steps) {
          if (s.kind == StepKind.goTo) {
            expect(_placed(s.target), isTrue, reason: '${t.title}: ${s.target}');
            if (sc != null) {
              final real = worldAliases[s.target] ?? s.target;
              expect(sc.props.contains(real) || sc.props.contains(s.target) || (real == 'pad' && sc.props.contains('pad')), isTrue, reason: '${t.title}: ${s.target} is not drawn');
            }
          }
          for (final i in s.items) {
            expect(_placed(i), isTrue, reason: '${t.title}: item $i');
            if (sc != null && !i.startsWith('site:')) expect(sc.pickups.contains(i), isTrue, reason: '${t.title}: $i not in scene pickups');
          }
        }
      }
    }
  });

  test('every mini-game spec is complete and solvable', () {
    for (final c in campaigns) {
      for (final t in c.tasks) {
        for (final s in t.steps) {
          final g = s.game;
          if (s.kind == StepKind.game) expect(g, isNotNull, reason: s.id);
          if (g == null) continue;
          final why = '${c.title} ${s.id}';
          switch (g.kind) {
            case GameKind.order:
              expect(g.answer.length, g.items.length, reason: why);
              expect(g.answer.toSet().length, g.items.length, reason: why);
            case GameKind.probe:
              expect(g.readings.length, g.items.length, reason: why);
              expect(g.faulty.isNotEmpty && g.faulty.every((i) => i < g.items.length), isTrue, reason: why);
            case GameKind.wire:
              expect(g.answer.length, g.items.length, reason: why);
              expect(g.right.length, g.items.length, reason: why);
              expect(g.answer.toSet().length, g.items.length, reason: why);
            case GameKind.sort:
              expect(g.answer.length, g.items.length, reason: why);
              expect(g.bins.length, greaterThanOrEqualTo(2), reason: why);
              expect(g.answer.every((b) => b >= 0 && b < g.bins.length), isTrue, reason: why);
            case GameKind.checklist:
              expect(g.readings.length, g.items.length, reason: why);
              expect(g.right.isEmpty || g.right.length == g.items.length, isTrue, reason: why);
            case GameKind.hold:
              expect(g.low < g.high && g.high <= g.max && g.rate > 0, isTrue, reason: why);
            case GameKind.draw:
              expect(g.points.length.isEven && g.points.length >= 6, isTrue, reason: why);
              expect(g.points.every((p) => p >= 0 && p <= 1), isTrue, reason: why);
            case GameKind.sim:
              expect(simModel(g.sim), isNotNull, reason: '$why: ${g.sim}');
            case GameKind.jump:
            case GameKind.drive:
            case GameKind.fitness:
              expect(g.count, greaterThan(0), reason: why);
            default:
              break;
          }
          if (t.scene != null) expect(g.hint.isNotEmpty, isTrue, reason: '$why has no hint');
        }
      }
    }
  });

  test('choices always have a right answer; launches are the last step', () {
    for (final c in campaigns) {
      for (final t in c.tasks) {
        final ids = <String>{};
        for (var i = 0; i < t.steps.length; i++) {
          final s = t.steps[i];
          expect(ids.add(s.id), isTrue, reason: 'duplicate step id ${s.id}');
          if (s.kind == StepKind.choice) expect(s.options.any((o) => !o.mistake), isTrue, reason: s.id);
          if (s.launch) expect(i, t.steps.length - 1, reason: '${s.id} launches before the end');
        }
      }
    }
  });

  test('every level of every campaign can be finished with 3 stars at every age', () {
    for (final c in campaigns) {
      for (var n = 1; n <= c.length; n++) {
        for (final m in AgeMode.values) {
          final r = StoryRun(c.task(n), c.carryDefaults(n), mode: m);
          var guard = 0;
          while (!r.finished && guard++ < 200) {
            _playWell(r);
          }
          expect(r.outcome, TaskOutcome.complete, reason: '${c.title} level $n ($m) ${r.failReason}');
          expect(r.stars, 3, reason: '${c.title} level $n');
        }
      }
    }
  });

  test('every level has skills to give evidence for', () {
    for (final e in catalogue) {
      expect(e.skills.isNotEmpty, isTrue, reason: e.id);
    }
    final ids = catalogue.map((e) => e.id).toSet();
    expect(ids.length, catalogue.length);
    expect(catalogue.length, 70);
  });

  test('the levels SQL migration matches the Dart catalogue', () {
    final f = File('backend/prisma/migrations/0003_catalogue/migration.sql');
    if (!f.existsSync()) return;
    final sql = f.readAsStringSync();
    for (final e in catalogue) {
      expect(sql.contains("('${e.id}', '${e.campaign.name}', ${e.number}, "), isTrue, reason: e.id);
    }
    expect(RegExp(r"^\s+\('", multiLine: true).allMatches(sql).length, catalogue.length);
  });

  test('engineering SIMs start unsafe and have a safe solution', () {
    expect(sims.length, greaterThanOrEqualTo(15));
    for (final m in sims.values) {
      expect(m.solved(m.start), isFalse, reason: '${m.id} is already solved');
      expect(m.solved(m.solution), isTrue, reason: '${m.id} solution');
      for (var i = 0; i < m.sliders.length; i++) {
        final s = m.sliders[i];
        expect(m.solution[i] >= s.min && m.solution[i] <= s.max, isTrue, reason: '${m.id} slider $i');
        expect(m.start[i] >= s.min && m.start[i] <= s.max, isTrue, reason: '${m.id} start $i');
      }
    }
  });

  test('Readiness Check: 8 questions per campaign covering all six skills', () {
    for (final c in [CampaignId.cadet, CampaignId.explorer, CampaignId.engineer]) {
      final qs = readinessQuestions[c]!;
      expect(qs.length, 8);
      expect(qs.map((q) => q.skill).toSet().length, 6, reason: c.name);
      for (final q in qs) {
        expect(q.answer >= 0 && q.answer < q.options.length, isTrue, reason: q.id);
      }
      expect(readinessScore(qs, [for (final q in qs) q.answer]), 8);
      expect(readinessScore(qs, List.filled(8, -1)), 0);
    }
  });

  test('18 co-op missions, 6 per age, every round is winnable', () {
    expect(coopMissions.length, 18);
    for (var a = 0; a < 3; a++) {
      expect(coopMissions.where((m) => m.age == a).length, 6);
    }
    for (final m in coopMissions) {
      expect(catalogueEntry(m.id)?.title, m.title, reason: m.id);
      for (final r in m.rounds) {
        final ids = r.actions.map((x) => x.id).toSet();
        expect(r.answer.every(ids.contains), isTrue, reason: '${m.id}: ${r.prompt}');
        expect(r.actions.every((x) => m.roles.contains(x.owner)), isTrue, reason: m.id);
        expect(r.info.keys.every(m.roles.contains), isTrue, reason: m.id);
      }
      // play it perfectly with every role on its own phone
      final s = CoopState(m);
      s.seat([for (final r in m.roles) r.name], {for (final r in m.roles) r.name: r.title});
      s.start();
      for (var k = 0; k < m.rounds.length; k++) {
        final r = s.current;
        for (final a in r.answer) {
          final owner = r.actions.firstWhere((x) => x.id == a).owner;
          expect(s.act(owner.name, a), isTrue, reason: '${m.id} round $k $a');
        }
        s.nextRound();
      }
      expect(s.finished, isTrue, reason: m.id);
      expect(s.stars, 3);
    }
  });

  test('co-op: wrong order and other roles\' buttons', () {
    final m = coopMission('coop-01')!;
    final s = CoopState(m)..seat(['a', 'c'], {'a': 'Rana', 'c': 'Omar'})..start();
    expect(s.rolesOf('a').contains(CoopRole.astronaut), isTrue);
    expect(s.act('a', 'helmet'), isFalse); // helmet is last
    expect(s.mistakes, 1);
    expect(s.act('c', 'under'), isNull); // CAPCOM does not own the suit buttons
    expect(s.act('a', 'under'), isTrue);
    final copy = CoopState(m)..applyJson(s.toJson());
    expect(copy.done.length, 1);
    expect(copy.mistakes, 1);
    expect(copy.rolesOf('c').contains(CoopRole.capcom), isTrue);
  });

  test('roles are shared out for 2, 3 and 4 players', () {
    const four = CoopRole.values;
    expect(shareRoles(four, 2).map((s) => s.length).join(','), '2,2');
    expect(shareRoles(four, 3).map((s) => s.length).join(','), '2,1,1');
    expect(shareRoles(four, 4).every((s) => s.length == 1), isTrue);
    expect(shareRoles(four, 9).length, 4);
  });

  test('sync queue: in order, retries later, drops bad data, coalesces', () async {
    final store = MemoryQueueStore();
    final q = SyncQueue(store);
    await q.add(SyncOp('attempt', {'n': 1}));
    await q.add(SyncOp('campaign', {'v': 1}, key: 'cadet'));
    await q.add(SyncOp('campaign', {'v': 2}, key: 'cadet'));
    await q.add(SyncOp('attempt', {'n': 2}));
    expect(q.length, 3);
    // offline: nothing is lost
    expect(await q.flush((_) async => throw const SocketException('offline')), 0);
    expect(q.length, 3);
    expect(SyncQueue(store).length, 3); // survives a restart
    final sent = <String>[];
    expect(await q.flush((op) async {
      if (op.data['n'] == 2) throw const PermanentSyncError('bad');
      sent.add('${op.kind}${op.data}');
    }), 2);
    expect(q.isEmpty, isTrue);
    expect(sent.join(' '), 'attempt{n: 1} campaign{v: 2}');
  });

  test('local link: messages and presence between two phones', () async {
    final hub = LocalHub();
    final a = hub.link('a'), b = hub.link('b');
    final got = <String>[];
    b.messages.listen((m) => got.add('${m.from}:${m.event}:${m.data['x']}'));
    await a.connect({'name': 'Rana'});
    await b.connect({'name': 'Omar'});
    expect(a.currentPeers.length, 2);
    await a.send('act', {'x': 1});
    await b.send('act', {'x': 2}); // never echoed back to the sender
    expect(got.join(','), 'a:act:1');
    await a.close();
    expect(b.currentPeers.length, 1);
  });

  test('low gravity: Moon jumps are six times higher and clear the craters', () {
    expect(jumpHeight(2.3, earthG) * 6, closeTo(jumpHeight(2.3, moonG), 0.1));
    final r = JumpRunner();
    final widest = jumpCourse(8).map((c) => c.$2 - c.$1).reduce((a, b) => a > b ? a : b);
    expect(r.jumpLength, greaterThan(widest + 2));
    expect(JumpRunner(g: earthG).jumpLength, lessThan(widest));
    r.jump();
    var t = 0.0;
    while (r.airborne && t < 10) {
      r.step(0.01);
      t += 0.01;
    }
    expect(t, closeTo(hangTime(2.3, moonG), 0.05));
  });

  test('rep counter counts real moves, not shaking', () {
    final c = RepCounter();
    var ms = 0;
    for (var i = 0; i < 5; i++) {
      c.sample(0, 0, 4, ms += 100); // a push
      c.sample(0, 0, 0.5, ms += 400); // back to rest
    }
    expect(c.reps, 5);
    for (var i = 0; i < 10; i++) {
      c.sample(0, 0, 5, ms += 20); // jitter too fast to be reps
    }
    expect(c.reps, lessThanOrEqualTo(6));
    expect(laneFor(-0.9), 0);
    expect(laneFor(0), 1);
    expect(laneFor(0.8), 2);
  });

  test('attempt records are what the database accepts', () {
    final id = newClientId();
    expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(id), isTrue, reason: id);
    final r = LevelRecord(
      clientId: id,
      levelId: 'cadet-01',
      mode: AgeMode.cadet,
      startedAt: DateTime.utc(2026, 11, 14, 9),
      endedAt: DateTime.utc(2026, 11, 14, 9, 6),
      complete: true,
      stars: 3,
      mistakes: 0,
      hints: 1,
      decisions: const [],
      evidence: const [(Skill.procedure, true)],
      campaign: CampaignId.cadet,
      n: 1,
      carry: const {},
    );
    final j = r.attemptJson();
    expect(j['outcome'], 'complete');
    expect(j['duration_s'], 360);
    expect(j['age_mode'], 'cadet');
    expect(r.skillsJson().first['skill'], 'procedure');
  });
}
