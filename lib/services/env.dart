/// Cloud configuration for Supabase (auth + data).
///
/// Prefers `--dart-define-from-file=env/dev.json` at build time. If those
/// defines are missing (common when launching from the IDE), loads the same
/// public keys from the bundled `env/dev.json` asset so sign-in still works.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Env {
  static String appEnv = const String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  static String supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  static String supabasePublishableKey = const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static String teacherDashboardUrl = const String.fromEnvironment('TEACHER_DASHBOARD_URL');

  /// Sign-in, cloud progress and classes are available.
  static bool get cloudConfigured => supabaseUrl.startsWith('https://') && supabasePublishableKey.isNotEmpty;

  /// Live lesson Realtime needs Supabase.
  static bool get realtimeConfigured => cloudConfigured;

  /// Fill any missing keys from the bundled env file. Safe to call once at startup.
  static Future<void> load() async {
    if (cloudConfigured) {
      debugPrint('Env: cloud keys from dart-define');
      return;
    }
    for (final path in const ['env/dev.json', 'assets/env/dev.json']) {
      try {
        final raw = await rootBundle.loadString(path);
        final map = jsonDecode(raw.replaceFirst(RegExp(r'^\uFEFF'), '')) as Map<String, dynamic>;
        _apply(map);
        if (cloudConfigured) {
          debugPrint('Env: cloud keys loaded from $path');
          return;
        }
      } catch (e) {
        debugPrint('Env: could not read $path ($e)');
      }
    }
    debugPrint('Env: cloud not configured — sign-in stays offline');
  }

  static void _apply(Map<String, dynamic> map) {
    String read(String key) => '${map[key] ?? ''}'.trim();
    if (appEnv.isEmpty || appEnv == 'dev') {
      final v = read('APP_ENV');
      if (v.isNotEmpty) appEnv = v;
    }
    if (supabaseUrl.isEmpty) supabaseUrl = read('SUPABASE_URL');
    if (supabasePublishableKey.isEmpty) supabasePublishableKey = read('SUPABASE_PUBLISHABLE_KEY');
    if (teacherDashboardUrl.isEmpty) teacherDashboardUrl = read('TEACHER_DASHBOARD_URL');
  }
}
