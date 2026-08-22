import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:expense_tracker/core/auth/services/auth_service.dart';
import 'package:expense_tracker/core/auth/services/secure_token_storage.dart';
import 'package:expense_tracker/core/auth/models/auth_user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  late ProductionAuthService authService;

  setUp(() {
    authService = ProductionAuthService();
  });

  group('1 & 4. Comprehensive Authentication Tests', () {
    test('Sign Up with valid email and password creates user account', () async {
      final email = 'profin.test@example.com';
      final password = 'StrongPassword123!';
      final displayName = 'ProFin Tester';

      final user = await authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        displayName: displayName,
      );

      expect(user.email, equals(email));
      expect(user.displayName, equals(displayName));
      expect(user.id, isNotEmpty);
    });

    test('Sign Up fails on weak password missing uppercase or numbers', () {
      expect(
        () => authService.signUpWithEmailAndPassword(
          email: 'weak@example.com',
          password: 'weak',
          displayName: 'Weak User',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('Login succeeds with correct credentials', () async {
      final email = 'profin.test@example.com';
      final password = 'StrongPassword123!';

      final user = await authService.loginWithEmailAndPassword(
        email: email,
        password: password,
      );

      expect(user.email, equals(email));
      expect(user.displayName, equals('ProFin Tester'));
    });

    test('Login fails with wrong password', () {
      expect(
        () => authService.loginWithEmailAndPassword(
          email: 'profin.test@example.com',
          password: 'WrongPassword123!',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('Session restoration preserves user credentials and clearSession logs out', () async {
      final tokenStorage = SecureTokenStorage();
      final user = AuthUser(
        id: 'usr_profin_test',
        email: 'profin.test@example.com',
        displayName: 'ProFin Tester',
        isEmailVerified: true,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      await tokenStorage.saveSession(accessToken: 'token_123', user: user);
      final restored = await tokenStorage.getUser();
      expect(restored?.email, equals('profin.test@example.com'));

      await authService.logout();
      final clearedUser = await tokenStorage.getUser();
      expect(clearedUser, isNull);
    });

    test('Password recovery request accepts valid registered email', () async {
      await expectLater(
        authService.sendPasswordResetEmail('profin.test@example.com'),
        completes,
      );
    });
  });
}
