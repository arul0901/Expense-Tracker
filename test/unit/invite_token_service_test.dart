import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/core/utils/invite_token_service.dart';

void main() {
  group('InviteTokenService Tests', () {
    test('extracts token from full HTTPS URL', () {
      final token = InviteTokenService.extractTokenFromQr('https://profin.app/room/join/INV-3TPUD7');
      expect(token, equals('INV-3TPUD7'));
    });

    test('extracts token from URL with trailing parameters or slashes', () {
      final token = InviteTokenService.extractTokenFromQr('https://profin.app/room/join/INV-3TPUD7?ref=share#top');
      expect(token, equals('INV-3TPUD7'));
    });

    test('extracts token from custom scheme profin://', () {
      final token = InviteTokenService.extractTokenFromQr('profin://room/join/INV-3TPUD7');
      expect(token, equals('INV-3TPUD7'));
    });

    test('extracts token from legacy PROFIN:ROOM_INVITE format', () {
      final token = InviteTokenService.extractTokenFromQr('PROFIN:ROOM_INVITE:1:INV-3TPUD7');
      expect(token, equals('INV-3TPUD7'));
    });

    test('normalizes lowercase tokens and short codes', () {
      final token1 = InviteTokenService.extractTokenFromQr('inv-3tpud7');
      expect(token1, equals('INV-3TPUD7'));

      final token2 = InviteTokenService.extractTokenFromQr('3TPUD7');
      expect(token2, equals('INV-3TPUD7'));
    });

    test('formatQrPayload generates standard HTTPS URL', () {
      final payload = InviteTokenService.formatQrPayload('INV-3TPUD7', 1);
      expect(payload, equals('https://profin.app/room/join/INV-3TPUD7'));
    });
  });
}
