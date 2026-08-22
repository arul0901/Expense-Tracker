import 'auth_user_model.dart';

enum AuthStatus {
  unknown,
  unauthenticated,
  authenticating,
  authenticated,
  verifyingEmail,
  biometricLocked,
  error,
}

class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final String? accessToken;
  final String? refreshToken;
  final String? errorMessage;
  final bool isBiometricEnabled;
  final DateTime? lastActiveAt;

  const AuthState({
    required this.status,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.errorMessage,
    this.isBiometricEnabled = false,
    this.lastActiveAt,
  });

  factory AuthState.unknown() {
    return const AuthState(status: AuthStatus.unknown);
  }

  factory AuthState.unauthenticated({String? errorMessage}) {
    return AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage: errorMessage,
    );
  }

  factory AuthState.authenticating() {
    return const AuthState(status: AuthStatus.authenticating);
  }

  factory AuthState.authenticated({
    required AuthUser user,
    required String accessToken,
    String? refreshToken,
    bool isBiometricEnabled = false,
  }) {
    return AuthState(
      status: AuthStatus.authenticated,
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      isBiometricEnabled: isBiometricEnabled,
      lastActiveAt: DateTime.now(),
    );
  }

  factory AuthState.verifyingEmail({
    required AuthUser user,
    required String accessToken,
  }) {
    return AuthState(
      status: AuthStatus.verifyingEmail,
      user: user,
      accessToken: accessToken,
    );
  }

  factory AuthState.biometricLocked({
    required AuthUser user,
    required String accessToken,
  }) {
    return AuthState(
      status: AuthStatus.biometricLocked,
      user: user,
      accessToken: accessToken,
      isBiometricEnabled: true,
    );
  }

  factory AuthState.error(String message) {
    return AuthState(
      status: AuthStatus.error,
      errorMessage: message,
    );
  }

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    String? accessToken,
    String? refreshToken,
    String? errorMessage,
    bool? isBiometricEnabled,
    DateTime? lastActiveAt,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      errorMessage: errorMessage,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isVerifyingEmail => status == AuthStatus.verifyingEmail;
  bool get isBiometricLocked => status == AuthStatus.biometricLocked;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
}
