/// Small helpers that turn the engine's names into the design's icons,
/// colours and chips.
library;

import 'package:flutter/material.dart';

import '../../ui/figma_art.dart';
import '../../ui/kit.dart';
import '../../ui/line_icons.dart';
import '../../ui/theme.dart';
import '../base_engine.dart';

LineIconData iconNamed(String name) => switch (name) {
      'power' || 'zap' => Ln.zap,
      'water' || 'droplet' => Ln.droplet,
      'food' || 'sprout' => Ln.sprout,
      'oxygen' || 'wind' => Ln.wind,
      'crew' || 'heart' => Ln.heart,
      'research' || 'flask' => Ln.flask,
      'shield' => Ln.shield,
      'clock' => Ln.clock,
      'up' => Ln.up,
      'down' => Ln.down,
      'sun' => Ln.sun,
      'rocket' => Ln.rocket,
      'alert' || 'danger' => Ln.alert,
      'fix' || 'wrench' => Ln.wrench,
      'star' => Ln.star,
      'radiation' => Ln.radiation,
      'award' => Ln.award,
      'battery' => Ln.battery,
      'radio' => Ln.radio,
      _ => Ln.info,
    };

Color colorNamed(String name) => switch (name) {
      'orange' => C.orange,
      'red' => C.red,
      'yellow' => C.yellow,
      'blue' => C.water,
      'green' => C.green,
      'cyan' => C.cyan,
      'white' => C.frozen,
      _ => C.cyan,
    };

LineIconData sysIcon(Sys s) => switch (s) {
      Sys.lifeSupport => Ln.wind,
      Sys.greenhouse => Ln.sprout,
      Sys.recycler => Ln.droplet,
      Sys.research => Ln.flask,
      Sys.shield => Ln.shield,
    };

Color sysColor(Sys s) => switch (s) {
      Sys.lifeSupport => C.air,
      Sys.greenhouse => C.food,
      Sys.recycler => C.water,
      Sys.research => C.frozen,
      Sys.shield => C.shield,
    };

/// The module on the base picture for a system (and back).
BaseModule moduleFor(Sys s) => switch (s) {
      Sys.lifeSupport => BaseModule.habitat,
      Sys.greenhouse => BaseModule.greenhouse,
      Sys.recycler => BaseModule.recycler,
      Sys.research => BaseModule.lab,
      Sys.shield => BaseModule.habitat,
    };

Sys? sysForModule(BaseModule m) => switch (m) {
      BaseModule.habitat => Sys.lifeSupport,
      BaseModule.greenhouse => Sys.greenhouse,
      BaseModule.recycler => Sys.recycler,
      BaseModule.lab => Sys.research,
      BaseModule.shield => Sys.shield,
      BaseModule.power => null,
    };

/// A change chip ("↑ +18%", "−20 Power", "Crew safe").
Widget changeChip(Change c, {Color on = C.panel, double size = 14}) {
  final color = c.good ? C.green : C.red;
  final icon = switch (c.icon) {
    'up' => c.good ? Ln.up : Ln.down,
    'down' => Ln.down,
    'clock' => Ln.clock,
    'alert' => Ln.alert,
    '' => null,
    _ => iconNamed(c.icon),
  };
  // the design colours "no cost now" grey, research yellow, power red/green
  final col = c.icon == 'clock' ? C.muted : (c.icon == 'research' && !c.good ? C.yellow : color);
  return TagChip(c.label, color: col, icon: icon, on: on, size: size);
}

String pct(double v) => '${v.round()}%';

String two(int n) => n.toString().padLeft(2, '0');
