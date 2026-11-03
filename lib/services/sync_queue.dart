/// Offline-first sync. Everything the player does is saved on the device first and
/// queued here; the queue is sent to the cloud when there is a signed-in session
/// and a connection. Pure Dart so it can be unit-tested.
library;

import 'dart:convert';

/// One thing to send. [key] lets later ops replace earlier ones of the same kind
/// (the newest campaign state or settings win); attempts never coalesce.
class SyncOp {
  final String kind;
  final String key;
  final Map<String, dynamic> data;
  int tries;
  final int createdMs;

  SyncOp(this.kind, this.data, {String? key, this.tries = 0, int? createdMs})
      : key = key ?? '',
        createdMs = createdMs ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {'k': kind, 'key': key, 'd': data, 't': tries, 'c': createdMs};

  static SyncOp? fromJson(Object? j) {
    if (j is! Map) return null;
    final d = j['d'];
    if (j['k'] is! String || d is! Map) return null;
    return SyncOp(j['k'] as String, Map<String, dynamic>.from(d),
        key: j['key'] as String? ?? '', tries: (j['t'] as num?)?.toInt() ?? 0, createdMs: (j['c'] as num?)?.toInt());
  }
}

/// Thrown by a sender when an op can never succeed (bad data, not allowed):
/// the op is dropped instead of blocking the queue forever.
class PermanentSyncError implements Exception {
  final String reason;
  const PermanentSyncError(this.reason);
  @override
  String toString() => 'PermanentSyncError: $reason';
}

/// Where the queue is kept between launches.
abstract class QueueStore {
  String? read();
  Future<void> write(String value);
}

class MemoryQueueStore implements QueueStore {
  String? value;
  @override
  String? read() => value;
  @override
  Future<void> write(String v) async => value = v;
}

class SyncQueue {
  final QueueStore store;
  final List<SyncOp> _ops = [];

  /// Ops are given up after this many failed sends (about a week of retries).
  static const maxTries = 40;
  static const maxOps = 2000;
  bool _flushing = false;

  SyncQueue(this.store) {
    try {
      final raw = store.read();
      if (raw != null && raw.isNotEmpty) {
        for (final j in (jsonDecode(raw) as List)) {
          final op = SyncOp.fromJson(j);
          if (op != null) _ops.add(op);
        }
      }
    } catch (_) {
      // a corrupt queue is dropped rather than crashing the game
      _ops.clear();
    }
  }

  int get length => _ops.length;
  bool get isEmpty => _ops.isEmpty;
  List<SyncOp> get pending => List.unmodifiable(_ops);

  Future<void> add(SyncOp op) async {
    if (op.key.isNotEmpty) _ops.removeWhere((o) => o.kind == op.kind && o.key == op.key);
    _ops.add(op);
    if (_ops.length > maxOps) _ops.removeRange(0, _ops.length - maxOps);
    await _save();
  }

  Future<void> clear() async {
    _ops.clear();
    await _save();
  }

  /// Sends ops in order. Stops at the first temporary failure (no connection),
  /// drops ops that fail permanently. Returns how many were sent.
  Future<int> flush(Future<void> Function(SyncOp op) send) async {
    if (_flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      while (_ops.isNotEmpty) {
        final op = _ops.first;
        try {
          await send(op);
          _ops.removeAt(0);
          sent++;
        } on PermanentSyncError {
          _ops.removeAt(0);
        } catch (_) {
          op.tries++;
          if (op.tries >= maxTries) _ops.removeAt(0);
          break;
        }
      }
    } finally {
      _flushing = false;
      await _save();
    }
    return sent;
  }

  Future<void> _save() async {
    try {
      await store.write(jsonEncode([for (final o in _ops) o.toJson()]));
    } catch (_) {}
  }
}
