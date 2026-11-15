import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/game_dictionary.dart';
import 'widgets/helper_face.dart';
import '../data/glossary.dart' as vocabulary;

final gameGlossary = <String, String>{
  ...commonGameDictionary,
  'electrolyser': 'An electrolyser is a machine that uses electricity to split water into oxygen and hydrogen. In your base, it helps make oxygen for the crew to breathe.',
  'electrolyzer': 'An electrolyzer is a machine that uses electricity to split water into oxygen and hydrogen. In your base, it helps make oxygen for the crew to breathe.',

  for (final tip in vocabulary.glossary) tip.word.toLowerCase(): tip.meaning,
  'oxygen':
      'Oxygen is the gas your crew needs to breathe. Keep the air system working and repair leaks.',
  'regolith':
      'Regolith is the loose dust and broken rock covering the Moon. It can help shield your base.',
  'radiation':
      'Radiation is energy that can harm astronauts. Use shielding and shelter during a solar storm.',
  'solar storm':
      'A solar storm is a burst of activity from the Sun. Protect your crew with shelter and shielding.',
  'solar panels':
      'Solar panels turn sunlight into electricity for your base. Keep them working to power your systems.',
  'habitat':
      'A habitat is the place where your astronauts live, with air, water, food and protection.',
  'airlock':
      'An airlock is a small chamber with two doors. It lets astronauts go outside without losing the base air.',
  'gravity':
      'Gravity pulls objects toward a planet or moon. The Moon has less gravity than Earth.',
  'orbit':
      'An orbit is the curved path an object follows around a planet or moon.',
  'resources':
      'Resources are supplies your base uses, such as oxygen, water, food and power. Check them before making decisions.',
  'shielding':
      'Shielding is protective material that reduces radiation reaching your crew.',
  'hydroponics':
      'Hydroponics means growing plants using nutrient-rich water instead of soil.',
  'nutrients':
      'Nutrients are substances that living things need to grow and stay healthy.',
  'evaporation':
      'Evaporation happens when liquid water changes into water vapor.',
  'condensation':
      'Condensation happens when water vapor cools and changes into liquid water.',
  'pressure':
      'Pressure is the force of gas pushing on surfaces. Your habitat needs safe air pressure.',
  'temperature':
      'Temperature tells you how hot or cold something is. Keep the crew and equipment in a safe range.',
  'co-op':
      'Co-op means playing together. Create a room, share its code with a friend, and coordinate your actions.',
  'mission':
      'A mission is a game challenge with an objective. Read the briefing, watch your supplies and work toward the objective.',
  'fuel':
      'Fuel is the supply used to power movement. Watch how much you have left during a Supply Run.',
  'research':
      'Research means learning through investigation. In the game, it tracks scientific progress.',
  'crew': 'Your crew is the team of astronauts you are keeping safe.',
  'astronaut': 'A person trained to travel and work in space.',
  'engineer': 'A person who designs, builds or repairs equipment and systems.',
  'commander': 'The person who leads a crew and helps make mission decisions.',
  'explorer': 'Someone who visits a place to discover and learn about it.',
  'survival': 'Staying alive by meeting needs such as air, water, food and shelter.',
  'objective': 'The goal you are trying to reach in a mission.',
  'briefing': 'Instructions that explain a mission before you begin.',
  'debrief': 'A review of what happened after a mission and what you learned.',
  'emergency': 'A dangerous situation that needs quick action.',
  'priority': 'Something that should be handled before less urgent tasks.',
  'urgent': 'Needing attention very soon to avoid a problem.',
  'critical': 'Very serious, or essential for something to work.',
  'stable': 'Staying steady without large or sudden changes.',
  'efficient': 'Getting useful results while wasting less energy, time or supplies.',
  'efficiency': 'How well a system uses its energy or supplies without wasting them.',
  'capacity': 'The largest amount a container or system can hold or handle.',
  'consumption': 'The amount of a resource that is used.',
  'production': 'Making something useful, such as oxygen or electricity.',
  'supply': 'An amount of something available to use, such as food or fuel.',
  'supplies': 'Things your crew needs, such as food, water and equipment.',
  'storage': 'Keeping supplies or energy until you need them.',
  'shortage': 'Not having enough of something you need.',
  'depleted': 'Used up or almost used up.',
  'restore': 'To bring something back to a working or healthy state.',
  'repair': 'To fix something that is broken or damaged.',
  'maintenance': 'Regular work that keeps equipment in good condition.',
  'damage': 'Harm that makes something work less well.',
  'failure': 'When something stops doing the job it should do.',
  'backup': 'An extra system or supply used when the main one fails.',
  'redundancy': 'Having extra equipment so one failure does not stop everything.',
  'leak': 'An unwanted opening that lets air or liquid escape.',
  'seal': 'A tight barrier that prevents air or liquid from escaping.',
  'valve': 'A part that opens or closes to control the flow of gas or liquid.',
  'filter': 'A part that removes unwanted material from air or water.',
  'contamination': 'Unwanted or harmful material getting into something.',
  'purification': 'Removing unwanted substances to make something cleaner.',
  'recycling': 'Collecting and processing something so it can be used again.',
  'life support': 'The systems that provide safe air, water and conditions for astronauts.',
  'scrubber': 'Equipment that removes an unwanted gas, such as carbon dioxide, from the air.',
  'atmosphere': 'The layer of gases surrounding a planet or moon.',
  'vacuum': 'A region with very little matter, including very little air.',
  'insulation': 'Material that slows the transfer of heat or prevents unwanted electrical flow.',
  'heat': 'Energy transferred because of a temperature difference.',
  'thermal': 'Related to heat or temperature.',
  'coolant': 'A fluid that carries heat away from equipment.',
  'radiator': 'Equipment that releases heat to help a system cool down.',
  'conduction': 'Heat moving through material or between objects that touch.',
  'convection': 'Heat carried by moving liquid or gas.',
  'energy': 'The ability to do work or cause change.',
  'power': 'How quickly energy is used or produced. Your base needs power to run equipment.',
  'electricity': 'Energy associated with electric charges that can run your equipment.',
  'generator': 'Equipment that converts another form of energy into electricity.',
  'overload': 'A demand greater than a system can safely handle.',
  'short circuit': 'An unintended electrical path that can allow too much current to flow.',
  'calibration': 'Checking and adjusting an instrument so its measurements are accurate.',
  'measurement': 'A number describing an amount, size or condition.',
  'estimate': 'A careful approximate answer when the exact value is not known.',
  'threshold': 'A limit at which an action or warning is triggered.',
  'simulation': 'A model that lets you explore how a real system might behave.',
  'evidence': 'Information or observations that help support an explanation.',
  'diagnosis': 'Finding what is wrong by examining symptoms and evidence.',
  'hypothesis': 'A possible explanation that you can test.',
  'experiment': 'A planned test used to learn something.',
  'variable': 'Something that can change or be changed in an experiment.',
  'data': 'Information collected through observations or measurements.',
  'analysis': 'Examining information to understand what it means.',
  'photosynthesis': 'How plants use light to make sugars from water and carbon dioxide, releasing oxygen.',
  'germination': 'When a seed begins to grow.',
  'greenhouse': 'A sheltered place with conditions that help plants grow.',
  'humidity': 'The amount of water vapor in the air.',
  'dehydration': 'When the body does not have enough water.',
  'morale': 'How confident and positive a team feels.',
  'fatigue': 'Strong tiredness that can make work and decisions harder.',
  'payload': 'The people, equipment or supplies a vehicle carries for its mission.',
  'docking': 'Joining two spacecraft together in a controlled way.',
  'launch': 'Sending a spacecraft upward to begin its flight.',
  'landing': 'Bringing a vehicle safely down onto a surface.',
  'navigation': 'Working out where you are and how to reach your destination.',
  'communication': 'Sending and receiving information.',
  'signal': 'A changing pattern used to carry information, such as a radio message.',
  'bandwidth': 'How much information a communication link can carry in a given time.',
  'latency': 'The delay before a message arrives or a system responds.',
  'autonomous': 'Able to carry out a task without constant human control.',
  'solar flare': 'A sudden release of energy from the Sun that produces intense radiation.',
  'coronal mass ejection': 'A large release of plasma and magnetic field from the Sun, also called a CME.',
  'plasma': 'Gas containing electrically charged particles.',
  'magnetic field': 'A region where magnetic forces act.',
  'dose': 'The amount received, such as a measure of radiation exposure.',
  'exposure': 'Being in contact with something, such as radiation, for a period of time.',
  'shelter': 'A protected place where the crew can stay safe.',
  'micrometeorite': 'A very small piece of space rock that has reached a surface.',
  'impact': 'A collision, such as a space rock hitting the ground.',
  'erosion': 'Material wearing away or being moved from a surface.',
  'extraction': 'Removing a useful substance from a material, such as water from ice-bearing soil.',
  'prototype': 'An early version built to try out a design.',
  'cooperation': 'Working together to reach a shared goal.',
  'coordination': 'Organizing actions so people or systems work well together.',
  'allocate': 'To give part of your available supplies or time to a task.',
  'conserve': 'To use a resource carefully so it lasts longer.',
  'compromise': 'A choice that gives up some benefits to gain others.',
  'consequence': 'A result of an action or decision.',
  'resilience': 'The ability to recover after a problem or disruption.',
  'sustainability': 'Using resources in a way that can continue without exhausting them.',
};
final _lookup = <String, String>{
  for (final entry in gameGlossary.entries) ...{
    '${entry.key}s': entry.value,
    if (entry.key.endsWith('y')) '${entry.key.substring(0, entry.key.length - 1)}ies': entry.value,
  },
  ...gameGlossary,
  'solar panel': gameGlossary['solar panels']!,
  'resource': gameGlossary['resources']!,
  'nutrient': gameGlossary['nutrients']!,
  'cme': gameGlossary['coronal mass ejection']!,
  'co2': gameGlossary['carbon dioxide']!,
  'o2': gameGlossary['oxygen']!,
};
/// Shared text API preserving the original screen typography and colors.
class GameText extends Text {
  const GameText(super.data,
      {super.key,
      super.style,
      super.strutStyle,
      super.textAlign,
      super.textDirection,
      super.locale,
      super.softWrap,
      super.overflow,
      super.textScaler,
      super.maxLines,
      super.semanticsLabel,
      super.textWidthBasis,
      super.textHeightBehavior,
      super.selectionColor});
}

class GameHelper extends StatefulWidget {
  final Widget child;
  final bool reducedMotion;
  const GameHelper(
      {super.key, required this.child, this.reducedMotion = false});
  @override
  State<GameHelper> createState() => _GameHelperState();
}

class _GameHelperState extends State<GameHelper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flight =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <String>[
    'Hi! I am your astronaut guide. Ask about this game, or type a game word to learn what it means.'
  ];
  bool _open = false;
  int _prompt = 0;
  late final Timer _timer = Timer.periodic(const Duration(seconds: 7), (_) {
    if (mounted && !_open) setState(() => _prompt = (_prompt + 1) % 3);
  });
  static const _prompts = [
    'How can I help you?',
    'Type a game word to learn its meaning.',
    'Need mission help? Tap me!'
  ];
  @override
  void initState() {
    super.initState();
    _timer;
  }

  void _ask([String? question]) {
    final q = (question ?? _input.text).trim();
    if (q.isEmpty) return;
    var target = q.toLowerCase().replaceAll(RegExp(r'[?!.]+$'), '').trim();
    target = target.replaceFirst(RegExp(r'^(?:what (?:does|is|are)|define|explain|meaning of|tell me about)\s+'), '');
    target = target.replaceFirst(RegExp(r'\s+mean$'), '').replaceFirst(RegExp(r'^(?:the word|the meaning of|a|an)\s+'), '').trim();
    target = target.replaceAll(RegExp("^[\"']|[\"']\$"), '');
    final matches = _lookup.containsKey(target) ? {target} : <String>{};
    String answer;
    if (matches.isNotEmpty) {
      answer = matches.map((w) => _lookup[w]!).join('\n\n');
    } else if (RegExp(r'\b(help|play|start|stuck|game)\b', caseSensitive: false)
        .hasMatch(q)) {
      answer =
          'Read your mission briefing first. Check air, water, food, power and crew health. Fix the most urgent problem, then work toward the mission objective. You can ask me about any game word.';
    } else {
      answer =
          'I only help with this game and its space words. Try asking about oxygen, radiation, resources, co-op or your mission. I do not have an answer for that question yet.';
    }
    setState(() {
      _messages.add('You: $q');
      _messages.add(answer);
    });
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients)
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _flight.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still =
        widget.reducedMotion || MediaQuery.of(context).disableAnimations;
    return Stack(fit: StackFit.expand, children: [
      widget.child,
      if (_open)
        Positioned.fill(
            child: Material(
                color: const Color(0x66040814),
                child: SafeArea(
                    child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16,
                      MediaQuery.of(context).viewInsets.bottom + 16),
                  child: Align(
                      alignment: Alignment.bottomRight,
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              minWidth: 320, maxWidth: 320, maxHeight: 390),
                          child: Material(
                              color: const Color(0xFF17263D),
                              borderRadius: BorderRadius.circular(24),
                              clipBehavior: Clip.antiAlias,
                              child: Column(children: [
                                ListTile(
                                    title: const Text('Astronaut guide'),
                                    subtitle:
                                        const Text('Game help • works offline'),
                                    trailing: IconButton(
                                        tooltip: 'Close game help',
                                        icon: const Icon(Icons.close),
                                        onPressed: () =>
                                            setState(() => _open = false))),
                                Expanded(
                                    child: ListView.builder(
                                  reverse: true,
                                        controller: _scroll,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18),
                                        itemCount: _messages.length,
                                        itemBuilder: (context, i) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 16),
                                            child: Text(_messages[_messages.length - 1 - i],
                                                style: TextStyle(
                                                    color: _messages[_messages.length - 1 - i]
                                                            .startsWith('You:')
                                                        ? const Color(
                                                            0xFF66BFFF)
                                                        : Colors.white,
                                                    height: 1.5))))),
                                Wrap(
                                    spacing: 6,
                                    children: ['Oxygen', 'Radiation', 'Co-op']
                                        .map((word) => ActionChip(
                                            label: Text(word),
                                            onPressed: () => _ask(word)))
                                        .toList()),
                                Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(children: [
                                      Expanded(
                                          child: TextField(
                                              controller: _input,
                                              maxLength: 240,
                                              textInputAction:
                                                  TextInputAction.send,
                                              onSubmitted: _ask,
                                              decoration: const InputDecoration(
                                                  hintText:
                                                      'Ask about the game…',
                                                  counterText: '',
                                                  border:
                                                      OutlineInputBorder()))),
                                      IconButton(
                                          tooltip: 'Send question',
                                          onPressed: _ask,
                                          icon: const Icon(Icons.send))
                                    ])),
                              ])))),
                )))),
      if (!_open)
        Positioned(
            right: 12,
            bottom: 78,
            child: SafeArea(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  IgnorePointer(
                      child: Container(
                          constraints: const BoxConstraints(maxWidth: 126),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 8),
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFF223A55),
                                Color(0xFF122239)
                              ]),
                              borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(15),
                                  topRight: Radius.circular(15),
                                  bottomLeft: Radius.circular(15),
                                  bottomRight: Radius.circular(4)),
                              border:
                                  Border.all(color: const Color(0x5566BFFF)),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x26000000),
                                    blurRadius: 14,
                                    offset: Offset(0, 4))
                              ]),
                          child: Text(_prompts[_prompt],
                              style: const TextStyle(
                                  color: Color(0xFFD8EEFF),
                                  fontSize: 10,
                                  height: 1.4)))),
                  AnimatedBuilder(
                      animation: _flight,
                      builder: (context, child) => Transform.translate(
                          offset: still
                              ? Offset.zero
                              : Offset(
                                  math.sin(_flight.value * math.pi * 2) * 3,
                                  math.cos(_flight.value * math.pi * 2) * 4),
                          child: child),
                      child: Semantics(
                          button: true,
                          label: 'Open astronaut game help',
                          child: GestureDetector(
                              key: const ValueKey('astronaut-help'),
                              onTap: () => setState(() => _open = true),
                              child: SizedBox(
                                  width: 48,
                                  height: 54,
                                  child: Center(
                                      child: const HelperFace(size: 48)))))),
                ]))),
    ]);
  }
}
