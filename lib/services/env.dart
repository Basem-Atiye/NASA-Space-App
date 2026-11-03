/// Build-time configuration, passed with
///   flutter run --dart-define-from-file=env/dev.json
/// Only public keys belong here (Clerk publishable key, Supabase publishable key).
/// Without them the app runs fully offline: guest play, progress on the device.
library;

class Env {
  static const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  static const clerkPublishableKey = String.fromEnvironment('CLERK_PUBLISHABLE_KEY');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const teacherDashboardUrl = String.fromEnvironment('TEACHER_DASHBOARD_URL');
  static const coopRegionHint = String.fromEnvironment('COOP_REGION_HINT', defaultValue: 'eu-central-1');

  /// Sign-in, cloud progress, classes and online co-op are available.
  static bool get cloudConfigured =>
      clerkPublishableKey.startsWith('pk_') && supabaseUrl.startsWith('https://') && supabasePublishableKey.isNotEmpty;

  /// Online co-op only needs Supabase (guests can play without signing in).
  static bool get realtimeConfigured => supabaseUrl.startsWith('https://') && supabasePublishableKey.isNotEmpty;
}
