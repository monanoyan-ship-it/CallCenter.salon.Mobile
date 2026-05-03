import 'dart:convert';

import 'package:callcenter_salon_mobil/models/booking_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Platform kullanıcı JWT + profil özeti.
class SessionStore {
  static const _kToken = 'platform_jwt';
  static const _kUserJson = 'platform_user_json';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> readToken() => _storage.read(key: _kToken);

  Future<PlatformUser?> readUser() async {
    final raw = await _storage.read(key: _kUserJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return PlatformUser.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession({required String token, required PlatformUser user}) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(
      key: _kUserJson,
      value: jsonEncode({
        'fullName': user.fullName,
        'phone': user.phone,
        'email': user.email,
      }),
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUserJson);
  }
}
