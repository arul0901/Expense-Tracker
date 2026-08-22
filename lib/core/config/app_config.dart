class AppConfig {
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  /// Supabase Project URL (Passed via --dart-define-from-file=.env or --dart-define=SUPABASE_URL=...)
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase Anon Key (Passed via --dart-define-from-file=.env or --dart-define=SUPABASE_ANON_KEY=...)
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';

  /// Deep link settings
  static const String appScheme = 'profin';
  static const String webDomain = 'profin.app';
  static String get inviteUrlPrefix => 'https://$webDomain/room/join/';
}
