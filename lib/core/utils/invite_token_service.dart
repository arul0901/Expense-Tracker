import 'dart:math';

class InviteTokenPayload {
  final String token;
  final int roomId;
  final DateTime expiresAt;
  final String role;

  InviteTokenPayload({
    required this.token,
    required this.roomId,
    required this.expiresAt,
    this.role = 'Member',
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  String get deepLink => 'profin://room/join/$token';
  String get webLink => 'https://profin.app/room/join/$token';
}

class InviteTokenService {
  static final _random = Random.secure();

  /// Generates a secure random 8-character token like 'INV-8F92A1'
  static String generateSecureToken() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final result = StringBuffer('INV-');
    for (int i = 0; i < 6; i++) {
      result.write(chars[_random.nextInt(chars.length)]);
    }
    return result.toString();
  }

  /// Format QR code payload as standard HTTPS URL for high compatibility
  static String formatQrPayload(String token, int roomId) {
    return 'https://profin.app/room/join/${token.trim()}';
  }

  /// Parse QR code payload, link, or manual input robustly
  static String? extractTokenFromQr(String rawInput) {
    final text = rawInput.trim();
    if (text.isEmpty) return null;

    String? candidate;

    // 1. Scheme prefix profin://room/join/{token}
    if (text.toLowerCase().startsWith('profin://room/join/')) {
      candidate = text.substring('profin://room/join/'.length);
    }
    // 2. Custom legacy payload PROFIN:ROOM_INVITE:{roomId}:{token}
    else if (text.toUpperCase().startsWith('PROFIN:ROOM_INVITE:')) {
      final parts = text.split(':');
      if (parts.length >= 4) {
        candidate = parts[3];
      }
    }
    // 3. Web URL e.g. https://profin.app/room/join/{token}
    else if (text.toLowerCase().contains('/room/join/')) {
      final idx = text.toLowerCase().indexOf('/room/join/');
      candidate = text.substring(idx + '/room/join/'.length);
    }
    // 4. Raw token starting with INV- or code like 3TPUD7
    else {
      candidate = text;
    }

    if (candidate == null || candidate.trim().isEmpty) return null;

    return _sanitizeToken(candidate);
  }

  static String _sanitizeToken(String tokenStr) {
    // Strip query parameters, hashes, and trailing path segments
    var cleaned = tokenStr.split('?').first.split('#').first.split('/').first.trim();

    // Remove non-alphanumeric except hyphen
    cleaned = cleaned.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');

    // Auto-prefix INV- if only 6-8 chars entered
    if (!cleaned.toUpperCase().startsWith('INV-') && RegExp(r'^[A-Z0-9]{5,8}$', caseSensitive: false).hasMatch(cleaned)) {
      cleaned = 'INV-$cleaned';
    }

    return cleaned.toUpperCase();
  }
}
