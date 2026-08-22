import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:expense_tracker/core/auth/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('Authentication Architecture Tests', () {
    late ProductionAuthService authService;

    setUp(() {
      authService = ProductionAuthService();
    });

    test('Log in succeeds with valid credentials', () async {
      final user = await authService.loginWithEmailAndPassword(
        email: 'arul@example.com',
        password: 'Pass@1234',
      );

      expect(user.email, equals('arul@example.com'));
      expect(user.displayName, equals('Arul'));
      expect(user.isEmailVerified, isTrue);
    });

    test('Log in fails with incorrect password and throws translated error', () async {
      expect(
        () async => await authService.loginWithEmailAndPassword(
          email: 'arul@example.com',
          password: 'WrongPassword123',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('Email or password is incorrect'),
        )),
      );
    });

    test('Sign up enforces password requirements (min 8, uppercase, lowercase, number, special)', () async {
      // Weak password missing special character
      expect(
        () async => await authService.signUpWithEmailAndPassword(
          email: 'newuser@example.com',
          password: 'Password123',
          displayName: 'New User',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('special character'),
        )),
      );
    });

    test('Sign up creates new account with valid credentials', () async {
      final newEmail = 'testuser_${DateTime.now().millisecondsSinceEpoch}@example.com';
      final user = await authService.signUpWithEmailAndPassword(
        email: newEmail,
        password: 'SecurePass@123',
        displayName: 'Test User',
      );

      expect(user.email, equals(newEmail));
      expect(user.displayName, equals('Test User'));
      expect(user.isEmailVerified, isFalse);
    });

    test('Duplicate sign up fails with user-friendly error', () async {
      expect(
        () async => await authService.signUpWithEmailAndPassword(
          email: 'arul@example.com',
          password: 'ValidPass@123',
          displayName: 'Arul Duplicate',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('already exists'),
        )),
      );
    });

    test('Change password verifies current password before updating', () async {
      final user = await authService.loginWithEmailAndPassword(
        email: 'arul@example.com',
        password: 'Pass@1234',
      );

      // Wrong current password
      expect(
        () async => await authService.changePassword(
          user: user,
          currentPassword: 'WrongPass@123',
          newPassword: 'NewSecurePass@999',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('Current password is incorrect'),
        )),
      );

      // Correct current password
      await authService.changePassword(
        user: user,
        currentPassword: 'Pass@1234',
        newPassword: 'NewSecurePass@999',
      );

      // Verify login with new password
      final reloggedUser = await authService.loginWithEmailAndPassword(
        email: 'arul@example.com',
        password: 'NewSecurePass@999',
      );
      expect(reloggedUser.id, equals(user.id));
    });
  });
}
