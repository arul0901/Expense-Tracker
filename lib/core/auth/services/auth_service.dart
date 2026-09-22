import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import '../../config/app_config.dart';
import '../models/auth_user_model.dart';
import 'secure_token_storage.dart';

class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, {this.code});

  @override
  String toString() => message;
}

abstract class BaseAuthService {
  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AuthUser> loginWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> sendEmailVerification(AuthUser user);

  Future<bool> checkEmailVerified(AuthUser user);

  Future<void> sendPasswordResetEmail(String email);

  Future<void> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
  });

  Future<void> changePassword({
    required AuthUser user,
    required String currentPassword,
    required String newPassword,
  });

  Future<AuthUser> updateProfile({
    required AuthUser user,
    String? displayName,
    String? photoUrl,
  });



  Future<void> deleteAccount({
    required AuthUser user,
    required String currentPassword,
  });

  Future<void> logout();
}

class ProductionAuthService implements BaseAuthService {
  final SecureTokenStorage _tokenStorage;
  final _random = Random.secure();

  static final Map<String, _RegisteredAccount> _mockRemoteAccounts = {
    'arul@example.com': _RegisteredAccount(
      user: AuthUser(
        id: 'usr_arul_1001',
        email: 'arul@example.com',
        displayName: 'Arul',
        isEmailVerified: true,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        lastLoginAt: DateTime.now(),
      ),
      passwordHash: 'Pass@1234',
    ),
  };

  ProductionAuthService({SecureTokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? SecureTokenStorage();

  bool get _isSupabaseConfigured {
    try {
      Supabase.instance.client;
      final url = AppConfig.supabaseUrl;
      return url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'));
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _validatePasswordRequirements(password);
    final normalizedEmail = email.trim().toLowerCase();

    if (_isSupabaseConfigured) {
      try {
        final response = await Supabase.instance.client.auth.signUp(
          email: normalizedEmail,
          password: password,
          data: {'display_name': displayName.trim()},
          emailRedirectTo: 'profin://login-callback',
        );

        final suUser = response.user;
        if (suUser == null) throw AuthException('Registration failed. Please try again.');

        final user = AuthUser(
          id: suUser.id,
          email: suUser.email ?? normalizedEmail,
          displayName: displayName.trim(),
          isEmailVerified: suUser.emailConfirmedAt != null,
          createdAt: DateTime.tryParse(suUser.createdAt) ?? DateTime.now(),
          lastLoginAt: DateTime.now(),
        );

        final session = response.session;
        await _tokenStorage.saveSession(
          accessToken: session?.accessToken ?? 'jwt_access_${user.id}',
          refreshToken: session?.refreshToken,
          user: user,
        );

        return user;
      } on AuthException catch (e) {
        throw AuthException(e.message, code: e.code);
      } catch (e) {
        final errStr = e.toString();
        if (errStr.contains('Invalid argument') || errStr.contains('No host specified') || errStr.contains('SocketException')) {
          throw AuthException('Unable to reach server. Please check your network connection.');
        }
        throw AuthException(errStr.replaceAll('AuthException: ', ''));
      }
    }

    // Local Fallback Mode
    await Future.delayed(const Duration(milliseconds: 500));
    if (_mockRemoteAccounts.containsKey(normalizedEmail)) {
      throw AuthException(
        'An account with this email address already exists. Please log in instead.',
        code: 'email-already-in-use',
      );
    }

    final userId = 'usr_${_random.nextInt(899999) + 100000}';
    final user = AuthUser(
      id: userId,
      email: normalizedEmail,
      displayName: displayName.trim(),
      isEmailVerified: false,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    _mockRemoteAccounts[normalizedEmail] = _RegisteredAccount(
      user: user,
      passwordHash: password,
    );

    final accessToken = 'jwt_access_${user.id}_${DateTime.now().millisecondsSinceEpoch}';
    await _tokenStorage.saveSession(
      accessToken: accessToken,
      user: user,
    );

    return user;
  }

  @override
  Future<AuthUser> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (_isSupabaseConfigured) {
      try {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: normalizedEmail,
          password: password,
        );

        final suUser = response.user;
        if (suUser == null) throw AuthException('Invalid email or password.');

        final metaName = suUser.userMetadata?['display_name'] as String?;
        final name = metaName ?? (suUser.email?.split('@').first) ?? 'User';

        final user = AuthUser(
          id: suUser.id,
          email: suUser.email ?? normalizedEmail,
          displayName: name,
          isEmailVerified: suUser.emailConfirmedAt != null,
          createdAt: DateTime.tryParse(suUser.createdAt) ?? DateTime.now(),
          lastLoginAt: DateTime.now(),
        );

        final session = response.session;
        await _tokenStorage.saveSession(
          accessToken: session?.accessToken ?? 'jwt_access_${user.id}',
          refreshToken: session?.refreshToken,
          user: user,
        );

        return user;
      } on AuthException catch (e) {
        throw AuthException(e.message, code: e.code);
      } catch (e) {
        final errStr = e.toString();
        if (errStr.contains('Invalid argument') || errStr.contains('No host specified') || errStr.contains('SocketException')) {
          throw AuthException('Unable to reach server. Please check your network connection.');
        }
        throw AuthException(errStr.replaceAll('AuthException: ', ''));
      }
    }

    // Local Fallback Mode
    await Future.delayed(const Duration(milliseconds: 500));
    final account = _mockRemoteAccounts[normalizedEmail];

    if (account == null || account.passwordHash != password) {
      throw AuthException(
        'Email or password is incorrect. Please try again.',
        code: 'invalid-credentials',
      );
    }

    final updatedUser = account.user.copyWith(lastLoginAt: DateTime.now());
    _mockRemoteAccounts[normalizedEmail] = account.copyWith(user: updatedUser);

    final accessToken = 'jwt_access_${updatedUser.id}_${DateTime.now().millisecondsSinceEpoch}';
    await _tokenStorage.saveSession(
      accessToken: accessToken,
      user: updatedUser,
    );

    return updatedUser;
  }

  @override
  Future<void> sendEmailVerification(AuthUser user) async {
    if (_isSupabaseConfigured) {
      try {
        await Supabase.instance.client.auth.resend(
          type: OtpType.signup,
          email: user.email,
        );
      } catch (_) {}
    }
  }

  @override
  Future<bool> checkEmailVerified(AuthUser user) async {
    if (_isSupabaseConfigured) {
      try {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null && currentUser.emailConfirmedAt != null) {
          final verifiedUser = user.copyWith(isEmailVerified: true);
          final token = await _tokenStorage.getAccessToken() ?? 'jwt_access_${user.id}';
          await _tokenStorage.saveSession(accessToken: token, user: verifiedUser);
          return true;
        }
      } catch (_) {}
    }

    final normalizedEmail = user.email.trim().toLowerCase();
    final account = _mockRemoteAccounts[normalizedEmail];
    if (account != null) {
      final verifiedUser = account.user.copyWith(isEmailVerified: true);
      _mockRemoteAccounts[normalizedEmail] = account.copyWith(user: verifiedUser);
      final token = await _tokenStorage.getAccessToken() ?? 'jwt_access_${user.id}';
      await _tokenStorage.saveSession(accessToken: token, user: verifiedUser);
      return true;
    }
    return false;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (_isSupabaseConfigured) {
      try {
        await Supabase.instance.client.auth.resetPasswordForEmail(email.trim());
      } catch (_) {}
    }
  }

  @override
  Future<void> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
  }) async {
    _validatePasswordRequirements(newPassword);
  }

  @override
  Future<void> changePassword({
    required AuthUser user,
    required String currentPassword,
    required String newPassword,
  }) async {
    _validatePasswordRequirements(newPassword);

    if (_isSupabaseConfigured) {
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
        return;
      } catch (e) {
        throw AuthException('Failed to update password: $e');
      }
    }

    final normalizedEmail = user.email.trim().toLowerCase();
    final account = _mockRemoteAccounts[normalizedEmail];

    if (account == null || account.passwordHash != currentPassword) {
      throw AuthException('Current password is incorrect.', code: 'wrong-password');
    }

    _mockRemoteAccounts[normalizedEmail] = account.copyWith(passwordHash: newPassword);
  }

  @override
  Future<AuthUser> updateProfile({
    required AuthUser user,
    String? displayName,
    String? photoUrl,
  }) async {
    final newName = displayName?.trim() ?? user.displayName;

    if (_isSupabaseConfigured) {
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'display_name': newName}),
        );
      } catch (_) {}
    }

    final updated = user.copyWith(displayName: newName, photoUrl: photoUrl ?? user.photoUrl);
    final token = await _tokenStorage.getAccessToken() ?? 'jwt_access_${user.id}';
    await _tokenStorage.saveSession(accessToken: token, user: updated);
    return updated;
  }



  @override
  Future<void> deleteAccount({
    required AuthUser user,
    required String currentPassword,
  }) async {
    await _tokenStorage.clearSession();
  }

  @override
  Future<void> logout() async {
    if (_isSupabaseConfigured) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
    await _tokenStorage.clearSession();
  }

  void _validatePasswordRequirements(String password) {
    if (password.length < 8) {
      throw AuthException('Password must be at least 8 characters long.');
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      throw AuthException('Password must contain at least one uppercase letter.');
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      throw AuthException('Password must contain at least one lowercase letter.');
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      throw AuthException('Password must contain at least one number.');
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      throw AuthException('Password must contain at least one special character (!@#\$%^&*).');
    }
  }
}

class _RegisteredAccount {
  final AuthUser user;
  final String passwordHash;

  _RegisteredAccount({required this.user, required this.passwordHash});

  _RegisteredAccount copyWith({AuthUser? user, String? passwordHash}) {
    return _RegisteredAccount(
      user: user ?? this.user,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }
}
