import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../ui/game_helper.dart';

import '../main.dart';
import '../story/story_model.dart';
import '../ui/theme.dart';
import '../ui/kit.dart';
import '../ui/widgets/common.dart';

/// Choose your age group: Little Explorer, Explorer or Engineer.
class RankScreen extends StatefulWidget {
  const RankScreen({super.key});

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen> {
  AgeMode? _picked;

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final p = sv.progress;
    final picked = _picked ?? p.ageMode;
    final locked = p.rankLocked;
    final bottom = MediaQuery.of(context).padding.bottom;
    return SpaceBackground(
      hill: true,
      child: Stack(children: [
        SafeArea(
          bottom: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                children: [
                  Row(children: [
                    if (p.rankChosen)
                      RoundButton(onTap: sv.nav.back)
                    else
                      const SizedBox(height: 44),
                  ]),
                  const SizedBox(height: 14),
                  Overline(p.rankChosen ? 'Your age group' : 'New crew member', color: C.cyan, size: 11.5),
                  const SizedBox(height: 4),
                  const GameText('Choose your age group', style: T.h1),
                  const SizedBox(height: 8),
                  GameText('Same Moon, same missions. Your age group sets how much reading, maths and pressure you get. You can change it any time.', style: T.body.copyWith(color: C.frozen.withValues(alpha: 0.85), fontSize: 15)),
                  const SizedBox(height: 22),
                  for (final m in AgeMode.values)
                    EnterAnim(
                      delayMs: 60 * m.index,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RankCard(
                          mode: m,
                          selected: picked == m,
                          onTap: locked
                              ? null
                              : () {
                                  sv.audio.tap();
                                  setState(() => _picked = m);
                                },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + bottom),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    Icon(locked ? Icons.lock_rounded : Icons.info_outline_rounded, color: C.muted, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: GameText(locked ? 'Your teacher chose the age group for the class.' : 'Teachers can choose the age group for the whole class.', style: T.body.copyWith(color: C.muted, fontSize: 13.5))),
                  ]),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: p.rankChosen ? 'Save' : 'Join the crew',
                  onTap: () async {
                    await p.setAgeMode(picked);
                    sv.audio.tap();
                    final to = sv.nav.afterRank;
                    if (to == Screen.title) {
                      sv.nav.resetTo(Screen.title);
                    } else {
                      sv.nav.go(to);
                    }
                  },
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _RankCard extends StatelessWidget {
  final AgeMode mode;
  final bool selected;
  final VoidCallback? onTap;
  const _RankCard({required this.mode, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = selected ? C.cyan : C.frozen;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.normal,
        curve: Motion.curve,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        decoration: BoxDecoration(
          color: selected ? C.raised : C.panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? C.cyan : Colors.transparent, width: 2.5),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 56, height: 56, child: CustomPaint(painter: _RankIcon(mode))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                GameText(mode.title, style: T.h3.copyWith(fontSize: 20, color: c)),
                GameText(mode.ages, style: T.body.copyWith(color: C.muted, fontSize: 13.5)),
                AnimatedOpacity(
                  duration: Motion.fast,
                  opacity: selected ? 1 : 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: C.cyan, borderRadius: BorderRadius.circular(10)),
                    child: GameText('CHOSEN', style: T.label.copyWith(color: C.ink, fontSize: 10, letterSpacing: 1.6)),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              GameText(mode.blurb, style: T.body.copyWith(fontSize: 14)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _RankIcon extends CustomPainter {
  final AgeMode mode;
  _RankIcon(this.mode);

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;
    final bg = switch (mode) {
      AgeMode.cadet => const Color(0xFF2A4F6E),
      AgeMode.explorer => const Color(0xFF2B3F7A),
      AgeMode.engineer => const Color(0xFF5A3A3A),
    };
    canvas.drawCircle(c, r, Paint()..color = bg);
    switch (mode) {
      case AgeMode.cadet:
        // a helmet with a gold visor and a star
        canvas.drawCircle(c + const Offset(0, 3), r * 0.48, Paint()..color = const Color(0xFFF6F6F2));
        canvas.drawOval(Rect.fromCenter(center: c + const Offset(0, 5), width: r * 0.68, height: r * 0.48), Paint()..color = const Color(0xFF2E3FB8));
        canvas.drawPath(sparklePath(c - Offset(0, r * 0.52), r * 0.24), Paint()..color = C.cyan);
        break;
      case AgeMode.explorer:
        final body = Path()
          ..moveTo(c.dx, c.dy - r * 0.62)
          ..quadraticBezierTo(c.dx + r * 0.3, c.dy - r * 0.2, c.dx + r * 0.2, c.dy + r * 0.38)
          ..lineTo(c.dx - r * 0.2, c.dy + r * 0.38)
          ..quadraticBezierTo(c.dx - r * 0.3, c.dy - r * 0.2, c.dx, c.dy - r * 0.62)
          ..close();
        canvas.drawPath(body, Paint()..color = Colors.white);
        canvas.drawCircle(c - Offset(0, r * 0.12), r * 0.13, Paint()..color = C.cyan);
        canvas.drawPath(Path()..moveTo(c.dx - r * 0.2, c.dy + r * 0.15)..lineTo(c.dx - r * 0.38, c.dy + r * 0.45)..lineTo(c.dx - r * 0.18, c.dy + r * 0.38)..close(), Paint()..color = C.sapphire);
        canvas.drawPath(Path()..moveTo(c.dx + r * 0.2, c.dy + r * 0.15)..lineTo(c.dx + r * 0.38, c.dy + r * 0.45)..lineTo(c.dx + r * 0.18, c.dy + r * 0.38)..close(), Paint()..color = C.sapphire);
        canvas.drawPath(Path()..moveTo(c.dx - r * 0.12, c.dy + r * 0.4)..lineTo(c.dx + r * 0.12, c.dy + r * 0.4)..lineTo(c.dx, c.dy + r * 0.62)..close(), Paint()..color = C.cyan);
        break;
      case AgeMode.engineer:
        final gear = Paint()..color = C.cyan;
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(a);
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, -r * 0.5), width: r * 0.2, height: r * 0.22), const Radius.circular(2)), gear);
          canvas.restore();
        }
        canvas.drawCircle(c, r * 0.42, Paint()
          ..color = C.cyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.13);
        canvas.drawCircle(c, r * 0.16, Paint()..color = C.sapphire);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _RankIcon old) => old.mode != mode;
}
