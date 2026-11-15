/// Short, emoji-friendly Base Commander copy for Little Explorer (ages 6–10).
library;

import '../story/story_model.dart';
import 'base_engine.dart';

bool useKidBaseCopy(AgeMode mode) => mode == AgeMode.cadet;

String kidGoal(BaseMission m) => switch (m.n) {
      1 => '🌬️ Keep 4 friends breathing for 12 days!',
      2 => '💧 Keep everyone alive for 30 days!',
      3 => '🥗 Grow food for 30 days!',
      4 => '🛡️ Survive 2 storms + a long night!',
      5 => '🔧 Get 3 parts. Fly home on Day 30!',
      6 => '🔴 Stay alive 20 Mars days!',
      7 => '🌪️ Survive a giant dust storm!',
      8 => '🧊 Keep water flowing 25 days!',
      9 => '❄️ Get through the long winter!',
      10 => '🚀 Run the Mars base + get 3 parts!',
      _ => m.goal,
    };

String kidNewTitle(BaseMission m) => switch (m.n) {
      1 => 'NEW: POWER + AIR ⚡🌬️',
      2 => 'NEW: WATER 💧',
      3 => 'NEW: FOOD 🥗',
      4 => 'NEW: RADIATION ☀️🛡️',
      5 => 'NEW: REPAIR PARTS 🔧',
      6 => 'NEW: MARS SUN 🔴',
      7 => 'NEW: DUST STORMS 🌪️',
      8 => 'NEW: MARS ICE 🧊',
      9 => 'NEW: WINTER ❄️',
      10 => 'NEW: PIONEER 🌟',
      _ => m.newTitle,
    };

String kidNewText(BaseMission m) => switch (m.n) {
      1 => 'Crew needs air! 🌬️ Life Support makes it — but needs power from the Sun. ☀️',
      2 => 'Crew drinks every day! 💧 The recycler cleans water — if it has power. ⚡',
      3 => 'Earth food runs out! 📦 Plants need light, water and power. 🌱',
      4 => 'Sun storms can hurt! ☀️ Shield keeps friends safe — if it has power. 🛡️',
      5 => 'Need 3 parts to fly home! 🚀 Find, print, or unload them. Stay safe!',
      6 => 'Mars is farther. 🔴 Panels get less sunshine. Save power!',
      7 => 'Dust can hide the Sun! 🌪️ Charge batteries before the storm.',
      8 => 'Ice under the ground! 🧊 Find it so you need less Earth water.',
      9 => 'Winter = low Sun + long nights. ❄️ Keep spare power!',
      10 => 'Everything you learned — on the hardest world! 🌟',
      _ => m.newText,
    };

String kidLesson(String lesson, {required int mission}) => switch (mission) {
      1 => '🌬️ Air first! Life Support needs clean panels. ☀️',
      2 => '💧 A healthy recycler beats a full tank!',
      3 => '🌱 Plant early. Food needs water + power.',
      4 => '🛡️ Get ready before storms and nights!',
      5 => '🚀 Home needs air, water, food, power, shield + parts!',
      6 => '⚡ On Mars, every watt counts!',
      7 => '🔋 Batteries bridge dusty days!',
      8 => '🧊 Using local ice saves rockets!',
      9 => '❄️ Plan for the hardest days first!',
      10 => '🌟 Plan ahead. Fix early. Keep friends safe!',
      _ => lesson,
    };

String kidEventTitle(String id, String fallback) => switch (id) {
      'dust' => '🧹 Dusty panels!',
      'leak' => '💨 Air leak!',
      'storm' => '☀️ Solar storm!',
      'clog' => '💧 Filter clogged!',
      'leaves' => '💛 Yellow leaves!',
      'quake' => '🫨 Moonquake!',
      'night' => '🌙 Night coming!',
      'rock' => '☄️ Space rock!',
      'sick' => '🤒 Crew feels sick',
      'parts' => '🚀 Old lander!',
      'printer' => '🖨️ Printer ready!',
      'ship' => '📦 Supply ship!',
      'duststorm' => '🌪️ Dust storm!',
      _ => fallback,
    };

String kidEventText(String id, String fallback) => switch (id) {
      'dust' => 'Moon dust covers panels. Less power! ⚡',
      'leak' => 'Habitat seal leaking. Air drops each day! 💨',
      'storm' => 'Storm in 2 days! How do we stay safe? 🛡️',
      'clog' => 'Water filter is dirty. Slow recycler! 💧',
      'leaves' => 'Lettuce looking sad and yellow. 🥬',
      'quake' => 'Ground shook! Check the pipes! 🫨',
      'night' => 'Sun hides 4 days. Panels make little power. 🌙',
      'rock' => 'Tiny rock hit a panel. One part broke! ☄️',
      'sick' => 'Scientist dizzy. Maybe stale air? 🤒',
      'parts' => 'Rover found an old lander. Spare parts? 🔧',
      'printer' => 'Lab can print a spare part! 🖨️',
      'ship' => 'Cargo ship landed! Carry boxes in. 📦',
      'duststorm' => 'Huge Mars dust storm! Sun may hide. 🌪️',
      _ => fallback,
    };
