import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/catalogue.dart';
import '../data/readiness.dart';
import '../main.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import '../world/characters.dart';

/// The Readiness Check: 8 questions before the campaign ("pre") and the same 8
/// after it ("post"). The teacher sees the gain. The first time, answers are
/// not marked (so it measures what the player already knows); the second
/// time every answer is explained.
class ReadinessScreen extends StatefulWidget {
  const ReadinessScreen({super.key});

  @override
  State<ReadinessScreen> createState() => _ReadinessScreenState();
}

class _ReadinessScreenState extends State<ReadinessScreen> {
  late final sv = Services.of(context);
  late final camp = sv.progress.campaign;
  late final List<ReadinessQ> _qs = readinessQuestions[camp.id] ?? const [];
  late final String _kind = sv.progress.assessment(camp.id, 'pre') == null ? 'pre' : 'post';
  late final List<int> _answers = List.filled(_qs.length, -1);
  late final List<List<int>> _order = [for (var i = 0; i < _qs.length; i++) _shuffle(_qs[i].options.length, i * 31 + camp.id.index)];
  int _i = 0;
  bool _revealed = false;
  bool _done = false;

  static List<int> _shuffle(int n, int seed) {
    final l = List<int>.generate(n, (i) => i);
    final r = math.Random(seed);
    for (var i = n - 1; i > 0; i--) {
      final j = r.nextInt(i + 1);
      final t = l[i];
      l[i] = l[j];
      l[j] = t;
    }
    return l;
  }

  bool get _post => _kind == 'post';

  void _pick(int option) {
    if (_revealed) return;
    sv.audio.tap();
    setState(() {
      _answers[_i] = option;
      _revealed = _post;
    });
    if (!_post) Future.delayed(const Duration(milliseconds: 350), _next);
    if (_post) sv.voice.say(_qs[_i].why);
  }

  void _next() {
    if (!mounted) return;
    if (_i < _qs.length - 1) {
      setState(() {
        _i++;
        _revealed = false;
      });
      if (sv.progress.voiceOn) sv.voice.say(_qs[_i].text);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final score = readinessScore(_qs, _answers);
    await sv.session.recordAssessment(camp.id, _kind, score, _qs.length, [
      for (var i = 0; i < _qs.length; i++) {'q': _qs[i].id, 'answer': _answers[i], 'correct': _answers[i] == _qs[i].answer, 'skill': _qs[i].skill.db},
    ]);
    for (var i = 0; i < _qs.length; i++) {
      sv.progress.addSkillEvidence(_qs[i].skill, _answers[i] == _qs[i].answer);
    }
    await sv.progress.saveSkills();
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return AuroraBackground(
      intensity: 0.7,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + bottom),
          child: _done ? _result() : _question(),
        ),
      ),
    );
  }

  Widget _question() {
    final q = _qs[_i];
    final order = _order[_i];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        IconButton(onPressed: () => sv.nav.back(), icon: const Icon(Icons.close_rounded, color: C.frozen)),
        Expanded(child: Text(_post ? 'FINAL READINESS CHECK' : 'READINESS CHECK', style: T.label, textAlign: TextAlign.center)),
        const SizedBox(width: 48),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        for (var k = 0; k < _qs.length; k++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: Motion.fast,
              height: 6,
              decoration: BoxDecoration(color: k < _i ? C.cyan : (k == _i ? C.sapphire : C.lineSoft), borderRadius: BorderRadius.circular(3)),
            ),
          ),
          if (k < _qs.length - 1) const SizedBox(width: 4),
        ],
      ]),
      const SizedBox(height: 20),
      Text('Question ${_i + 1} of ${_qs.length} · ${q.skill.title}', style: T.bodySmall),
      const SizedBox(height: 8),
      AnimatedSwitcher(
        duration: Motion.normal,
        child: Text(q.text, key: ValueKey(_i), style: T.h1.copyWith(fontSize: 23, height: 1.3)),
      ),
      const SizedBox(height: 20),
      for (final o in order)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _option(q, o),
        ),
      const Spacer(),
      if (_revealed)
        EnterAnim(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.cyan.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: C.cyan.withValues(alpha: 0.35))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                PipFigure(size: 34, eye: _answers[_i] == q.answer ? PipEye.happy : PipEye.thinking),
                const SizedBox(width: 8),
                Expanded(child: Text(q.why, style: T.body.copyWith(fontSize: 14))),
              ]),
            ),
            const SizedBox(height: 12),
            PrimaryButton(label: _i < _qs.length - 1 ? 'Next question' : 'See my result', icon: Icons.arrow_forward_rounded, onTap: _next),
          ]),
        )
      else
        Text(_post ? 'Pick an answer to see the explanation.' : 'There is no time limit, and this is not a test of you: it shows where you start.', style: T.bodySmall, textAlign: TextAlign.center),
    ]);
  }

  Widget _option(ReadinessQ q, int o) {
    final picked = _answers[_i] == o;
    final right = o == q.answer;
    Color border = C.line;
    Color fill = C.panelSolid;
    if (_revealed && right) {
      border = C.cyan;
      fill = C.cyan.withValues(alpha: 0.14);
    } else if (_revealed && picked) {
      border = C.red.withValues(alpha: 0.8);
      fill = C.red.withValues(alpha: 0.08);
    } else if (picked) {
      border = C.sapphire;
    }
    return Pressable(
      onTap: _revealed ? null : () => _pick(o),
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 1.5)),
        child: Row(children: [
          Expanded(child: Text(q.options[o], style: T.h3.copyWith(fontSize: 15.5))),
          if (_revealed && right) const Icon(Icons.check_circle_rounded, color: C.cyan),
          if (_revealed && picked && !right) const Icon(Icons.cancel_rounded, color: C.red),
        ]),
      ),
    );
  }

  Widget _result() {
    final score = readinessScore(_qs, _answers);
    final pre = sv.progress.assessment(camp.id, 'pre');
    final post = sv.progress.assessment(camp.id, 'post');
    final gain = _post && pre != null && post != null ? post - pre : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Spacer(),
      Center(child: PipFigure(size: 90, eye: score >= _qs.length * 0.6 ? PipEye.happy : PipEye.normal)),
      const SizedBox(height: 16),
      Text(_post ? 'Final check done' : 'Ready for launch', style: T.hero.copyWith(fontSize: 34), textAlign: TextAlign.center),
      const SizedBox(height: 10),
      Text('$score of ${_qs.length} right', style: T.h2, textAlign: TextAlign.center),
      if (gain != null) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: C.cyan.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18), border: Border.all(color: C.cyan.withValues(alpha: 0.5))),
          child: Column(children: [
            Text('BEFORE → AFTER', style: T.label.copyWith(fontSize: 11)),
            const SizedBox(height: 6),
            Text('$pre% → $post%', style: T.hero.copyWith(fontSize: 36, color: C.cyan)),
            Text(gain >= 0 ? '+$gain points. That is what you learned on this mission.' : 'Keep practising: replay a level and try again.', style: T.body.copyWith(color: C.muted), textAlign: TextAlign.center),
          ]),
        ),
      ] else
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text('You will take the same check at the end of the campaign to see how much you learned.', style: T.body.copyWith(color: C.muted), textAlign: TextAlign.center),
        ),
      const Spacer(),
      PrimaryButton(label: _post ? 'See my skills' : 'Start level 1', icon: _post ? Icons.radar_rounded : Icons.play_arrow_rounded, onTap: () {
        if (_post) {
          sv.nav.go(Screen.skills);
        } else {
          sv.nav.back();
          sv.nav.startStory(1, sv);
        }
      }),
      const SizedBox(height: 10),
      HudButton(label: 'BACK TO THE MAP', onTap: () => sv.nav.resetTo(Screen.map)),
    ]);
  }
}
