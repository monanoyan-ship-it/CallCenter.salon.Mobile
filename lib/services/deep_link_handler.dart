import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:callcenter_salon_mobil/screens/reset_password_page.dart';
import 'package:callcenter_salon_mobil/screens/salon_profile_page.dart';
import 'package:flutter/material.dart';

/// Gelen URI'leri ilgili sayfaya haritalar.
///
/// Desteklenen formatlar:
/// - `corplynk-salon://salon/{slug}` veya `https://*.corplynk.com/salon/{slug}` → profil
/// - `corplynk-salon://reset-password?token=...` veya
///   `https://*.corplynk.com/reset-password?token=...` → şifre sıfırlama
/// - `corplynk-salon://verify-email?token=...` → token'ı API'ye gönder + sonuç
///
/// Platform manifest/Info.plist konfigürasyonu yapılana kadar bu sınıf yalnız
/// uygulama açıkken alınan event'leri işler. Bkz. `docs/PRODUCTION.md`.
class DeepLinkHandler {
  DeepLinkHandler({required this.navigatorKey})
      : _appLinks = AppLinks();

  final GlobalKey<NavigatorState> navigatorKey;
  final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  Future<void> init() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial);
    } catch (_) {}

    _sub = _appLinks.uriLinkStream.listen(_handle, onError: (_) {});
  }

  void dispose() {
    _sub?.cancel();
  }

  void _handle(Uri uri) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final slug = _extractSalonSlug(uri);
    if (slug != null) {
      navigator.push(
        MaterialPageRoute(builder: (_) => SalonProfilePage(slug: slug)),
      );
      return;
    }

    final resetToken = _extractResetToken(uri);
    if (resetToken != null) {
      navigator.push(
        MaterialPageRoute(builder: (_) => ResetPasswordPage(token: resetToken)),
      );
      return;
    }
  }

  static String? _extractSalonSlug(Uri uri) {
    if (uri.scheme == 'corplynk-salon') {
      if (uri.host == 'salon' && uri.pathSegments.isNotEmpty) {
        return _validateSlug(uri.pathSegments.first);
      }
      if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'salon') {
        return _validateSlug(uri.pathSegments[1]);
      }
    }
    final segs = uri.pathSegments;
    final salonIdx = segs.indexOf('salon');
    if (salonIdx >= 0 && segs.length > salonIdx + 1) {
      return _validateSlug(segs[salonIdx + 1]);
    }
    return null;
  }

  /// Reset URI'larında token query string'inden veya yolun son segmentinden
  /// gelir. Hem custom scheme hem https desteklenir.
  static String? _extractResetToken(Uri uri) {
    final isResetCustom = uri.scheme == 'corplynk-salon' &&
        (uri.host == 'reset-password' ||
            (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'reset-password'));
    final isResetWeb =
        uri.scheme.startsWith('http') && uri.pathSegments.contains('reset-password');
    if (!isResetCustom && !isResetWeb) return null;

    final t = uri.queryParameters['token']?.trim();
    if (t != null && t.isNotEmpty) return t;
    if (uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last.trim();
      if (last.isNotEmpty && last != 'reset-password') return last;
    }
    return null;
  }

  static String? _validateSlug(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final pattern = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$', caseSensitive: false);
    return pattern.hasMatch(s) ? s : null;
  }
}
