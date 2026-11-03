/// What a finished level reports: saved on the device and queued for the cloud.
/// Pure Dart.
library;

import 'dart:math' as math;

import '../cloud/models.dart' show Decision;
import '../data/catalogue.dart';
import 'story_model.dart' show AgeMode;

/// What a finished level reports (saved locally, queued for the cloud).
class LevelRecord {
  final String clientId;
  final String levelId;
  final AgeMode mode;
  final DateTime startedAt;
  final DateTime endedAt;
  final bool complete;
  final int stars;
  final int mistakes;
  final int hints;
  final List<Decision> decisions;
  final List<(Skill, bool)> evidence;
  final CampaignId campaign;
  final int n;
  final Map<String, Object> carry;

  const LevelRecord({
    required this.clientId,
    required this.levelId,
    required this.mode,
    required this.startedAt,
    required this.endedAt,
    required this.complete,
    required this.stars,
    required this.mistakes,
    required this.hints,
    required this.decisions,
    required this.evidence,
    required this.campaign,
    required this.n,
    required this.carry,
  });

  Map<String, dynamic> attemptJson() => {
        'client_id': clientId,
        'level_id': levelId,
        'age_mode': mode.name,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
        'outcome': complete ? 'complete' : 'failed',
        'stars': complete ? stars : 0,
        'mistakes': mistakes.clamp(0, 999),
        'hints': hints.clamp(0, 999),
        'duration_s': endedAt.difference(startedAt).inSeconds.clamp(0, 86400),
        'decisions': [for (final d in decisions.take(60)) d.toJson()],
      };

  List<Map<String, dynamic>> skillsJson() => [for (final (k, good) in evidence.take(200)) {'skill': k.db, 'correct': good}];
}

/// A random version-4 UUID (for idempotent offline sync).
String newClientId() {
  final r = math.Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  final s = [for (var i = 0; i < 16; i++) h(i)].join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

