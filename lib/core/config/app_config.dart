class AppConfig {
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  /// Supabase Project URL (Passed via --dart-define-from-file=.env or --dart-define=SUPABASE_URL=...)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://cuukuohykhlrhkrvvjlt.supabase.co',
  );

  /// Supabase Anon Key (Passed via --dart-define-from-file=.env or --dart-define=SUPABASE_ANON_KEY=...)
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN1dWt1b2h5a2hscmhrcnZ2amx0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxMTYyODEsImV4cCI6MjEwMjY5MjI4MX0.uQCN_eZFWhaSE5mVdS2xjjlIpPh-rdFzZOFDb2fQuno',
  );

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';

  /// Deep link settings
  static const String appScheme = 'profin';
  static const String webDomain = 'profin.app';
  static String get inviteUrlPrefix => 'https://$webDomain/room/join/';
}
