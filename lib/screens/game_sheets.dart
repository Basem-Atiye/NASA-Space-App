import 'package:flutter/material.dart';

import '../data/messages.dart';
import '../engine/constants.dart';
import '../engine/mission.dart';
import '../engine/simulation.dart';
import '../game/game_controller.dart';
import '../ui/theme.dart';
import '../ui/widgets/avatar.dart';
import '../ui/widgets/common.dart';

/// Opens a HUD sheet. The game pauses while it is open.
Future<void> openSheet(BuildContext context, GameController g, Widget Function(BuildContext) builder) async {
  g.setSheetOpen(true);
  g.audio.tap();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierColor: const Color(0x66000000),
    builder: (ctx) {
      final h = MediaQuery.of(ctx).size.height;
      return SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 760, maxHeight: h * 0.86),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: AnimatedBuilder(animation: g, builder: (c, _) => builder(c)),
            ),
          ),
        ),
      );
    },
  );
  g.setSheetOpen(false);
}

class _SheetFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  const _SheetFrame({required this.title, required this.icon, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: C.cyan, size: 20),
            const SizedBox(width: 8),
            Text(title, style: T.h2),
            const SizedBox(width: 10),
            if (subtitle != null) Expanded(child: Text(subtitle!, style: T.bodySmall, overflow: TextOverflow.ellipsis)) else const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: C.amber.withValues(alpha: 0.6))),
              child: Text('PAUSED', style: T.label.copyWith(color: C.amber, fontSize: 9)),
            ),
            const SizedBox(width: 8),
            GestureDetector(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.close_rounded, color: C.muted)),
          ]),
          const HudDivider(),
          Flexible(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- POWER

class PowerSheet extends StatelessWidget {
  final GameController g;
  const PowerSheet({super.key, required this.g});

  @override
  Widget build(BuildContext context) {
    final s = g.sim;
    final gen = s.generationKw, load = s.loadKw;
    final net = gen - load;
    final o2PerDay = Rates.electrolyzerMaxO2PerHour * s.electrolyzerRate * 24;
    final o2Need = Rates.o2PerDay * s.crew;
    return _SheetFrame(
      title: 'POWER',
      icon: Icons.bolt_rounded,
      subtitle: s.sun ? 'Solar panels at ${((1 - s.dust) * 100).round()}% (dust ${(s.dust * 100).round()}%)' : 'Night: no solar power, battery only',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PowerBar(gen: gen, load: load),
          const SizedBox(height: 6),
          Row(children: [
            Text('Battery ${s.battery.toStringAsFixed(1)} / ${s.batteryCap.toStringAsFixed(0)} kWh', style: T.mono.copyWith(fontSize: 12)),
            const Spacer(),
            Text(
              net >= 0 ? 'Charging +${net.toStringAsFixed(2)} kW' : 'Draining ${net.toStringAsFixed(2)} kW · empty in ${formatHours(s.batteryHoursLeft)}',
              style: T.mono.copyWith(fontSize: 12, color: net >= 0 ? C.green : C.amber),
            ),
          ]),
          const HudDivider(),
          _SystemRow(
            icon: Icons.air_rounded,
            name: 'Oxygen generator',
            detail: 'Makes ${o2PerDay.toStringAsFixed(2)} kg O₂/day (crew needs ${o2Need.toStringAsFixed(2)}). Uses ${(o2PerDay * Rates.electrolyzerWaterPerKgO2).toStringAsFixed(2)} kg water/day.',
            kw: Rates.electrolyzerKw * s.electrolyzerRate,
            on: s.electrolyzerOn,
            broken: s.isBroken(SystemId.electrolyzer),
            onChanged: g.setElectrolyzer,
            extra: Row(children: [
              Text('RATE', style: T.label.copyWith(fontSize: 9)),
              Expanded(
                child: Slider(
                  value: s.electrolyzerRate,
                  divisions: 20,
                  onChanged: s.isBroken(SystemId.electrolyzer) ? null : g.setElectrolyzerRate,
                ),
              ),
              SizedBox(width: 44, child: Text('${(s.electrolyzerRate * 100).round()}%', style: T.mono.copyWith(fontSize: 12))),
            ]),
          ),
          _SystemRow(
            icon: Icons.recycling_rounded,
            name: 'Water recycler',
            detail: 'Recovers ${(Rates.recyclerEfficiency * 100).round()}% of the water the crew uses.',
            kw: Rates.recyclerKw,
            on: s.recyclerOn,
            broken: s.isBroken(SystemId.recycler),
            onChanged: g.setRecycler,
          ),
          if (s.mission.hasGreenhouse)
            _SystemRow(
              icon: Icons.eco_rounded,
              name: 'Greenhouse lights',
              detail: 'Grows ${Rates.greenhouseHarvestKg} kg of food per harvest. Next harvest: ${(s.growth * 100).round()}% grown.',
              kw: Rates.greenhouseKw,
              on: s.greenhouseOn,
              broken: s.isBroken(SystemId.greenhouse),
              onChanged: g.setGreenhouse,
            ),
          _SystemRow(
            icon: Icons.local_fire_department_rounded,
            name: 'Heaters',
            detail: s.sun ? 'Only use power at night. Without them, the crew freezes in the dark.' : 'Running now. Turning them off at night hurts the crew fast.',
            kw: s.sun ? 0 : Rates.heaterKw,
            on: s.heatersOn,
            broken: false,
            onChanged: g.setHeaters,
          ),
          _SystemRow(
            icon: Icons.science_rounded,
            name: 'Science lab',
            detail: 'Needed for SCIENCE tasks. Science raises morale. Total so far: ${s.science.toStringAsFixed(0)} points.',
            kw: Rates.labKw,
            on: s.labOn,
            broken: false,
            onChanged: g.setLab,
          ),
          const SizedBox(height: 4),
          const Text('Life support base load: ${Rates.baseKw} kW (always on). When the battery empties, systems shut down in this order: lab, greenhouse, oxygen generator, recycler, heaters.',
              style: T.bodySmall),
        ],
      ),
    );
  }
}

class _PowerBar extends StatelessWidget {
  final double gen, load;
  const _PowerBar({required this.gen, required this.load});

  @override
  Widget build(BuildContext context) {
    final maxV = [gen, load, 1.0].reduce((a, b) => a > b ? a : b) * 1.15;
    Widget bar(String label, double v, Color c) => Row(children: [
          SizedBox(width: 92, child: Text(label, style: T.label.copyWith(fontSize: 9.5))),
          Expanded(
            child: Stack(children: [
              Container(height: 12, decoration: BoxDecoration(color: C.lineSoft, borderRadius: BorderRadius.circular(3))),
              FractionallySizedBox(
                widthFactor: (v / maxV).clamp(0.0, 1.0).toDouble(),
                child: Container(height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
              ),
            ]),
          ),
          SizedBox(width: 64, child: Text('${v.toStringAsFixed(2)} kW', style: T.mono.copyWith(fontSize: 11.5), textAlign: TextAlign.right)),
        ]);
    return Column(children: [
      bar('SOLAR IN', gen, C.amber),
      const SizedBox(height: 6),
      bar('SYSTEMS USE', load, load > gen ? C.red : C.cyan),
    ]);
  }
}

class _SystemRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final String detail;
  final double kw;
  final bool on;
  final bool broken;
  final ValueChanged<bool> onChanged;
  final Widget? extra;

  const _SystemRow({
    required this.icon,
    required this.name,
    required this.detail,
    required this.kw,
    required this.on,
    required this.broken,
    required this.onChanged,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final c = broken ? C.red : (on ? C.cyan : C.dim);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: c, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(name, style: T.h3),
                const SizedBox(width: 8),
                if (broken)
                  Text('BROKEN · set Nova\'s task to REPAIR', style: T.label.copyWith(color: C.red, fontSize: 9.5))
                else
                  Text('${kw.toStringAsFixed(2)} kW', style: T.monoSmall.copyWith(color: on ? C.cyan : C.dim)),
              ]),
              const SizedBox(height: 2),
              Text(detail, style: T.bodySmall),
            ]),
          ),
          Switch(value: on && !broken, onChanged: broken ? null : onChanged),
        ]),
        if (extra != null && !broken) Padding(padding: const EdgeInsets.only(left: 32), child: extra),
      ]),
    );
  }
}

// ---------------------------------------------------------------- TASK

class TaskSheet extends StatelessWidget {
  final GameController g;
  const TaskSheet({super.key, required this.g});

  @override
  Widget build(BuildContext context) {
    final s = g.sim;
    final tasks = <(Activity, IconData, String, String?)>[
      (Activity.rest, Icons.bed_rounded, 'Lowers fatigue fast. Uses a little less oxygen.', null),
      (Activity.repair, Icons.handyman_rounded, s.broken.isEmpty ? 'Nothing is broken right now.' : 'Fix ${systemName(s.broken.first)} in about 3 hours.',
          s.broken.isEmpty ? 'Nothing to fix' : null),
      (Activity.greenhouse, Icons.eco_rounded, 'Tend the plants: food grows twice as fast.', s.mission.hasGreenhouse ? null : 'No greenhouse in this mission'),
      (Activity.exercise, Icons.fitness_center_rounded, 'Keeps bones and muscles strong (+health). Uses more oxygen.', null),
      (Activity.science, Icons.science_rounded, 'Experiments in the lab (+morale). Turns the lab on.', null),
      (Activity.clean, Icons.cleaning_services_rounded, 'Brush dust off the panels outside. Outside means more radiation.', null),
      (Activity.shelter, Icons.shield_rounded, 'The best radiation protection. Cramped: morale drops.', null),
    ];
    return _SheetFrame(
      title: "NOVA'S TASK",
      icon: Icons.person_rounded,
      subtitle: s.onEva ? 'Nova is on an EVA. Recall her first to change tasks.' : 'Now: ${activityName(s.activity)}',
      child: LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth > 560 ? 3 : 2;
        final w = (box.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in tasks)
            SizedBox(
              width: w,
              child: _TaskCard(
                icon: t.$2,
                name: activityName(t.$1),
                detail: t.$3,
                disabledReason: s.onEva ? 'On EVA' : t.$4,
                selected: !s.onEva && s.activity == t.$1,
                warn: t.$1 == Activity.shelter && s.storm != null,
                onTap: () => g.setActivity(t.$1),
              ),
            ),
        ]);
      }),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String detail;
  final String? disabledReason;
  final bool selected;
  final bool warn;
  final VoidCallback onTap;

  const _TaskCard({
    required this.icon,
    required this.name,
    required this.detail,
    required this.disabledReason,
    required this.selected,
    required this.warn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = disabledReason == null;
    final c = !enabled ? C.dim : (warn ? C.amber : C.cyan);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.18) : C.bg.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? c : (warn && enabled ? C.amber.withValues(alpha: 0.7) : C.lineSoft), width: selected ? 1.6 : 1),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: c, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(name, style: T.h3.copyWith(color: enabled ? C.text : C.dim)),
                if (selected) ...[const SizedBox(width: 6), const Icon(Icons.check_circle_rounded, size: 14, color: C.cyan)],
                if (warn && enabled && !selected) ...[const SizedBox(width: 6), Text('STORM!', style: T.label.copyWith(color: C.amber, fontSize: 9))],
              ]),
              const SizedBox(height: 2),
              Text(enabled ? detail : disabledReason!, style: T.bodySmall.copyWith(fontSize: 11.5)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- EVA

class EvaSheet extends StatefulWidget {
  final GameController g;
  const EvaSheet({super.key, required this.g});

  @override
  State<EvaSheet> createState() => _EvaSheetState();
}

class _EvaSheetState extends State<EvaSheet> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final s = g.sim;
    if (!s.mission.evaUnlocked) {
      return const _SheetFrame(
        title: 'EVA',
        icon: Icons.directions_walk_rounded,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Moonwalks unlock in Chapter 3. For now, Nova stays safely inside the habitat.', style: T.body),
        ),
      );
    }
    if (s.onEva) {
      final total = evaHours(s.eva!);
      return _SheetFrame(
        title: 'EVA IN PROGRESS',
        icon: Icons.directions_walk_rounded,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(evaName(s.eva!), style: T.h3),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: (total - s.evaLeft) / total, minHeight: 8, backgroundColor: C.lineSoft, color: C.cyan),
          ),
          const SizedBox(height: 6),
          Text('${s.evaLeft} hours left · dose rate now ${(s.doseRatePerHour * 24).toStringAsFixed(2)} mSv/day', style: T.mono.copyWith(fontSize: 12)),
          const SizedBox(height: 12),
          if (s.storm != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('A solar storm is coming. Recall Nova now and send her to the shelter.', style: T.body.copyWith(color: C.amber)),
            ),
          HudButton(
            label: 'RECALL NOVA',
            icon: Icons.u_turn_left_rounded,
            color: C.amber,
            filled: true,
            onTap: () {
              g.recallEva();
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 4),
          const Text('Recalling ends the EVA early without its reward.', style: T.bodySmall),
        ]),
      );
    }
    final targets = <(EvaTarget, IconData, String)>[
      (EvaTarget.ice, Icons.ac_unit_rounded, '+${Rates.iceKgPerEva.toStringAsFixed(0)} kg water from ancient ice'),
      (EvaTarget.science, Icons.landscape_rounded, '+${Rates.samplesPerEva} rock samples, +morale'),
      (EvaTarget.ridge, Icons.solar_power_rounded, '+${Rates.ridgePanelKw} kW solar power (needs a spare panel: ${s.sparePanels})'),
      (EvaTarget.berm, Icons.foundation_rounded, 'Halves the radiation dose inside the habitat'),
    ];
    return _SheetFrame(
      title: 'PLAN AN EVA',
      icon: Icons.directions_walk_rounded,
      subtitle: 'Outside: oxygen use x1.6, fatigue +4/h, full surface radiation',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (s.storm != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Solar storm warning: going outside now is dangerous.', style: T.body.copyWith(color: C.amber)),
          ),
        for (final t in targets) _evaRow(g, t.$1, t.$2, t.$3),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: T.body.copyWith(color: C.red))),
      ]),
    );
  }

  Widget _evaRow(GameController g, EvaTarget t, IconData icon, String reward) {
    final s = g.sim;
    final h = evaHours(t);
    final dose = h * Rates.surfaceDosePerHour;
    final o2 = Rates.o2PerDay / 24 * s.crew * 1.6 * h;
    final reason = s.canStartEva(t);
    final done = (t == EvaTarget.berm && s.berm);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, color: reason == null ? C.cyan : C.dim, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(evaName(t), style: T.h3),
            Text(reward, style: T.bodySmall.copyWith(color: C.green)),
            Text('$h h · O₂ ${o2.toStringAsFixed(2)} kg · dose ~${dose.toStringAsFixed(2)} mSv (no storm)', style: T.monoSmall.copyWith(fontSize: 10.5)),
          ]),
        ),
        const SizedBox(width: 8),
        HudButton(
          label: done ? 'DONE' : 'GO',
          compact: true,
          filled: reason == null,
          onTap: done
              ? null
              : () {
                  final r = g.startEva(t);
                  if (r == null) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _error = r);
                  }
                },
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- MISSION

class MissionSheet extends StatelessWidget {
  final GameController g;
  final VoidCallback onData;
  const MissionSheet({super.key, required this.g, required this.onData});

  @override
  Widget build(BuildContext context) {
    final s = g.sim;
    final m = s.mission;
    Widget star(StarRule r, int n) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            StarRow(stars: n, size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text(r.label, style: T.bodySmall.copyWith(color: s.meetsStar(r) ? C.green : C.muted))),
          ]),
        );
    return _SheetFrame(
      title: 'MISSION ${m.id}: ${m.title.toUpperCase()}',
      icon: Icons.flag_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.goalText, style: T.body),
        const SizedBox(height: 6),
        Text(m.newThisMission, style: T.bodySmall),
        const HudDivider(),
        const SectionLabel('Stars'),
        const SizedBox(height: 4),
        const Row(children: [StarRow(stars: 1, size: 14), SizedBox(width: 8), Text('Complete the mission', style: T.bodySmall)]),
        star(m.star2, 2),
        star(m.star3, 3),
        const HudDivider(),
        Wrap(spacing: 18, runSpacing: 6, children: [
          _kv('CREW', '${m.crew}'),
          _kv('DURATION', '${m.days} days'),
          _kv('DOSE LIMIT', '${m.doseLimit.toStringAsFixed(0)} mSv'),
          _kv('SAMPLES', '${s.samples}'),
          _kv('ICE MINED', '${s.iceMined.toStringAsFixed(0)} kg'),
          _kv('SCIENCE', s.science.toStringAsFixed(0)),
        ]),
        const SizedBox(height: 12),
        HudButton(label: 'WHERE DO THESE NUMBERS COME FROM?', icon: Icons.menu_book_rounded, compact: true, onTap: onData),
      ]),
    );
  }

  Widget _kv(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(k, style: T.label.copyWith(fontSize: 9)),
        Text(v, style: T.mono),
      ]);
}

// ---------------------------------------------------------------- LOG

class LogSheet extends StatelessWidget {
  final GameController g;
  const LogSheet({super.key, required this.g});

  @override
  Widget build(BuildContext context) {
    final items = g.feed.reversed.toList();
    return _SheetFrame(
      title: 'COMMS LOG',
      icon: Icons.forum_rounded,
      child: Column(children: [
        for (final f in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SpeakerAvatar(speaker: f.message.speaker, mood: f.message.mood, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(speakerName(f.message.speaker).toUpperCase(), style: T.label.copyWith(fontSize: 9.5, color: speakerColor(f.message.speaker))),
                    const Spacer(),
                    Text(missionClock(f.hour), style: T.monoSmall.copyWith(fontSize: 9.5)),
                  ]),
                  const SizedBox(height: 2),
                  Text(f.message.text, style: T.body.copyWith(fontSize: 13)),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- GAUGE INFO

class GaugeInfoSheet extends StatelessWidget {
  final GameController g;
  final String id;
  const GaugeInfoSheet({super.key, required this.g, required this.id});

  @override
  Widget build(BuildContext context) {
    final s = g.sim;
    String title;
    String body;
    switch (id) {
      case 'o2':
        title = 'OXYGEN';
        body = 'Each crew member breathes about ${Rates.o2PerDay} kg of oxygen a day (NASA). The oxygen generator makes more by splitting water with electricity. '
            'Net change now: ${(s.o2NetPerHour * 24).toStringAsFixed(2)} kg/day. Time left: ${formatHours(s.o2HoursLeft)}.';
        break;
      case 'water':
        title = 'WATER';
        body = 'Each crew member needs about ${Rates.drinkWaterPerDay} kg a day for drinking and food (NASA), plus some for washing. '
            'The recycler saves most of it. Making oxygen also uses water. Net change now: ${(s.waterNetPerHour * 24).toStringAsFixed(2)} kg/day.';
        break;
      case 'food':
        title = 'FOOD';
        body = 'Each crew member eats about ${Rates.foodPerDay} kg of dry food a day (NASA). A greenhouse can grow more, but needs power and water.';
        break;
      case 'power':
        title = 'BATTERY';
        body = 'Solar panels charge the battery in sunlight. At night or when panels are dusty, the battery must cover everything. '
            'Solar ${s.generationKw.toStringAsFixed(2)} kW in, systems ${s.loadKw.toStringAsFixed(2)} kW out.';
        break;
      case 'dose':
        title = 'RADIATION DOSE';
        body = 'The open lunar surface gets about ${Rates.surfaceDosePerDay} mSv a day from cosmic rays (Chang\'e 4 measurement). '
            'The habitat blocks part of it, regolith shielding more, the storm shelter most. Solar storms add much more. '
            'Dose rate now: ${(s.doseRatePerHour * 24).toStringAsFixed(2)} mSv/day. Mission limit: ${s.mission.doseLimit.toStringAsFixed(0)} mSv.';
        break;
      case 'health':
        title = 'HEALTH';
        body = 'Health drops without oxygen, water or food, in the cold, from radiation and from exhaustion. Exercise and good care bring it back slowly.';
        break;
      default:
        title = 'MORALE';
        body = 'Isolation is hard. Rest, science, harvests, successful EVAs and messages from home lift morale. Very low morale slows repairs.';
    }
    return _SheetFrame(title: title, icon: Icons.info_outline_rounded, child: Text(body, style: T.body));
  }
}
