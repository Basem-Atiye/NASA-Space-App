import 'package:flutter/material.dart';
import '../ui/game_helper.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/content.dart';
import '../data/missions.dart';
import '../story/campaign.dart';
import '../story/story_model.dart' show AgeModeInfo;
import '../engine/constants.dart';
import '../main.dart';
import '../ui/theme.dart';
import '../ui/kit.dart';
import '../ui/widgets/common.dart';

/// The frame of the information screens: back button, big title, scrolling body.
class InfoFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const InfoFrame({super.key, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    return AuroraBackground(
      intensity: 0.7,
      child: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Row(children: [
              RoundButton(onTap: () {
                  sv.audio.tap();
                  sv.nav.back();
                }),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(context).padding.bottom),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GameText(_titleCase(title), style: T.h1),
                const SizedBox(height: 6),
                GameText(subtitle, style: T.body.copyWith(color: C.muted)),
                const SizedBox(height: 18),
                child,
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  static String _titleCase(String s) => s.split(' ').map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase()).join(' ');
}

Future<void> _openUrl(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

// ---------------------------------------------------------------- MISSION DATA

class MissionDataScreen extends StatelessWidget {
  const MissionDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoFrame(
      title: 'MISSION DATA',
      subtitle: 'Every number in the game, its real value, and where it comes from',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth > 640;
          return Column(children: [
            if (wide)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(flex: 3, child: GameText('QUANTITY', style: T.label)),
                  Expanded(flex: 4, child: GameText('REAL VALUE', style: T.label)),
                  Expanded(flex: 4, child: GameText('IN THE GAME', style: T.label)),
                  Expanded(flex: 4, child: GameText('SOURCE', style: T.label)),
                ]),
              ),
            for (final d in missionData)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.lineSoft))),
                child: wide
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 3, child: GameText(d.quantity, style: T.h3)),
                        Expanded(flex: 4, child: GameText(d.realValue, style: T.mono.copyWith(fontSize: 12, color: C.cyan))),
                        Expanded(flex: 4, child: GameText(d.inGame, style: T.bodySmall.copyWith(color: C.text))),
                        Expanded(flex: 4, child: _SourceLink(d.source, d.url)),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        GameText(d.quantity, style: T.h3),
                        GameText(d.realValue, style: T.mono.copyWith(fontSize: 12, color: C.cyan)),
                        GameText(d.inGame, style: T.bodySmall.copyWith(color: C.text)),
                        _SourceLink(d.source, d.url),
                      ]),
              ),
          ]);
        }),
        const HudDivider(),
        const SectionLabel('Real storms replayed in the game'),
        const SizedBox(height: 6),
        for (final st in [Storms.x33Feb2024, Storms.m33Jun2024, Storms.x19Jan2026])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 60, child: GameText(st.flareClass, style: T.mono.copyWith(color: st.flareClass.startsWith('X') ? C.red : C.amber))),
              SizedBox(width: 110, child: GameText(st.date, style: T.bodySmall.copyWith(color: C.text))),
              Expanded(child: _SourceLink('NASA DONKI record', st.url)),
            ]),
          ),
        const HudDivider(),
        const SectionLabel('Simplified for the game'),
        const SizedBox(height: 6),
        for (final g in gameSimplifications)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const GameText('•  ', style: T.bodySmall),
              Expanded(child: GameText(g, style: T.bodySmall)),
            ]),
          ),
        const SizedBox(height: 10),
        const GameText(
          'Per crew member per day: O₂ ${Rates.o2PerDay} kg · water ${Rates.drinkWaterPerDay} kg + ${Rates.hygieneWaterPerDay} kg hygiene · food ${Rates.foodPerDay} kg · CO₂ ${Rates.co2PerDay} kg · surface dose ${Rates.surfaceDosePerDay} mSv',
          style: T.monoSmall,
        ),
      ]),
    );
  }
}

class _SourceLink extends StatelessWidget {
  final String label;
  final String url;
  const _SourceLink(this.label, this.url);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUrl(url),
      child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Flexible(child: GameText(label, style: T.bodySmall.copyWith(color: C.cyan, decoration: TextDecoration.underline, decorationColor: C.cyan))),
        const SizedBox(width: 4),
        const Icon(Icons.open_in_new_rounded, size: 12, color: C.cyan),
      ]),
    );
  }
}

// ---------------------------------------------------------------- TEACHER MODE

class TeacherScreen extends StatelessWidget {
  const TeacherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    return AnimatedBuilder(
      animation: sv.progress,
      builder: (context, _) => InfoFrame(
        title: 'TEACHER MODE',
        subtitle: 'Learning goals, the science, and discussion questions for each chapter',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.lock_open_rounded, color: C.cyan, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GameText('Unlock all missions', style: T.h3),
                GameText('Lets a class jump straight to any chapter.', style: T.bodySmall),
              ]),
            ),
            Switch(value: sv.progress.unlockAll, onChanged: (v) => sv.progress.setSetting('unlock_all', v)),
          ]),
          Row(children: [
            const Icon(Icons.lock_person_rounded, color: C.cyan, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GameText('Lock the rank: ${sv.progress.ageMode.title}', style: T.h3),
                const GameText('Students can\'t change the age mode on this device.', style: T.bodySmall),
              ]),
            ),
            Switch(value: sv.progress.rankLocked, onChanged: (v) => sv.progress.setSetting('rank_locked', v)),
          ]),
          const HudDivider(),
          const SectionLabel('Story levels: lessons and NASA links'),
          const SizedBox(height: 8),
          for (final camp in campaigns) ...[
            GameText(camp.title.toUpperCase(), style: T.label.copyWith(letterSpacing: 2, color: C.cyan)),
            const SizedBox(height: 8),
            for (final l in camp.infos)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(18)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  GameText('LEVEL ${l.n} · ${camp.task(l.n).title.toUpperCase()}', style: T.h3.copyWith(color: C.cyan)),
                  const SizedBox(height: 4),
                  _line('Moral lesson', l.moral),
                  _line('What NASA does', l.nasaDoes),
                  _line('The maths', l.howCalc),
                ]),
              ),
            const SizedBox(height: 8),
          ],
          const HudDivider(),
          const SectionLabel('Survival chapters'),
          const SizedBox(height: 8),
          const GameText(
            'Each mission takes 3 to 5 minutes. Suggested use: students play a chapter in pairs, then discuss the questions below. '
            'The Mission Data screen lists every real value and its source.',
            style: T.body,
          ),
          const SizedBox(height: 12),
          for (final t in teacherGuide) _chapter(t),
        ]),
      ),
    );
  }

  Widget _chapter(TeacherChapter t) {
    final ch = chapters.firstWhere((c) => c.number == t.chapter);
    final ms = missions.where((m) => m.chapter == t.chapter).map((m) => 'M${m.id} ${m.title}').join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GameText('CHAPTER ${t.chapter} · ${ch.title.toUpperCase()}', style: T.h3.copyWith(color: C.cyan)),
        GameText(ms, style: T.bodySmall),
        const SizedBox(height: 6),
        _line('Learning goal', t.goal),
        _line('The science', t.science),
        const SizedBox(height: 4),
        GameText('DISCUSSION', style: T.label.copyWith(fontSize: 9.5)),
        for (final q in t.questions)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const GameText('?  ', style: TextStyle(fontFamily: F.mono, color: C.amber)),
              Expanded(child: GameText(q, style: T.body.copyWith(fontSize: 13))),
            ]),
          ),
      ]),
    );
  }

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: RichText(
          text: TextSpan(children: [
            TextSpan(text: '$k: ', style: T.h3.copyWith(fontSize: 13)),
            TextSpan(text: v, style: T.body.copyWith(fontSize: 13)),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- SETTINGS

