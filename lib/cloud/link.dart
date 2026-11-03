/// A tiny message link between phones: broadcast events plus "who is here"
/// (presence). Used by co-op missions and the teacher's live lesson.
///
/// [SupabaseLink] (supabase_link.dart) goes over Supabase Realtime. [LocalHub]
/// connects links inside one app: same-phone co-op and the tests.
library;

import 'dart:async';

class LinkMessage {
  final String event;
  final Map<String, dynamic> data;

  /// The sender's link id (presence key).
  final String from;
  const LinkMessage(this.event, this.data, this.from);
}

enum LinkState { idle, connecting, connected, failed, closed }

abstract class Link {
  /// This phone's id on the link.
  String get selfId;
  LinkState get state;
  Stream<LinkState> get states;

  /// Messages from the other phones (never echoes our own).
  Stream<LinkMessage> get messages;

  /// Everyone here, including us: each map is that phone's presence payload
  /// with its id under 'id'.
  Stream<List<Map<String, dynamic>>> get peers;
  List<Map<String, dynamic>> get currentPeers;

  Future<bool> connect(Map<String, dynamic> me);
  Future<void> updatePresence(Map<String, dynamic> me);
  Future<void> send(String event, Map<String, dynamic> data);
  Future<void> close();
}

/// Connects [LocalLink]s in memory, as if they were phones on one channel.
class LocalHub {
  final Map<String, LocalLink> _links = {};
  final Map<String, Map<String, dynamic>> _presence = {};

  /// Simulated network delay (0 for tests).
  final Duration delay;
  LocalHub({this.delay = Duration.zero});

  LocalLink link(String id) => LocalLink._(this, id);

  void _join(LocalLink l, Map<String, dynamic> me) {
    _links[l.selfId] = l;
    _presence[l.selfId] = {...me, 'id': l.selfId};
    _announce();
  }

  void _leave(LocalLink l) {
    _links.remove(l.selfId);
    _presence.remove(l.selfId);
    _announce();
  }

  void _announce() {
    final all = [for (final p in _presence.values) Map<String, dynamic>.from(p)];
    for (final l in _links.values.toList()) {
      l._peers.add(all);
      l._current = all;
    }
  }

  void _send(LocalLink from, String event, Map<String, dynamic> data) {
    for (final l in _links.values.toList()) {
      if (l == from) continue;
      final msg = LinkMessage(event, Map<String, dynamic>.from(data), from.selfId);
      if (delay == Duration.zero) {
        l._messages.add(msg);
      } else {
        Timer(delay, () {
          if (!l._messages.isClosed) l._messages.add(msg);
        });
      }
    }
  }
}

class LocalLink implements Link {
  final LocalHub _hub;
  @override
  final String selfId;
  final _messages = StreamController<LinkMessage>.broadcast(sync: true);
  final _peers = StreamController<List<Map<String, dynamic>>>.broadcast(sync: true);
  final _states = StreamController<LinkState>.broadcast(sync: true);
  List<Map<String, dynamic>> _current = const [];
  @override
  LinkState state = LinkState.idle;

  LocalLink._(this._hub, this.selfId);

  @override
  Stream<LinkMessage> get messages => _messages.stream;
  @override
  Stream<List<Map<String, dynamic>>> get peers => _peers.stream;
  @override
  Stream<LinkState> get states => _states.stream;
  @override
  List<Map<String, dynamic>> get currentPeers => _current;

  @override
  Future<bool> connect(Map<String, dynamic> me) async {
    state = LinkState.connected;
    _states.add(state);
    _hub._join(this, me);
    return true;
  }

  @override
  Future<void> updatePresence(Map<String, dynamic> me) async => _hub._join(this, me);

  @override
  Future<void> send(String event, Map<String, dynamic> data) async {
    if (state == LinkState.connected) _hub._send(this, event, data);
  }

  @override
  Future<void> close() async {
    if (state == LinkState.closed) return;
    _hub._leave(this);
    state = LinkState.closed;
    _states.add(state);
    await _messages.close();
    await _peers.close();
    await _states.close();
  }
}
