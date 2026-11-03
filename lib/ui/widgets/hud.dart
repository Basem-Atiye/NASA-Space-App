import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/messages.dart';
import '../../engine/mission.dart';
import '../../engine/simulation.dart';
import '../../game/game_controller.dart';
import '../theme.dart';
import 'avatar.dart';
import 'common.dart';

// ---------------------------------------------------------------- gauges

class GaugeData {
  final String label;
  final IconData icon;
  final String value;
  final String? sub;
  final double frac;
  final Color color;
  final bool critical;
  final String id;
  const GaugeData(this.id, this.label, this.icon, this.value, this.sub, this.frac, this.color, {this.critical = false});
}

List<GaugeData> gaugesFor(MissionSim s) {
  final o2Left = s.o2HoursLeft;
  final wLeft = s.waterHoursLeft;
  final fLeft = s.foodHoursLeft;
  final bLeft = s.batteryHoursLeft;
  Color byLeft(double? h, double frac) {
    if (h != null && h < 6) return C.red;
    if (h != null && h < 18) return C.amber;
    return levelColor(frac);
  }

  final o2f = (s.o2Days / 3).clamp(0.0, 1.0).toDouble();
  final wf = (s.waterDays / 3).clamp(0.0, 1.0).toDouble();
  final ff = (s.foodDays / 3).clamp(0.0, 1.0).toDouble();
  final bf = s.batteryCap > 0 ? s.battery / s.batteryCap : 0.0;
  final df = (s.dose / s.mission.doseLimit).clamp(0.0, 1.0).toDouble();
  return [
    GaugeData('o2', 'OXYGEN', Icons.air_rounded, '${s.o2.toStringAsFixed(1)} kg', formatHours(o2Left), o2f, byLeft(o2Left, o2f),
        critical: s.o2 <= 0 || (o2Left != null && o2Left < 6)),
    GaugeData('water', 'WATER', Icons.water_drop_rounded, '${s.water.toStringAsFixed(1)} kg', formatHours(wLeft), wf, byLeft(wLeft, wf),
        critical: s.water <= 0 || (wLeft != null && wLeft < 6)),
    GaugeData('food', 'FOOD', Icons.restaurant_rounded, '${s.food.toStringAsFixed(1)} kg', formatHours(fLeft), ff, byLeft(fLeft, ff),
        critical: s.food <= 0),
    GaugeData('power', 'BATTERY', Icons.battery_charging_full_rounded, '${s.battery.toStringAsFixed(0)}/${s.batteryCap.toStringAsFixed(0)} kWh',
        s.netKw >= 0 ? '+${s.netKw.toStringAsFixed(1)} kW' : formatHours(bLeft), bf, s.brownout ? C.red : (s.netKw < 0 ? byLeft(bLeft, bf) : C.green),
        critical: s.brownout),
    GaugeData('dose', 'DOSE', Icons.radar_rounded, '${s.dose.toStringAsFixed(1)} mSv', 'limit ${s.mission.doseLimit.toStringAsFixed(0)}', df,
        df > 0.85 ? C.red : (df > 0.6 ? C.amber : (s.stormActive ? C.violet : C.cyan)),
        critical: df > 0.85),
    GaugeData('health', 'HEALTH', Icons.favorite_rounded, '${s.health.toStringAsFixed(0)}%', null, s.health / 100,
        s.health < 35 ? C.red : (s.health < 60 ? C.amber : C.green),
        critical: s.health < 35),
    GaugeData('morale', 'MORALE', Icons.mood_rounded, '${s.morale.toStringAsFixed(0)}%', null, s.morale / 100,
        s.morale < 30 ? C.amber : C.cyan),
  ];
}

class GaugeColumn extends StatelessWidget {
  final MissionSim sim;
  final void Function(String id) onTap;
  const GaugeColumn({super.key, required this.sim, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gs = gaugesFor(sim);
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (final g in gs) _row(g)],
        ),
      ),
    );
  }

  Widget _row(GaugeData g) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(g.id),
      child: Pulse(
        active: g.critical,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
          child: Row(
            children: [
              RingGauge(value: g.frac, color: g.color, icon: g.icon, size: 30),
              const SizedBox(width: 8),
              SizedBox(
                width: 112,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(g.label, style: T.label.copyWith(fontSize: 9.5, color: C.muted)),
                        const Spacer(),
                        if (g.sub != null) Text(g.sub!, style: T.monoSmall.copyWith(fontSize: 9.5, color: g.color)),
                      ],
                    ),
                    Text(g.value, style: T.mono.copyWith(fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Survival resources as a strip of tiles across the top (portrait).
class GaugeStrip extends StatelessWidget {
  final MissionSim sim;
  final void Function(String id) onTap;
  const GaugeStrip({super.key, required this.sim, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gs = gaugesFor(sim);
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: gs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final g = gs[i];
          return GestureDetector(
            onTap: () => onTap(g.id),
            child: Pulse(
              active: g.critical,
              child: Container(
                width: 92,
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: g.color.withValues(alpha: 0.5))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Row(children: [
                    Icon(g.icon, size: 12, color: g.color),
                    const SizedBox(width: 4),
                    Expanded(child: Text(g.label, style: T.label.copyWith(fontSize: 9.5, letterSpacing: 1, color: g.color), overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 3),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(g.value, style: T.h3.copyWith(fontSize: 14))),
                  if (g.sub != null) Text(g.sub!, style: T.bodySmall.copyWith(fontSize: 10, color: C.dim), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- top bar

class TopBar extends StatelessWidget {
  final GameController g;
  final VoidCallback onMenu;
  const TopBar({super.key, required this.g, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final s = g.sim;
    final frac = s.hour / s.mission.totalHours;
    Widget chip(String text, Color c, IconData icon) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c.withValues(alpha: 0.7)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 5),
            Text(text, style: T.label.copyWith(color: c, fontSize: 10)),
          ]),
        );

    final chips = <Widget>[
      s.sun ? chip('SUNLIGHT', C.amber, Icons.wb_sunny_rounded) : chip('NIGHT', C.violet, Icons.nightlight_round),
      if (s.stormWarning) chip('PROTONS IN ${s.storm!.hoursLeft}h', C.amber, Icons.warning_amber_rounded),
      if (s.stormActive) chip('STORM ${s.storm!.hoursLeft}h', C.red, Icons.flare_rounded),
      if (s.onEva) chip('EVA', C.cyan, Icons.directions_walk_rounded),
      if (s.location == CrewLocation.shelter) chip('IN SHELTER', C.green, Icons.shield_rounded),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('MISSION ${s.mission.id} · ${s.mission.title.toUpperCase()}', style: T.label.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(missionClock(s.hour), style: T.h1.copyWith(fontFamily: F.display, fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: 1)),
            const SizedBox(height: 4),
            Row(children: [
              SizedBox(
                width: 110,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(value: frac.clamp(0.0, 1.0).toDouble(), minHeight: 3, backgroundColor: C.lineSoft, color: C.cyan),
                ),
              ),
              const SizedBox(width: 8),
              Text('${s.hoursLeft} h left', style: T.bodySmall.copyWith(fontSize: 12)),
            ]),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _speedButton(Icons.pause_rounded, g.userPaused, g.togglePause),
            _speedButton(null, !g.userPaused && g.speed == 1, () => g.setSpeed(1), label: '1x'),
            _speedButton(null, !g.userPaused && g.speed == 2, () => g.setSpeed(2), label: '2x'),
            _speedButton(null, !g.userPaused && g.speed == 4, () => g.setSpeed(4), label: '4x'),
            _speedButton(Icons.menu_rounded, false, onMenu),
          ]),
        ),
      ]),
      if (chips.isNotEmpty) ...[
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [for (final c in chips) Padding(padding: const EdgeInsets.only(right: 6), child: c)]),
        ),
      ],
    ]);
  }

  Widget _speedButton(IconData? icon, bool active, VoidCallback onTap, {String? label}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? C.sapphire : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: icon != null
            ? Icon(icon, size: 18, color: active ? Colors.white : C.muted)
            : Text(label ?? '', style: T.h3.copyWith(fontSize: 12.5, color: active ? Colors.white : C.muted)),
      ),
    );
  }
}

// ---------------------------------------------------------------- typewriter

class Typewriter extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double speed; // multiplier
  final ValueChanged<bool>? onTyping;
  const Typewriter({super.key, required this.text, required this.style, this.speed = 1, this.onTyping});

  @override
  State<Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<Typewriter> {
  int _n = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant Typewriter old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _start();
  }

  void _start() {
    _t?.cancel();
    _n = 0;
    widget.onTyping?.call(true);
    final ms = (22 / widget.speed).round().clamp(5, 80).toInt();
    _t = Timer.periodic(Duration(milliseconds: ms), (t) {
      if (!mounted) return;
      setState(() => _n += 1);
      if (_n >= widget.text.length) {
        t.cancel();
        widget.onTyping?.call(false);
      }
    });
  }

  void complete() {
    _t?.cancel();
    setState(() => _n = widget.text.length);
    widget.onTyping?.call(false);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.text.substring(0, _n.clamp(0, widget.text.length).toInt());
    return GestureDetector(
      onTap: complete,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: shown),
          TextSpan(text: widget.text.substring(shown.length), style: const TextStyle(color: Colors.transparent)),
        ]),
        style: widget.style,
      ),
    );
  }
}

// ---------------------------------------------------------------- Nova card and latest message

class CrewCard extends StatefulWidget {
  final GameController g;
  final VoidCallback onOpenLog;
  final double textSpeed;
  const CrewCard({super.key, required this.g, required this.onOpenLog, required this.textSpeed});

  @override
  State<CrewCard> createState() => _CrewCardState();
}

class _CrewCardState extends State<CrewCard> {
  bool _typing = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final s = g.sim;
    final mood = moodFor(s);
    final last = g.feed.isEmpty ? null : g.feed.last;
    String status;
    if (s.onEva) {
      status = 'EVA · ${evaName(s.eva!)} · ${s.evaLeft}h left';
    } else {
      status = activityName(s.activity);
      if (s.activity == Activity.repair && s.repairTarget != null) {
        status = 'Repairing ${systemName(s.repairTarget!)} ${(s.repairProgress * 100).round()}%';
      }
    }
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AstronautAvatar(mood: mood, size: 52, talking: _typing && last?.message.speaker == Speaker.nova),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CMDR. NOVA HADDAD', style: T.h3.copyWith(fontSize: 12.5)),
                    const SizedBox(height: 2),
                    Text(status, style: T.bodySmall.copyWith(color: C.cyan, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Row(children: [
                      Text('FATIGUE', style: T.label.copyWith(fontSize: 8.5)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: s.fatigue / 100,
                            minHeight: 4,
                            backgroundColor: C.lineSoft,
                            color: s.fatigue > 70 ? C.amber : C.cyan,
                          ),
                        ),
                      ),
                      if (s.crew > 1) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.groups_rounded, size: 14, color: C.muted),
                        Text(' ${s.crew}', style: T.monoSmall),
                      ],
                    ]),
                  ],
                ),
              ),
            ],
          ),
          if (last != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: widget.onOpenLog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: C.bg.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: speakerColor(last.message.speaker).withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(speakerName(last.message.speaker).toUpperCase(),
                          style: T.label.copyWith(fontSize: 9, color: speakerColor(last.message.speaker))),
                      const Spacer(),
                      Text('LOG ${g.feed.length}', style: T.monoSmall.copyWith(fontSize: 9)),
                      const Icon(Icons.chevron_right_rounded, size: 14, color: C.muted),
                    ]),
                    const SizedBox(height: 3),
                    Typewriter(
                      key: ValueKey(g.feed.length),
                      text: last.message.text,
                      style: T.body.copyWith(fontSize: 12.5),
                      speed: widget.textSpeed,
                      onTyping: (t) {
                        if (mounted && t != _typing) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _typing = t);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- objectives strip

class ObjectivesStrip extends StatelessWidget {
  final MissionSim s;
  const ObjectivesStrip({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    final m = s.mission;
    if (!m.hasObjectives) return const SizedBox.shrink();
    final items = <Widget>[];
    Widget item(String label, bool done, String value) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 14, color: done ? C.green : C.muted),
            const SizedBox(width: 5),
            Text('$label ', style: T.label.copyWith(fontSize: 9.5, color: done ? C.green : C.muted)),
            Text(value, style: T.mono.copyWith(fontSize: 11)),
          ]),
        );
    if (m.iceGoal > 0) items.add(item('ICE', s.iceMined >= m.iceGoal, '${s.iceMined.toStringAsFixed(0)}/${m.iceGoal.toStringAsFixed(0)} kg'));
    if (m.samplesGoal > 0) items.add(item('SAMPLES', s.samples >= m.samplesGoal, '${s.samples}/${m.samplesGoal}'));
    if (m.panelGoal) items.add(item('PANEL', s.panelInstalled, s.panelInstalled ? 'done' : 'to do'));
    if (m.bermGoal) items.add(item('SHIELDING', s.berm, s.berm ? 'built' : 'to do'));
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      brackets: false,
      blur: false,
      child: Row(mainAxisSize: MainAxisSize.min, children: items),
    );
  }
}

// ---------------------------------------------------------------- event banner

class EventBanner extends StatefulWidget {
  final BannerInfo? info;
  const EventBanner({super.key, required this.info});

  @override
  State<EventBanner> createState() => _EventBannerState();
}

class _EventBannerState extends State<EventBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400));
  int _shownId = -1;

  @override
  void didUpdateWidget(covariant EventBanner old) {
    super.didUpdateWidget(old);
    _maybePlay();
  }

  @override
  void initState() {
    super.initState();
    _maybePlay();
  }

  void _maybePlay() {
    final i = widget.info;
    if (i != null && i.id != _shownId) {
      _shownId = i.id;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.info;
    if (i == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;
          double o;
          if (v < 0.08) {
            o = v / 0.08;
          } else if (v > 0.85) {
            o = (1 - v) / 0.15;
          } else {
            o = 1;
          }
          if (_c.status == AnimationStatus.dismissed || v >= 1) o = 0;
          final slide = (1 - Curves.easeOutBack.transform((v / 0.12).clamp(0.0, 1.0).toDouble())) * -30;
          return Opacity(
            opacity: o.clamp(0.0, 1.0).toDouble(),
            child: Transform.translate(
              offset: Offset(0, slide),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    i.color.withValues(alpha: 0.0),
                    i.color.withValues(alpha: 0.28),
                    i.color.withValues(alpha: 0.28),
                    i.color.withValues(alpha: 0.0),
                  ], stops: const [0, 0.2, 0.8, 1]),
                  border: Border.symmetric(horizontal: BorderSide(color: i.color.withValues(alpha: 0.8))),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(i.icon, color: i.color, size: 20),
                  const SizedBox(width: 10),
                  Text(i.text, style: T.h2.copyWith(color: C.text, letterSpacing: 2.5, fontSize: 17, shadows: [
                    Shadow(color: i.color, blurRadius: 12),
                  ])),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- important message modal

class MessageModal extends StatefulWidget {
  final GameMessage message;
  final double textSpeed;
  final void Function(Reply? r) onDone;
  const MessageModal({super.key, required this.message, required this.onDone, required this.textSpeed});

  @override
  State<MessageModal> createState() => _MessageModalState();
}

class _MessageModalState extends State<MessageModal> {
  bool _typing = true;
  final _tw = GlobalKey<_TypewriterState>();

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final color = speakerColor(m.speaker);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.9, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Transform.scale(scale: v, child: child),
          child: GlassPanel(
            borderColor: color == C.text ? C.cyan : color,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  SpeakerAvatar(speaker: m.speaker, mood: m.mood, size: 56, talking: _typing),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(speakerName(m.speaker).toUpperCase(), style: T.h3.copyWith(color: color == C.text ? C.text : color)),
                      Text(speakerRole(m.speaker), style: T.bodySmall),
                    ]),
                  ),
                  const Icon(Icons.wifi_tethering_rounded, color: C.muted, size: 18),
                ]),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _tw.currentState?.complete(),
                  child: Typewriter(
                    key: _tw,
                    text: m.text,
                    style: T.body.copyWith(fontSize: 15),
                    speed: widget.textSpeed,
                    onTyping: (t) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _typing != t) setState(() => _typing = t);
                      });
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: m.replies.isEmpty
                      ? [HudButton(label: 'COPY THAT', icon: Icons.check_rounded, filled: true, onTap: () => widget.onDone(null))]
                      : [for (final r in m.replies) HudButton(label: r.label, filled: true, onTap: () => widget.onDone(r))],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- cargo choice

class CargoModal extends StatelessWidget {
  final List<CargoChoice> options;
  final void Function(CargoChoice c) onChoose;
  const CargoModal({super.key, required this.options, required this.onChoose});

  IconData _icon(CargoChoice c) {
    switch (c) {
      case CargoChoice.water:
        return Icons.water_drop_rounded;
      case CargoChoice.food:
        return Icons.restaurant_rounded;
      case CargoChoice.battery:
        return Icons.battery_charging_full_rounded;
      case CargoChoice.panel:
        return Icons.solar_power_rounded;
      case CargoChoice.oxygen:
        return Icons.air_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: GlassPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('CARGO LANDER: CHOOSE ONE CRATE', style: T.h2),
              const SizedBox(height: 4),
              const Text('There is room for only one. What does the base need most right now?', style: T.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final o in options)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: GestureDetector(
                          onTap: () => onChoose(o),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                            decoration: BoxDecoration(
                              color: C.cyan.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: C.line),
                            ),
                            child: Column(children: [
                              Icon(_icon(o), color: C.cyan, size: 30),
                              const SizedBox(height: 8),
                              Text(cargoName(o), style: T.h3.copyWith(fontSize: 12.5), textAlign: TextAlign.center),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps the HUD and shakes it when [trigger] changes.
class Shaker extends StatefulWidget {
  final int trigger;
  final int strength;
  final Widget child;
  const Shaker({super.key, required this.trigger, required this.strength, required this.child});

  @override
  State<Shaker> createState() => _ShakerState();
}

class _ShakerState extends State<Shaker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void didUpdateWidget(covariant Shaker old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = _c.value;
        final amp = (1 - v) * 3.0 * widget.strength;
        final dx = v == 0 || v == 1 ? 0.0 : amp * (((v * 37).floor() % 2 == 0) ? 1 : -1);
        final dy = v == 0 || v == 1 ? 0.0 : amp * 0.6 * (((v * 29).floor() % 2 == 0) ? -1 : 1);
        return Transform.translate(offset: Offset(dx, dy), child: child);
      },
      child: widget.child,
    );
  }
}
