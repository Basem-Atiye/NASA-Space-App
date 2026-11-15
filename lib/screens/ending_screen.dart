import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../ui/game_helper.dart';

import '../data/catalogue.dart';
import '../data/story.dart';
import '../main.dart';
import '../story/campaign.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import '../ui/widgets/space_art.dart';
import '../world/world_art.dart';

/// The last card: the ascent stage climbing toward Earth and the final
/// message from the master task order, with the mission numbers.
class EndingScreen extends StatefulWidget {
  const EndingScreen({super.key});

  @override
  State<EndingScreen> createState() => _EndingScreenState();
}

class _EndingScreenState extends State<EndingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final p = sv.progress;
    final camp = campaignById(sv.nav.endingCampaign);
    final upTo = sv.nav.endingLevel.clamp(1, camp.length);
    double dose = 0;
    int mistakes = 0;
    try {
      final j = jsonDecode(p.carryFor(camp.id)) as Map<String, dynamic>;
      dose = (j['dose'] as num?)?.toDouble() ?? 0;
      mistakes = (j['mistakes'] as num?)?.toInt() ?? 0;
    } catch (_) {}
    var total = 0;
    for (var n = 1; n <= upTo; n++) {
      total += p.storyStars(n, camp);
    }
    final avg = (total / upTo).round().clamp(1, 3);
    final seasonOne = camp.id == CampaignId.explorer && upTo <= 10;
    final (kicker, heading, message) = switch (camp.id) {
      CampaignId.cadet => ('TRAINING COMPLETE', 'Moon Cadet!', 'You finished Moon Cadet training. You can suit up, share power fairly, grow food, clean water and talk to Earth. Commander Nova is proud of you!'),
      CampaignId.engineer => ('SOL 40 · DESIGN APPROVED', 'Artemis Base Camp', 'From a launch window to a Mars plan: every decision you made used real NASA numbers. Your station design is on its way to the Mars team.'),
      _ when seasonOne => ('DAY $rescueDays · LIFT-OFF', 'Going home', '$finalMessage Season 2 is unlocked: come back with a crew and build the station.'),
      _ => ('SEASON 2 COMPLETE', 'Shackleton Station', 'A crash site became a station with a crew, a garden and its own water. Mission accomplished, Commander.'),
    };
    final bottom = MediaQuery.of(context).padding.bottom;
    return ColoredBox(
      color: C.bg,
      child: Stack(fit: StackFit.expand, children: [
        AnimatedBuilder(animation: _t, builder: (context, _) => CustomPaint(painter: _EndPainter(_t.value * 60))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GameText(kicker, style: T.label.copyWith(letterSpacing: 4, fontSize: 12)),
              const SizedBox(height: 6),
              GameText(heading, style: T.h1.copyWith(fontFamily: F.display, fontWeight: FontWeight.w800, fontSize: 32, letterSpacing: 1.5)),
            ]),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16 + bottom,
          child: EnterAnim(
            delayMs: 300,
            dy: 40,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(color: C.indigo.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(26)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  GameText('MISSION COMPLETE', style: T.label.copyWith(letterSpacing: 3, fontSize: 12)),
                  const Spacer(),
                  StarRow(stars: avg, size: 20),
                ]),
                const SizedBox(height: 12),
                GameText(message, style: T.h3.copyWith(fontSize: 17, height: 1.35)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _stat('LEVELS', '$upTo')),
                  const SizedBox(width: 8),
                  Expanded(child: _stat('DOSE', '${dose.toStringAsFixed(1)} mSv')),
                  const SizedBox(width: 8),
                  Expanded(child: _stat('MISTAKES', '$mistakes')),
                ]),
                const SizedBox(height: 14),
                if (p.assessment(camp.id, 'post') == null) ...[
                  HudButton(label: 'TAKE THE FINAL READINESS CHECK', icon: Icons.quiz_rounded, onTap: () => sv.nav.go(Screen.readiness)),
                  const SizedBox(height: 10),
                ],
                if (seasonOne) ...[
                  PrimaryButton(
                    label: 'Start Season 2 · Level 11',
                    icon: Icons.rocket_launch_rounded,
                    onTap: () {
                      sv.audio.tap();
                      sv.nav.endStory(to: Screen.map);
                      // Jump straight into the newly unlocked season.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!context.mounted) return;
                        sv.nav.startStory(11, sv);
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  HudButton(label: 'Back to Mission Control', icon: Icons.home_rounded, onTap: () => sv.nav.resetTo(Screen.title)),
                ] else
                  PrimaryButton(
                    label: 'Back to Mission Control',
                    icon: Icons.home_rounded,
                    color: C.cyan,
                    textColor: C.ink,
                    onTap: () => sv.nav.resetTo(Screen.title),
                  ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: C.panelDeep.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          GameText(label, style: T.bodySmall.copyWith(fontSize: 12)),
          const SizedBox(height: 2),
          FittedBox(child: GameText(value, style: T.h3.copyWith(fontSize: 17))),
        ]),
      );
}

class _EndPainter extends CustomPainter {
  final double t;
  _EndPainter(this.t);

  @override
  void paint(Canvas c, Size s) {
    final u = s.width / 390;
    final rnd = math.Random(9);
    for (var i = 0; i < 60; i++) {
      c.drawCircle(Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height * 0.75), i % 7 == 0 ? 1.4 : 0.8, Paint()..color = Colors.white.withValues(alpha: 0.4 + 0.5 * (0.5 + 0.5 * math.sin(t * 2 + i))));
    }
    paintEarth(c, Offset(s.width * 0.77, s.height * 0.23), s.width * 0.19, t * 3);
    // the Moon's horizon far below
    final r = Rect.fromCenter(center: Offset(s.width / 2, s.height * 0.86 + s.width * 1.3), width: s.width * 2.8, height: s.width * 2.8);
    c.drawOval(r, Paint()..shader = const RadialGradient(center: Alignment(0, -1), radius: 1.0, colors: [Color(0xFFCFCBC4), Color(0xFF6E6A63), Color(0xFF1A1917)], stops: [0, 0.25, 1]).createShader(r));
    // the ascent stage climbing, with its flame
    final bob = math.sin(t * 1.5) * 4 * u;
    c.save();
    c.translate(s.width / 2, s.height * 0.6 + bob);
    c.scale(1.5 * u);
    final flick = 0.85 + 0.15 * math.sin(t * 40);
    final h = 120 * flick;
    c.drawPath(
      Path()
        ..moveTo(-10, -61)
        ..cubicTo(-16, -61 + h * 0.6, 16, -61 + h * 0.6, 10, -61)
        ..close(),
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFFFC77A), Color(0x00FF9A3C)]).createShader(Rect.fromLTWH(-16, -61, 32, h)),
    );
    paintAscentStage(c, t);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _EndPainter old) => old.t != t;
}
