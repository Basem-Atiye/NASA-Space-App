import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../main.dart';
import '../story/story_model.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';

/// Choose your rank: Cadet, Explorer or Engineer (the three age modes).
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
    return AuroraBackground(
      child: Stack(children: [
        // the Moon's horizon peeks in at the bottom
        Positioned(
          left: -60,
          right: -60,
          bottom: -320,
          height: 420,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(center: const Alignment(0, -1), radius: 1.0, colors: [const Color(0xFF8E8B84).withValues(alpha: 0.9), const Color(0xFF3A3834).withValues(alpha: 0.6)]),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                children: [
                  Row(children: [
                    if (p.rankChosen)
                      IconButton(onPressed: sv.nav.back, icon: const Icon(Icons.arrow_back_rounded, color: C.frozen))
                    else
                      const SizedBox(height: 48),
                  ]),
                  Text(p.rankChosen ? 'YOUR CREW RANK' : 'NEW CREW MEMBER', style: T.label.copyWith(letterSpacing: 4, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('Choose your rank', style: T.hero.copyWith(fontSize: 34)),
                  const SizedBox(height: 10),
                  Text('Same mission, same Moon. Your rank sets how much reading, maths and pressure you get. You can change it any time.', style: T.body.copyWith(color: C.muted, fontSize: 15)),
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
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
                  child: Row(children: [
                    Icon(locked ? Icons.lock_rounded : Icons.info_outline_rounded, color: C.muted, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(locked ? 'Your teacher locked the rank for the class.' : 'Teachers can lock a rank for the whole class.', style: T.body.copyWith(color: C.muted, fontSize: 13.5))),
                  ]),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: p.rankChosen ? 'Save rank' : 'Join the crew',
                  onTap: () async {
                    await p.setAgeMode(picked);
                    sv.audio.tap();
                    final to = sv.nav.afterRank;
                    if (to == Screen.title) {
                      sv.nav.back();
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
    final c = mode == AgeMode.cadet ? C.frozen : C.cyan;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.normal,
        curve: Motion.curve,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        decoration: BoxDecoration(
          color: C.panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? C.cyan : C.line, width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: C.cyan.withValues(alpha: 0.28), blurRadius: 26)] : null,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 56, height: 56, child: CustomPaint(painter: _RankIcon(mode))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                Text(mode.title.toUpperCase(), style: T.h3.copyWith(fontSize: 18, letterSpacing: 2, color: c, fontWeight: FontWeight.w800)),
                Text(mode.ages, style: T.body.copyWith(color: C.muted, fontSize: 13.5)),
                AnimatedOpacity(
                  duration: Motion.fast,
                  opacity: selected ? 1 : 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: C.cyan, borderRadius: BorderRadius.circular(10)),
                    child: Text('SELECTED', style: T.label.copyWith(color: C.evergreen, fontSize: 10, letterSpacing: 1.6)),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text(mode.blurb, style: T.body.copyWith(fontSize: 14)),
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
      AgeMode.cadet => const Color(0xFF0E3A26),
      AgeMode.explorer => const Color(0xFF0E2C4A),
      AgeMode.engineer => const Color(0xFF3A2414),
    };
    canvas.drawCircle(c, r, Paint()..color = bg);
    switch (mode) {
      case AgeMode.cadet:
        // a helmet with a gold visor and a star
        canvas.drawCircle(c + const Offset(0, 3), r * 0.48, Paint()..color = const Color(0xFFF6F6F2));
        canvas.drawOval(Rect.fromCenter(center: c + const Offset(0, 5), width: r * 0.68, height: r * 0.48), Paint()..color = const Color(0xFFF2B544));
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
