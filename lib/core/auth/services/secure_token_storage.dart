import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_user_model.dart';

class SecureTokenStorage {
  final FlutterSecureStorage _storage;

  static const String _keyAccessToken = 'profin_access_token';
  static const String _keyRefreshToken = 'profin_refresh_token';
  static const String _keyUserJson = 'profin_user_json';
  static const String _keyBiometricEnabled = 'profin_biometric_enabled';
  static const String _keyActiveUserId = 'profin_active_user_id';

  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    required AuthUser user,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
    }
    await _storage.write(key: _keyUserJson, value: jsonEncode(user.toJson()));
    await _storage.write(key: _keyActiveUserId, value: user.id);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<AuthUser?> getUser() async {
    final jsonStr = await _storage.read(key: _keyUserJson);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AuthUser.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getActiveUserId() async {
    return await _storage.read(key: _keyActiveUserId);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometricEnabled, value: enabled ? 'true' : 'false');
  }

  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _keyBiometricEnabled);
    return val == 'true';
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserJson);
    await _storage.delete(key: _keyActiveUserId);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
