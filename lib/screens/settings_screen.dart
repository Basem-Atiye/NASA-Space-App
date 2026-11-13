/// Figma 18 Settings: Sound, Player, More. Every setting of the game is
/// here, grouped the way the design groups them.
library;

import 'package:flutter/material.dart';

import '../base/ui/base_screens.dart';
import '../main.dart';
import '../story/story_model.dart';
import '../ui/kit.dart';
import '../ui/line_icons.dart';
import '../ui/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final p = sv.progress;
    return SpaceBackground(
      child: SafeArea(
        child: PhoneColumn(
          child: Column(children: [
            ScreenHeader(title: 'Settings', onBack: () => sv.nav.back()),
            Expanded(
              child: ListenableBuilder(
                listenable: p,
                builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 30), children: [
                  const Overline('Sound'),
                  const SizedBox(height: 10),
                  _Group([
                    _toggleRow('Sound effects', p.sound, (v) async {
                      await p.setSetting('sound', v);
                      sv.session.saveSettings();
                    }),
                    _toggleRow('Music', p.music, (v) async {
                      await p.setSetting('music', v);
                      sv.audio.refreshSettings();
                      sv.session.saveSettings();
                    }),
                    _toggleRow('Vibration', p.haptics, (v) => p.setSetting('haptics', v)),
                    _toggleRow('Read lines aloud', p.voiceOn, (v) => p.setSetting('voice', v)),
                    _toggleRow('Typing sound', p.typingSound, (v) => p.setSetting('typing_sound', v)),
                  ]),
                  const SizedBox(height: 22),
                  const Overline('Player'),
                  const SizedBox(height: 10),
                  _Group([
                    _row(
                      'Age group',
                      trailing: _value(levelName(sv)),
                      onTap: p.rankLocked
                          ? () => _note(context, 'Your teacher set your age group.')
                          : () {
                              sv.nav.afterRank = Screen.settings;
                              sv.nav.go(Screen.rank);
                            },
                    ),
                    _row('Text size', trailing: SegmentPicker(labels: const ['A', 'A', 'A'], sizes: const [13, 16, 20], value: p.textSize, onChanged: (v) => p.setSetting('text_size', v))),
                    _row(
                      'Text speed',
                      trailing: SegmentPicker(labels: const ['Slow', 'Normal', 'Fast'], value: p.textSpeed < 0.9 ? 0 : (p.textSpeed > 1.4 ? 2 : 1), onChanged: (v) => p.setSetting('text_speed', const [0.7, 1.0, 1.8][v])),
                    ),
                    _row('Language', trailing: _value('English'), onTap: () => _note(context, 'The game is written in simple English for school readers.')),
                  ]),
                  const SizedBox(height: 22),
                  const Overline('Comfort'),
                  const SizedBox(height: 10),
                  _Group([
                    _toggleRow('Reduced motion', p.reducedMotion, (v) => p.setSetting('reduced_motion', v)),
                    _toggleRow('Tutorial hints', p.tutorialHints, (v) => p.setSetting('hints', v)),
                  ]),
                  const SizedBox(height: 22),
                  const Overline('More'),
                  const SizedBox(height: 10),
                  _Group([
                    _row('Account', trailing: _value(sv.session.signedIn ? sv.session.name : 'Guest'), onTap: () => sv.nav.go(Screen.account)),
                    _row('About the game', trailing: _chev(), onTap: () => _about(context)),
                    _row('Reset progress', color: C.red, onTap: () => _reset(context)),
                  ]),
                  const SizedBox(height: 18),
                  Center(child: Text('Level ${p.ageMode.title} · ${p.ageMode.ages}', style: T.bodySmall)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) => _row(label, trailing: KitToggle(value: value, onChanged: onChanged));

  Widget _row(String label, {Widget? trailing, VoidCallback? onTap, Color color = C.frozen}) => InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(children: [
            Expanded(child: Text(label, style: T.h3.copyWith(fontSize: 17.5, color: color))),
            if (trailing != null) trailing,
          ]),
        ),
      );

  Widget _value(String v) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text(v, style: T.body.copyWith(color: C.muted, fontSize: 16)),
        const SizedBox(width: 8),
        _chev(),
      ]);

  Widget _chev() => const LineIcon(Ln.next, size: 20, color: C.frozen);

  void _note(BuildContext context, String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: C.raised, content: Text(text, style: T.body)));

  void _about(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: C.panel, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SheetHandle(),
          const SizedBox(height: 18),
          const Text('Mission Trainer', style: T.h1),
          const SizedBox(height: 8),
          Text(
            'Made for the NASA Space Apps Challenge 2026: Build a Junior Astronaut Mission Trainer (Beirut).\n\n'
            'Life support numbers: NASA. Lunar radiation: Chang\'e 4. Solar storms: NASA DONKI. Moonquakes: Apollo seismometers. '
            'Polar ice: LCROSS.\n\nFonts: Fredoka and Nunito (SIL Open Font License). Icons in the style of Lucide (ISC). Sounds made for this game.',
            style: T.body.copyWith(color: C.frozen.withValues(alpha: 0.85)),
          ),
        ]),
      ),
    );
  }

  Future<void> _reset(BuildContext context) async {
    final sv = Services.of(context);
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xB3050A1E),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ModalCard(
          edge: C.red,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const GlowDisc(icon: Ln.refresh, color: C.red, size: 80),
            const SizedBox(height: 14),
            const Text('Reset everything?', style: T.h2),
            const SizedBox(height: 8),
            Text('All stars, badges and saved games on this phone will be deleted.', textAlign: TextAlign.center, style: T.body.copyWith(color: C.muted)),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: KitButton('Cancel', style: KitButtonStyle.secondary, onTap: () => Navigator.pop(ctx, false))),
              const SizedBox(width: 12),
              Expanded(child: KitButton('Reset', style: KitButtonStyle.danger, onTap: () => Navigator.pop(ctx, true))),
            ]),
          ]),
        ),
      ),
    );
    if (ok == true) {
      await sv.progress.resetAll();
      await sv.base.resetAll();
      if (context.mounted) _note(context, 'Progress reset.');
    }
  }
}

/// A rounded group of rows with thin dividers (the design's settings card).
class _Group extends StatelessWidget {
  final List<Widget> rows;
  const _Group(this.rows);

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: C.panel,
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i < rows.length - 1) const Divider(height: 1, thickness: 1, color: Color(0xFF4A4378)),
            ],
          ]),
        ),
      );
}
