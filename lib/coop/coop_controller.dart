/// Runs a co-op game: on one phone (pass-and-play) or across phones over
/// Supabase Realtime. The host phone owns the [CoopState] and broadcasts it;
/// the others send button presses and quick calls.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../cloud/cloud.dart';
import '../cloud/link.dart';
import '../cloud/supabase_link.dart';
import '../story/level_record.dart' show newClientId;
import 'coop_engine.dart';
import 'coop_missions.dart';

enum CoopMode { local, online }

class CoopCall {
  final String from;
  final String text;
  final DateTime at;
  CoopCall(this.from, this.text) : at = DateTime.now();
}

class CoopController extends ChangeNotifier {
  final Cloud? cloud;
  final String myName;
  final CoopMode mode;
  final String selfId = newClientId().substring(0, 13);

  late CoopState state;
  Link? _link;
  StreamSubscription<LinkMessage>? _msgs;
  StreamSubscription<List<Map<String, dynamic>>>? _peerSub;
  Timer? _clock;
  double _sinceBroadcast = 0;

  bool isHost = false;
  String? roomId;
  String? code;
  String? error;
  bool connecting = false;
  bool hostGone = false;
  List<Map<String, dynamic>> peers = [];
  final List<CoopCall> calls = [];
  bool _recorded = false;
  final int _joinedAt = DateTime.now().millisecondsSinceEpoch;

  /// Pass-and-play: whose screen is showing on the shared phone.
  CoopRole viewing = CoopRole.astronaut;

  /// Called once when the host finishes a mission (to save the result).
  void Function(Map<String, dynamic> result)? onResult;

  CoopController.local(CoopMission m, {required this.myName})
      : cloud = null,
        mode = CoopMode.local {
    state = CoopState(m);
    isHost = true;
    state.seat([selfId], {selfId: myName});
  }

  CoopController.online({required Cloud this.cloud, required this.myName}) : mode = CoopMode.online {
    state = CoopState(coopMissions.first);
  }

  bool get online => mode == CoopMode.online;
  Set<CoopRole> get myRoles => online ? state.rolesOf(selfId) : {viewing};
  bool get inLobby => state.phase == CoopPhase.lobby;
  int get playerCount => online ? peers.length : 1;

  // ---------------------------------------------------------------- hosting

  Future<bool> host(CoopMission m) async {
    final c = cloud;
    if (c == null || !c.ready) {
      error = 'Online co-op needs the cloud connection. Try one-phone mode.';
      notifyListeners();
      return false;
    }
    state = CoopState(m);
    isHost = true;
    connecting = true;
    error = null;
    notifyListeners();
    try {
      final room = await c.createCoopRoom(m.id);
      roomId = room.roomId;
      code = room.code;
      return await _connect();
    } catch (e) {
      error = cloudMessage(e);
      connecting = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> join(String roomCode) async {
    final c = cloud;
    if (c == null || !c.ready) {
      error = 'Online co-op needs the cloud connection.';
      notifyListeners();
      return false;
    }
    connecting = true;
    error = null;
    notifyListeners();
    try {
      final r = await c.joinCoopRoom(roomCode.trim());
      final m = coopMission(r.missionId);
      if (m == null) throw const CloudError('This mission needs a newer version of the app.');
      state = CoopState(m);
      roomId = r.roomId;
      code = roomCode.trim();
      isHost = false;
      final ok = await _connect();
      if (ok) await _link!.send('hello', {'name': myName});
      return ok;
    } catch (e) {
      error = cloudMessage(e);
      connecting = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _connect() async {
    final l = SupabaseLink(cloud!, 'coop:$code', presenceKey: selfId);
    _link = l;
    _msgs = l.messages.listen(_onMessage);
    _peerSub = l.peers.listen(_onPeers);
    final ok = await l.connect({'name': myName, 'host': isHost, 'joined': _joinedAt});
    connecting = false;
    if (!ok) error = 'Could not connect to the room. Check the internet and try again.';
    if (ok) _clock = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick(0.25));
    notifyListeners();
    return ok;
  }

  void _onPeers(List<Map<String, dynamic>> list) {
    peers = [...list]..sort((a, b) {
        if (a['host'] == true) return -1;
        if (b['host'] == true) return 1;
        return ((a['joined'] as num?) ?? 0).compareTo((b['joined'] as num?) ?? 0);
      });
    if (!isHost && state.phase != CoopPhase.lobby && !peers.any((p) => p['host'] == true)) hostGone = true;
    if (isHost && inLobby) _broadcast();
    notifyListeners();
  }

  void _onMessage(LinkMessage m) {
    switch (m.event) {
      case 'hello':
        if (isHost) _broadcast();
      case 'state':
        if (!isHost) {
          final s = m.data['s'];
          if (s is Map) state.applyJson(Map<String, dynamic>.from(s));
        }
      case 'act':
        if (isHost) {
          final r = state.act(m.from, '${m.data['a']}');
          if (r != null) _broadcast();
        }
      case 'next':
        if (isHost) nextRound();
      case 'call':
        calls.insert(0, CoopCall('${m.data['name'] ?? '?'}', '${m.data['text'] ?? ''}'));
        if (calls.length > 12) calls.removeLast();
    }
    _maybeFinish();
    notifyListeners();
  }

  void _tick(double dt) {
    if (!isHost) return;
    final before = state.mistakes;
    state.tick(dt);
    _sinceBroadcast += dt;
    if (state.mistakes != before || _sinceBroadcast >= 1) _broadcast();
    if (state.current.seconds > 0 && state.phase == CoopPhase.playing) notifyListeners();
  }

  void _broadcast() {
    _sinceBroadcast = 0;
    _link?.send('state', {'s': state.toJson()});
  }

  // ---------------------------------------------------------------- game

  /// Host: seat everyone and start.
  void start() {
    if (!isHost) return;
    if (online) {
      final ids = [for (final p in peers) '${p['id']}'];
      if (!ids.contains(selfId)) ids.insert(0, selfId);
      state.seat(ids, {for (final p in peers) '${p['id']}': '${p['name'] ?? 'Player'}', selfId: myName});
      if (roomId != null) cloud?.setCoopStatus(roomId!, 'playing');
    } else {
      state.seat([selfId], {selfId: myName});
      // one phone: every role belongs to this phone
      state.roles[selfId] = state.mission.roles.toSet();
    }
    state.start();
    viewing = state.mission.roles.first;
    _broadcast();
    if (!online) _clock ??= Timer.periodic(const Duration(milliseconds: 250), (_) => _tick(0.25));
    notifyListeners();
  }

  void press(String actionId) {
    if (isHost) {
      state.act(selfId, actionId);
      _broadcast();
      _maybeFinish();
    } else {
      _link?.send('act', {'a': actionId});
    }
    notifyListeners();
  }

  void nextRound() {
    if (isHost) {
      state.nextRound();
      _broadcast();
      _maybeFinish();
    } else {
      _link?.send('next', {});
    }
    notifyListeners();
  }

  void call(String text) {
    calls.insert(0, CoopCall(myName, text));
    if (calls.length > 12) calls.removeLast();
    _link?.send('call', {'name': myName, 'text': text});
    notifyListeners();
  }

  void view(CoopRole r) {
    viewing = r;
    notifyListeners();
  }

  void _maybeFinish() {
    if (!state.finished || _recorded || !isHost) return;
    _recorded = true;
    _clock?.cancel();
    if (roomId != null) cloud?.setCoopStatus(roomId!, 'done');
    onResult?.call({
      'room_id': roomId,
      'mission_id': state.mission.id,
      'players': const <String>[],
      'roles': {for (final e in state.roles.entries) for (final r in e.value) r.name: state.names[e.key] ?? 'Player'},
      'outcome': 'complete',
      'stars': state.stars,
      'duration_s': state.elapsed.round(),
      'mistakes': state.mistakes,
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _msgs?.cancel();
    _peerSub?.cancel();
    final l = _link;
    _link = null;
    if (l != null) unawaited(l.close());
    if (isHost && roomId != null && !state.finished) cloud?.setCoopStatus(roomId!, 'done');
    super.dispose();
  }
}

/// For tests: two controllers on a [LocalHub] without a cloud.
@visibleForTesting
CoopState playLocally(CoopMission m, Map<String, Set<CoopRole>> seats, List<(String, String)> presses) {
  final s = CoopState(m)..start();
  s.roles
    ..clear()
    ..addAll(seats);
  for (final (who, a) in presses) {
    s.act(who, a);
    if (s.phase == CoopPhase.roundDone) s.nextRound();
  }
  return s;
}
