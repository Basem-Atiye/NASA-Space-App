/// [Link] over a Supabase Realtime channel: broadcast for messages, Presence for
/// who is here. Free tier is plenty for a classroom (200 connections, 100 msg/s).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud.dart';
import 'link.dart';

class SupabaseLink implements Link {
  final Cloud cloud;
  final String topic;
  final bool private;
  @override
  final String selfId;

  RealtimeChannel? _ch;
  final _messages = StreamController<LinkMessage>.broadcast();
  final _peers = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _states = StreamController<LinkState>.broadcast();
  List<Map<String, dynamic>> _current = const [];
  Map<String, dynamic> _me = const {};
  @override
  LinkState state = LinkState.idle;

  SupabaseLink(this.cloud, this.topic, {this.private = false, required String presenceKey}) : selfId = presenceKey;

  @override
  Stream<LinkMessage> get messages => _messages.stream;
  @override
  Stream<List<Map<String, dynamic>>> get peers => _peers.stream;
  @override
  Stream<LinkState> get states => _states.stream;
  @override
  List<Map<String, dynamic>> get currentPeers => _current;

  void _set(LinkState s) {
    state = s;
    if (!_states.isClosed) _states.add(s);
  }

  @override
  Future<bool> connect(Map<String, dynamic> me) async {
    if (!cloud.ready) {
      _set(LinkState.failed);
      return false;
    }
    _me = me;
    _set(LinkState.connecting);
    final done = Completer<bool>();
    final ch = cloud.channel(topic, private: private, presenceKey: selfId);
    _ch = ch;
    ch.onBroadcast(
      event: '*',
      callback: (msg) {
        final event = msg['event'] as String? ?? '';
        final raw = msg['payload'];
        final data = raw is Map ? Map<String, dynamic>.from(raw) : Map<String, dynamic>.from(msg);
        final from = data.remove('_from') as String? ?? '';
        if (from == selfId || _messages.isClosed) return;
        _messages.add(LinkMessage(event, data, from));
      },
    );
    ch.onPresenceSync((_) => _readPresence());
    ch.onPresenceJoin((_) => _readPresence());
    ch.onPresenceLeave((_) => _readPresence());
    ch.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        try {
          await ch.track({..._me});
        } catch (e) {
          debugPrint('presence track failed: $e');
        }
        _set(LinkState.connected);
        if (!done.isCompleted) done.complete(true);
      } else if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
        debugPrint('realtime $topic: $status $error');
        _set(LinkState.failed);
        if (!done.isCompleted) done.complete(false);
      } else if (status == RealtimeSubscribeStatus.closed) {
        if (state != LinkState.closed) _set(LinkState.closed);
        if (!done.isCompleted) done.complete(false);
      }
    });
    return done.future.timeout(const Duration(seconds: 12), onTimeout: () {
      _set(LinkState.failed);
      return false;
    });
  }

  void _readPresence() {
    final ch = _ch;
    if (ch == null || _peers.isClosed) return;
    final list = <Map<String, dynamic>>[];
    for (final s in ch.presenceState()) {
      if (s.presences.isEmpty) continue;
      list.add({...s.presences.last.payload, 'id': s.key});
    }
    _current = list;
    _peers.add(list);
  }

  @override
  Future<void> updatePresence(Map<String, dynamic> me) async {
    _me = me;
    try {
      await _ch?.track({...me});
    } catch (_) {}
  }

  @override
  Future<void> send(String event, Map<String, dynamic> data) async {
    final ch = _ch;
    if (ch == null || state != LinkState.connected) return;
    try {
      await ch.sendBroadcastMessage(event: event, payload: {...data, '_from': selfId});
    } catch (e) {
      debugPrint('broadcast failed: $e');
    }
  }

  @override
  Future<void> close() async {
    final ch = _ch;
    _ch = null;
    if (ch != null) {
      try {
        await ch.untrack();
      } catch (_) {}
      await cloud.removeChannel(ch);
    }
    _set(LinkState.closed);
    await _messages.close();
    await _peers.close();
    await _states.close();
  }
}
