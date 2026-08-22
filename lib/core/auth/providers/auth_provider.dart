// ignore_for_file: prefer_initializing_formals
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState, AuthException;
import '../models/auth_state.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/secure_token_storage.dart';

final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  return SecureTokenStorage();
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final authServiceProvider = Provider<BaseAuthService>((ref) {
  return ProductionAuthService(tokenStorage: ref.watch(secureTokenStorageProvider));
});

final authNotifierProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier(
    authService: ref.watch(authServiceProvider),
    tokenStorage: ref.watch(secureTokenStorageProvider),
    biometricService: ref.watch(biometricServiceProvider),
  );
});

class AuthStateNotifier extends StateNotifier<AuthState> {
  final BaseAuthService _authService;
  final SecureTokenStorage _tokenStorage;
  final BiometricService _biometricService;

  AuthStateNotifier({
    required BaseAuthService authService,
    required SecureTokenStorage tokenStorage,
    required BiometricService biometricService,
  })  : _authService = authService,
        _tokenStorage = tokenStorage,
        _biometricService = biometricService,
        super(AuthState.unknown()) {
    initializeSession();
  }

  /// Restores session on app startup
  Future<void> initializeSession() async {
    try {
      try {
        final suSession = Supabase.instance.client.auth.currentSession;
        if (suSession != null && suSession.isExpired) {
          await Supabase.instance.client.auth.refreshSession();
        }
      } catch (_) {}

      final token = await _tokenStorage.getAccessToken();
      final user = await _tokenStorage.getUser();
      final isBiometricEnabled = await _tokenStorage.isBiometricEnabled();

      if (token != null && user != null) {
        if (isBiometricEnabled) {
          state = AuthState.biometricLocked(user: user, accessToken: token);
        } else {
          state = AuthState.authenticated(
            user: user,
            accessToken: token,
            isBiometricEnabled: isBiometricEnabled,
          );
        }
      } else {
        state = AuthState.unauthenticated();
      }
    } catch (e) {
      state = AuthState.unauthenticated();
    }
  }

  /// Unlock biometric session
  Future<bool> unlockWithBiometrics() async {
    if (state.user == null || state.accessToken == null) return false;

    final authenticated = await _biometricService.authenticate(
      reason: 'Please authenticate to unlock ProFin.',
    );

    if (authenticated) {
      state = AuthState.authenticated(
        user: state.user!,
        accessToken: state.accessToken!,
        isBiometricEnabled: true,
      );
      return true;
    }
    return false;
  }

  /// Toggle Biometric protection in Settings
  Future<bool> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      final canUse = await _biometricService.canCheckBiometrics();
      if (!canUse) {
        return false;
      }
      final success = await _biometricService.authenticate(
        reason: 'Confirm biometrics to enable App Lock.',
      );
      if (!success) return false;
    }

    await _tokenStorage.setBiometricEnabled(enabled);
    if (state.isAuthenticated && state.user != null && state.accessToken != null) {
      state = AuthState.authenticated(
        user: state.user!,
        accessToken: state.accessToken!,
        isBiometricEnabled: enabled,
      );
    }
    return true;
  }

  /// Login with email & password
  Future<bool> login(String email, String password) async {
    state = AuthState.authenticating();
    try {
      final user = await _authService.loginWithEmailAndPassword(
        email: email,
        password: password,
      );

      final token = await _tokenStorage.getAccessToken() ?? 'token_${user.id}';
      final isBiometric = await _tokenStorage.isBiometricEnabled();

      state = AuthState.authenticated(
        user: user,
        accessToken: token,
        isBiometricEnabled: isBiometric,
      );
      return true;
    } on AuthException catch (e) {
      state = AuthState.unauthenticated(errorMessage: e.message);
      return false;
    } catch (_) {
      state = AuthState.unauthenticated(errorMessage: 'Unable to sign in. Please try again.');
      return false;
    }
  }

  /// Sign Up with email & password
  Future<bool> signUp(String email, String password, String displayName) async {
    state = AuthState.authenticating();
    try {
      await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        displayName: displayName,
      );

      state = AuthState.unauthenticated();
      return true;
    } on AuthException catch (e) {
      state = AuthState.unauthenticated(errorMessage: e.message);
      return false;
    } catch (_) {
      state = AuthState.unauthenticated(errorMessage: 'Unable to create account. Please try again.');
      return false;
    }
  }

  /// Refresh email verification status
  Future<bool> checkEmailVerified() async {
    if (state.user == null) return false;
    final isVerified = await _authService.checkEmailVerified(state.user!);

    if (isVerified) {
      final updatedUser = state.user!.copyWith(isEmailVerified: true);
      final isBiometric = await _tokenStorage.isBiometricEnabled();
      state = AuthState.authenticated(
        user: updatedUser,
        accessToken: state.accessToken ?? 'token_${updatedUser.id}',
        isBiometricEnabled: isBiometric,
      );
      return true;
    }
    return false;
  }

  /// Send verification email again
  Future<void> resendVerificationEmail() async {
    if (state.user != null) {
      await _authService.sendEmailVerification(state.user!);
    }
  }

  /// Send password reset link
  Future<void> sendPasswordReset(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  /// Update Profile details
  Future<bool> updateProfile({String? displayName, String? photoUrl}) async {
    if (state.user == null) return false;
    try {
      final updated = await _authService.updateProfile(
        user: state.user!,
        displayName: displayName,
        photoUrl: photoUrl,
      );
      final isBiometric = await _tokenStorage.isBiometricEnabled();
      state = AuthState.authenticated(
        user: updated,
        accessToken: state.accessToken ?? '',
        isBiometricEnabled: isBiometric,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Change Password
  Future<void> changePassword(String currentPassword, String newPassword) async {
    if (state.user == null) throw AuthException('User not authenticated');
    await _authService.changePassword(
      user: state.user!,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Delete Account
  Future<bool> deleteAccount(String currentPassword) async {
    if (state.user == null) return false;
    try {
      await _authService.deleteAccount(
        user: state.user!,
        currentPassword: currentPassword,
      );
      state = AuthState.unauthenticated();
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _authService.logout();
    state = AuthState.unauthenticated();
  }
}
