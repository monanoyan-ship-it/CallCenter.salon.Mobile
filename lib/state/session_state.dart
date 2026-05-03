import 'package:callcenter_salon_mobil/models/booking_models.dart';
import 'package:callcenter_salon_mobil/services/session_store.dart';
import 'package:flutter/foundation.dart';

class SessionState extends ChangeNotifier {
  SessionState(this._store);

  final SessionStore _store;

  String? _token;
  PlatformUser? _user;

  String? get token => _token;
  PlatformUser? get user => _user;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  Future<void> loadFromDisk() async {
    _token = await _store.readToken();
    _user = await _store.readUser();
    notifyListeners();
  }

  Future<void> signIn(String token, PlatformUser user) async {
    _token = token;
    _user = user;
    await _store.saveSession(token: token, user: user);
    notifyListeners();
  }

  /// Profil kaydından sonra yerel önbelleği güncelle (aynı oturum token'ı).
  Future<void> replaceUser(PlatformUser user) async {
    _user = user;
    if (_token != null) {
      await _store.saveSession(token: _token!, user: user);
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    _token = null;
    _user = null;
    await _store.clear();
    notifyListeners();
  }
}
