import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/content.dart';
import '../data/levels.dart';
import '../data/missions.dart';
import '../data/story.dart' show storyTask;
import '../story/story_model.dart' show AgeModeInfo;
import '../engine/constants.dart';
import '../main.dart';
import '../ui/theme.dart';
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
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              IconButton(
                onPressed: () {
                  sv.audio.tap();
                  sv.nav.back();
                },
                icon: const Icon(Icons.arrow_back_rounded, color: C.frozen),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(context).padding.bottom),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_titleCase(title), style: T.hero.copyWith(fontSize: 34)),
                const SizedBox(height: 6),
                Text(subtitle, style: T.body.copyWith(color: C.muted)),
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
                child: const Row(children: [
                  const Expanded(flex: 3, child: const Text('QUANTITY', style: T.label)),
                  const Expanded(flex: 4, child: const Text('REAL VALUE', style: T.label)),
                  const Expanded(flex: 4, child: const Text('IN THE GAME', style: T.label)),
                  const Expanded(flex: 4, child: const Text('SOURCE', style: T.label)),
                ]),
              ),
            for (final d in missionData)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.lineSoft))),
                child: wide
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 3, child: Text(d.quantity, style: T.h3)),
                        Expanded(flex: 4, child: Text(d.realValue, style: T.mono.copyWith(fontSize: 12, color: C.cyan))),
                        Expanded(flex: 4, child: Text(d.inGame, style: T.bodySmall.copyWith(color: C.text))),
                        Expanded(flex: 4, child: _SourceLink(d.source, d.url)),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.quantity, style: T.h3),
                        Text(d.realValue, style: T.mono.copyWith(fontSize: 12, color: C.cyan)),
                        Text(d.inGame, style: T.bodySmall.copyWith(color: C.text)),
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
              SizedBox(width: 60, child: Text(st.flareClass, style: T.mono.copyWith(color: st.flareClass.startsWith('X') ? C.red : C.amber))),
              SizedBox(width: 110, child: Text(st.date, style: T.bodySmall.copyWith(color: C.text))),
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
              const Text('•  ', style: T.bodySmall),
              Expanded(child: Text(g, style: T.bodySmall)),
            ]),
          ),
        const SizedBox(height: 10),
        const Text(
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
        Flexible(child: Text(label, style: T.bodySmall.copyWith(color: C.cyan, decoration: TextDecoration.underline, decorationColor: C.cyan))),
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
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Unlock all missions', style: T.h3),
                const Text('Lets a class jump straight to any chapter.', style: T.bodySmall),
              ]),
            ),
            Switch(value: sv.progress.unlockAll, onChanged: (v) => sv.progress.setSetting('unlock_all', v)),
          ]),
          Row(children: [
            const Icon(Icons.lock_person_rounded, color: C.cyan, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Lock the rank: ${sv.progress.ageMode.title}', style: T.h3),
                const Text('Students can\'t change the age mode on this device.', style: T.bodySmall),
              ]),
            ),
            Switch(value: sv.progress.rankLocked, onChanged: (v) => sv.progress.setSetting('rank_locked', v)),
          ]),
          const HudDivider(),
          const SectionLabel('Story levels: lessons and NASA links'),
          const SizedBox(height: 8),
          for (final l in levelInfos)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('LEVEL ${l.n} · ${storyTask(l.n).title.toUpperCase()}', style: T.h3.copyWith(color: C.cyan)),
                const SizedBox(height: 4),
                _line('Moral lesson', l.moral),
                _line('What NASA does', l.nasaDoes),
                _line('The maths', l.howCalc),
              ]),
            ),
          const HudDivider(),
          const SectionLabel('Survival chapters'),
          const SizedBox(height: 8),
          const Text(
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
      decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CHAPTER ${t.chapter} · ${ch.title.toUpperCase()}', style: T.h3.copyWith(color: C.cyan)),
        Text(ms, style: T.bodySmall),
        const SizedBox(height: 6),
        _line('Learning goal', t.goal),
        _line('The science', t.science),
        const SizedBox(height: 4),
        Text('DISCUSSION', style: T.label.copyWith(fontSize: 9.5)),
        for (final q in t.questions)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('?  ', style: TextStyle(fontFamily: F.mono, color: C.amber)),
              Expanded(child: Text(q, style: T.body.copyWith(fontSize: 13))),
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _confirmReset = false;

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final p = sv.progress;
    return AnimatedBuilder(
      animation: p,
      builder: (context, _) => InfoFrame(
        title: 'SETTINGS',
        subtitle: 'Rank, sound, motion and text',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _toggle(Icons.volume_up_rounded, 'Sound effects', 'Beeps, alarms and ambience', p.sound, (v) async {
            await p.setSetting('sound', v);
            await sv.audio.refreshSettings();
          }),
          _toggle(Icons.music_note_rounded, 'Music', 'Menu music', p.music, (v) async {
            await p.setSetting('music', v);
            await sv.audio.refreshSettings();
          }),
          _toggle(Icons.vibration_rounded, 'Vibration', 'Haptic feedback on taps and alarms', p.haptics, (v) => p.setSetting('haptics', v)),
          _toggle(Icons.record_voice_over_rounded, 'Read lines aloud', 'Always on for Cadets; uses the phone\'s voice', p.voiceOn, (v) => p.setSetting('voice', v)),
          _toggle(Icons.animation_rounded, 'Reduced motion', 'Fades instead of zooms, no screen shake, no typing effect', p.reducedMotion, (v) => p.setSetting('reduced_motion', v)),
          _toggle(Icons.keyboard_rounded, 'Typing sound', 'Soft clicks while messages appear', p.typingSound, (v) => p.setSetting('typing_sound', v)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.military_tech_rounded, color: C.cyan),
            title: Text('Rank: ${p.ageMode.title} (${p.ageMode.ages})', style: T.h3),
            subtitle: Text(p.rankLocked ? 'Locked by your teacher' : 'Cadet, Explorer or Engineer', style: T.bodySmall),
            trailing: const Icon(Icons.chevron_right_rounded, color: C.muted),
            onTap: () {
              sv.nav.afterRank = Screen.title;
              sv.nav.go(Screen.rank);
            },
          ),
          _toggle(Icons.school_rounded, 'Tutorial hints', 'Mission Control pauses the game to explain new things', p.tutorialHints, (v) => p.setSetting('hints', v)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.text_fields_rounded, color: C.cyan, size: 20),
            const SizedBox(width: 10),
            const Text('Text speed', style: T.h3),
            Expanded(
              child: Slider(value: p.textSpeed, min: 0.5, max: 2.5, divisions: 8, onChanged: (v) => p.setSetting('text_speed', v)),
            ),
            SizedBox(width: 44, child: Text('${p.textSpeed.toStringAsFixed(1)}x', style: T.mono)),
          ]),
          const HudDivider(),
          Row(children: [
            const Expanded(child: const Text('Reset all progress: stars, badges and Nova\'s memories.', style: T.bodySmall)),
            if (!_confirmReset)
              HudButton(label: 'RESET', icon: Icons.restart_alt_rounded, compact: true, color: C.red, onTap: () => setState(() => _confirmReset = true))
            else ...[
              HudButton(label: 'CANCEL', compact: true, onTap: () => setState(() => _confirmReset = false)),
              const SizedBox(width: 8),
              HudButton(
                label: 'YES, RESET',
                compact: true,
                color: C.red,
                filled: true,
                onTap: () {
                  p.resetAll();
                  setState(() => _confirmReset = false);
                },
              ),
            ],
          ]),
          const HudDivider(),
          const Text('Credits', style: T.h3),
          const SizedBox(height: 4),
          const Text(
            'Made for the NASA Space Apps Challenge 2026: Build a Junior Astronaut Mission Trainer. '
            'Life support values: NASA. Lunar radiation: Chang\'e 4 LND. Solar storms: NASA DONKI. '
            'Moon maps: NASA Scientific Visualization Studio CGI Moon Kit (LRO). '
            'Fonts: Chakra Petch, IBM Plex Sans, JetBrains Mono (SIL Open Font License). Sounds synthesized for this game.',
            style: T.bodySmall,
          ),
        ]),
      ),
    );
  }

  Widget _toggle(IconData icon, String title, String sub, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, color: C.cyan, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.h3),
            Text(sub, style: T.bodySmall),
          ]),
        ),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }
}
