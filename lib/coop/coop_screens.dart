import 'package:flutter/material.dart';

import '../main.dart';
import '../services/audio.dart';
import '../story/story_model.dart' show AgeMode, AgeModeInfo;
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import '../world/characters.dart';
import 'coop_controller.dart';
import 'coop_engine.dart';
import 'coop_missions.dart';

/// Co-op home: pick a mission (for your age level), then host a room, join one
/// with a 4-digit code, or play on one phone by passing it around.
class CoopHome extends StatefulWidget {
  const CoopHome({super.key});

  @override
  State<CoopHome> createState() => _CoopHomeState();
}

class _CoopHomeState extends State<CoopHome> {
  CoopController? _game;
  late int _age = Services.of(context).progress.ageMode.index;
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _game?.dispose();
    _code.dispose();
    super.dispose();
  }

  void _attach(CoopController g) {
    final sv = Services.of(context);
    g.onResult = (r) {
      sv.session.recordCoop(r);
      sv.audio.play(Sfx.star);
    };
    setState(() => _game = g);
  }

  Future<void> _host(CoopMission m) async {
    final sv = Services.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final g = CoopController.online(cloud: sv.session.cloud, myName: _myName(sv));
    final ok = await g.host(m);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _attach(g);
    } else {
      setState(() => _error = g.error);
      g.dispose();
    }
  }

  Future<void> _join() async {
    final sv = Services.of(context);
    final c = _code.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (c.length != 4) {
      setState(() => _error = 'Room codes have 4 numbers.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final g = CoopController.online(cloud: sv.session.cloud, myName: _myName(sv));
    final ok = await g.join(c);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _attach(g);
    } else {
      setState(() => _error = g.error);
      g.dispose();
    }
  }

  void _local(CoopMission m) => _attach(CoopController.local(m, myName: _myName(Services.of(context))));

  String _myName(Services sv) => sv.session.signedIn ? sv.session.name : 'Player';

  void _leave() {
    _game?.dispose();
    setState(() => _game = null);
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    if (g != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: AnimatedBuilder(animation: g, builder: (context, _) => _CoopGame(g: g, onLeave: _leave)),
      );
    }
    final sv = Services.of(context);
    final online = sv.session.cloud.ready;
    final list = coopMissions.where((m) => m.age == _age).toList();
    final bottom = MediaQuery.of(context).padding.bottom;
    return AuroraBackground(
      intensity: 0.7,
      child: SafeArea(
        bottom: false,
        child: ListView(padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom), children: [
          Row(children: [
            IconButton(onPressed: () => sv.nav.back(), icon: const Icon(Icons.arrow_back_rounded, color: C.frozen)),
          ]),
          Text('Co-op missions', style: T.hero.copyWith(fontSize: 34)),
          const SizedBox(height: 6),
          Text('2 to 4 players. Each role sees different information, so you win by talking: Astronaut, CAPCOM, Flight Engineer and Flight Surgeon.', style: T.body.copyWith(color: C.muted)),
          const SizedBox(height: 16),
          // join a room
          GlassPanel(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  enabled: online && !_busy,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  style: T.mono.copyWith(fontSize: 22, letterSpacing: 6),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: online ? 'Room code' : 'Online needs the cloud',
                    hintStyle: T.body.copyWith(color: C.dim, letterSpacing: 0),
                    border: InputBorder.none,
                  ),
                ),
              ),
              PrimaryButton(label: 'Join', icon: Icons.login_rounded, height: 48, onTap: online && !_busy ? _join : null),
            ]),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: T.body.copyWith(color: C.violet))),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: [for (final m in AgeMode.values) ButtonSegment(value: m.index, label: Text(m.title))],
            selected: {_age},
            onSelectionChanged: (s) => setState(() => _age = s.first),
            style: ButtonStyle(foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.evergreen : C.frozen), backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.cyan : Colors.transparent)),
          ),
          const SizedBox(height: 12),
          for (final m in list) _missionCard(m, online),
        ]),
      ),
    );
  }

  Widget _missionCard(CoopMission m, bool online) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('MISSION ${m.n}', style: T.label.copyWith(fontSize: 11)),
            const Spacer(),
            Text('${m.minPlayers}–${m.maxPlayers} players', style: T.bodySmall),
          ]),
          const SizedBox(height: 4),
          Text(m.title, style: T.h2),
          const SizedBox(height: 6),
          Text(m.brief, style: T.body.copyWith(color: C.muted, fontSize: 13.5)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final r in m.roles)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _roleColor(r).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
                child: Text(r.title, style: T.label.copyWith(color: _roleColor(r), fontSize: 10, letterSpacing: 1)),
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: HudButton(label: 'ONE PHONE', icon: Icons.smartphone_rounded, onTap: _busy ? null : () => _local(m))),
            const SizedBox(width: 10),
            Expanded(child: PrimaryButton(label: _busy ? '…' : 'Host room', icon: Icons.wifi_tethering_rounded, height: 48, onTap: online && !_busy ? () => _host(m) : null)),
          ]),
        ]),
      );
}

Color _roleColor(CoopRole r) => const [C.cyan, C.frozen, C.violet, Color(0xFFFF9EAA)][r.index];

class _CoopGame extends StatelessWidget {
  final CoopController g;
  final VoidCallback onLeave;
  const _CoopGame({required this.g, required this.onLeave});

  @override
  Widget build(BuildContext context) {
    final s = g.state;
    final bottom = MediaQuery.of(context).padding.bottom;
    return AuroraBackground(
      intensity: 0.6,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 12 + bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconButton(onPressed: onLeave, icon: const Icon(Icons.close_rounded, color: C.frozen)),
              Expanded(child: Text(s.mission.title, style: T.h2, overflow: TextOverflow.ellipsis)),
              if (g.code != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: C.bg.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
                  child: Text('ROOM ${g.code}', style: T.mono.copyWith(fontSize: 14, color: C.cyan)),
                ),
            ]),
            if (g.hostGone)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('The host left the room. Start a new one.', style: T.body.copyWith(color: C.violet))),
            Expanded(
              child: switch (s.phase) {
                CoopPhase.lobby => _lobby(context),
                CoopPhase.done => _result(context),
                _ => _play(context),
              },
            ),
          ]),
        ),
      ),
    );
  }

  Widget _lobby(BuildContext context) {
    final s = g.state;
    final players = g.online ? g.peers : [{'name': g.myName, 'id': g.selfId}];
    final shares = shareRoles(s.mission.roles, players.length);
    return ListView(children: [
      const SizedBox(height: 8),
      if (g.online && g.isHost && g.code != null) ...[
        Text('Tell your team the room code:', style: T.body.copyWith(color: C.muted), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(g.code!.split('').join(' '), style: T.hero.copyWith(fontSize: 56, color: C.cyan, fontFamily: F.mono), textAlign: TextAlign.center),
        const SizedBox(height: 16),
      ],
      if (!g.online)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text('One phone: pass it around. Each player looks only at their own role\'s screen, then tells the others what they see.', style: T.body.copyWith(color: C.muted)),
        ),
      Text(s.mission.brief, style: T.body),
      const SizedBox(height: 16),
      Text('CREW', style: T.label.copyWith(fontSize: 11)),
      const SizedBox(height: 6),
      for (var i = 0; i < players.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
          child: Row(children: [
            CircleAvatar(backgroundColor: C.cyan.withValues(alpha: 0.2), child: Text('${i + 1}', style: T.h3)),
            const SizedBox(width: 10),
            Expanded(child: Text('${players[i]['name'] ?? 'Player'}${players[i]['id'] == g.selfId ? ' (you)' : ''}', style: T.h3)),
            if (!g.online || i < shares.length) Text((g.online ? shares[i] : s.mission.roles).map((r) => r.title).join(' + '), style: T.bodySmall),
          ]),
        ),
      if (g.online && players.length < 2) const Text('Waiting for at least one more player…', style: T.bodySmall, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      if (g.isHost)
        PrimaryButton(label: 'Start mission', icon: Icons.play_arrow_rounded, onTap: g.online && players.length < 2 ? null : g.start)
      else
        Text('The host starts the mission.', style: T.body.copyWith(color: C.muted), textAlign: TextAlign.center),
    ]);
  }

  Widget _play(BuildContext context) {
    final s = g.state;
    final r = s.current;
    final mine = g.myRoles;
    final myInfo = [for (final role in s.mission.roles) if (mine.contains(role) && r.info[role] != null) (role, r.info[role]!)];
    final myActions = [for (final a in r.actions) if (mine.contains(a.owner)) a];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('ROUND ${s.round + 1}/${s.mission.rounds.length}', style: T.label.copyWith(fontSize: 11)),
        const SizedBox(width: 10),
        if (r.seconds > 0 && s.phase == CoopPhase.playing) Text('${s.roundLeft.ceil()} s', style: T.mono.copyWith(color: s.roundLeft < 10 ? C.red : C.frozen)),
        const Spacer(),
        Text('Mistakes ${s.mistakes}', style: T.bodySmall),
      ]),
      const SizedBox(height: 6),
      if (!g.online)
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final role in s.mission.roles)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(role.title),
                  selected: g.viewing == role,
                  onSelected: (_) => g.view(role),
                  selectedColor: _roleColor(role),
                  labelStyle: T.h3.copyWith(fontSize: 12, color: g.viewing == role ? C.evergreen : C.frozen),
                  backgroundColor: C.panelDeep,
                ),
              ),
          ]),
        ),
      const SizedBox(height: 6),
      Text(r.prompt, style: T.h2.copyWith(fontSize: 19)),
      const SizedBox(height: 8),
      Expanded(
        child: ListView(children: [
          for (final (role, text) in myInfo)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _roleColor(role).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: _roleColor(role).withValues(alpha: 0.6))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ONLY YOU SEE THIS · ${role.title.toUpperCase()}', style: T.label.copyWith(color: _roleColor(role), fontSize: 9.5)),
                const SizedBox(height: 4),
                Text(text, style: T.body.copyWith(fontSize: 14.5)),
              ]),
            ),
          if (s.phase == CoopPhase.roundDone)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.cyan.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                const PipFigure(size: 36, eye: PipEye.happy),
                const SizedBox(width: 10),
                Expanded(child: Text(r.success, style: T.h3)),
              ]),
            )
          else ...[
            if (myActions.isEmpty) Text('No buttons for you this round: tell your team what your screen says!', style: T.body.copyWith(color: C.muted)),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in myActions)
                _ActionButton(
                  label: a.label,
                  color: _roleColor(a.owner),
                  done: s.done.contains(a.id),
                  onTap: () {
                    Services.of(context).audio.tap();
                    g.press(a.id);
                  },
                ),
            ]),
          ],
          const SizedBox(height: 12),
          for (final e in s.log.reversed.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('${e.good ? '✓' : '✗'} ${e.text}', style: T.bodySmall.copyWith(color: e.good ? C.cyan : C.violet)),
            ),
          for (final c in g.calls.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('🎙 ${c.from}: ${c.text}', style: T.bodySmall.copyWith(color: C.frozen)),
            ),
        ]),
      ),
      if (s.phase == CoopPhase.roundDone)
        PrimaryButton(label: s.round >= s.mission.rounds.length - 1 ? 'Finish mission' : 'Next round', icon: Icons.arrow_forward_rounded, onTap: g.nextRound)
      else if (g.online)
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final q in quickCalls)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(label: Text(q), onPressed: () => g.call(q), backgroundColor: C.panelDeep, labelStyle: T.body.copyWith(fontSize: 12.5)),
              ),
          ]),
        ),
    ]);
  }

  Widget _result(BuildContext context) {
    final s = g.state;
    return ListView(children: [
      const SizedBox(height: 20),
      const Center(child: PipFigure(size: 90, eye: PipEye.happy)),
      const SizedBox(height: 12),
      Text('Mission complete', style: T.hero.copyWith(fontSize: 34), textAlign: TextAlign.center),
      const SizedBox(height: 10),
      Center(child: StarRow(stars: s.stars, size: 34)),
      const SizedBox(height: 8),
      Text('${s.mistakes} mistakes · ${s.elapsed ~/ 60} min ${(s.elapsed % 60).round()} s', style: T.body.copyWith(color: C.muted), textAlign: TextAlign.center),
      const SizedBox(height: 18),
      GlassPanel(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TEAM LESSON', style: T.label.copyWith(fontSize: 11)),
          const SizedBox(height: 6),
          Text(s.mission.lesson, style: T.h3.copyWith(fontSize: 17, height: 1.35)),
          const SizedBox(height: 10),
          Text('NASA DOES', style: T.label.copyWith(fontSize: 11, color: C.frozen)),
          const SizedBox(height: 4),
          Text(s.mission.nasaDoes, style: T.body),
        ]),
      ),
      const SizedBox(height: 18),
      PrimaryButton(label: 'Back to missions', icon: Icons.groups_rounded, onTap: onLeave),
    ]);
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool done;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.color, required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: done ? null : onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: done ? color.withValues(alpha: 0.25) : C.panelSolid,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: done ? 0.3 : 0.85), width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (done) ...[Icon(Icons.check_rounded, size: 18, color: color), const SizedBox(width: 6)],
            Text(label, style: T.h3.copyWith(fontSize: 14.5, color: done ? C.muted : C.text)),
          ]),
        ),
      );
}
