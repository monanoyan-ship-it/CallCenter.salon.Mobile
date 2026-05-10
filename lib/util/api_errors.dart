import 'dart:convert';

import 'package:callcenter_salon_mobil/config/app_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// API hatalarını kullanıcı-dostu Türkçe mesaja çevirir. Web'de en çok görülen
/// "XMLHttpRequest error" / SSL sertifika reddi / CORS / connection-refused
/// gibi karmaşık altyapı mesajları için yol-haritası verir.
String dioErrorMessage(Object e) {
  if (e is! DioException) return e.toString();

  // 1) Backend gövdesinden gelen `message`'ı tercih et.
  final data = e.response?.data;
  if (data is Map && data['message'] != null) return data['message'].toString();
  if (data is String) {
    try {
      final j = jsonDecode(data);
      if (j is Map && j['message'] != null) return j['message'].toString();
    } catch (_) {}
  }

  final raw = (e.message ?? e.toString());
  final lower = raw.toLowerCase();
  final base = AppConfig.apiBaseUrl;
  final isHttps = base.startsWith('https://');
  final isLocalhost =
      base.contains('localhost') || base.contains('127.0.0.1') || base.contains('10.0.2.2');

  // 2) Timeout
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return 'Sunucuya ulaşılamadı (zaman aşımı). API ($base) açık mı? Ağ bağlantınızı kontrol edin.';
  }

  // 3) Sertifika reddi (mobil/desktop)
  if (lower.contains('handshakeexception') ||
      lower.contains('certificate') ||
      lower.contains('certverify')) {
    final hint = isLocalhost
        ? '\nGeliştirme sertifikasına güvenilmiyor. Çözüm: `dotnet dev-certs https --trust` veya '
            '`--dart-define=ALLOW_BAD_SSL=true` (yalnızca dev) ile tekrar başlatın.'
        : '';
    return 'Sunucu sertifikası doğrulanamadı.$hint';
  }

  // 4) Web (Flutter Chrome) — XMLHttpRequest / connection error
  if (kIsWeb &&
      (lower.contains('xmlhttprequest') ||
          e.type == DioExceptionType.connectionError ||
          (e.response == null && lower.contains('error')))) {
    final lines = <String>[
      'Tarayıcıdan API\'ye bağlanılamadı.',
      'Hedef: $base',
      '',
      'Olası nedenler:',
      '• API sunucusu kapalı veya yanlış portta',
    ];
    if (isHttps) {
      lines.add(
          '• HTTPS sertifikası tarayıcıda güvenli değil — bir kez API URL\'sini doğrudan tarayıcıda açıp "Devam et"e basın');
      lines.add(
          '• `dotnet dev-certs https --trust` (Windows) ile dev sertifikasını sisteme ekleyin');
    }
    lines.add(
        '• CORS: API\'nin geliştirme portunuza (örn. http://localhost:53852) izin vermesi gerekir');
    lines.add(
        '• En kolay test: Android emülatörde `--dart-define=API_BASE_URL=http://10.0.2.2:5041` (CORS yok)');
    return lines.join('\n');
  }

  // 5) HTTP status code'lu cevap (4xx/5xx)
  final status = e.response?.statusCode;
  if (status != null) {
    if (status == 401) return 'Oturum gerekli veya süresi doldu. Lütfen tekrar giriş yapın.';
    if (status == 403) return 'Bu işlem için yetkiniz yok.';
    if (status == 404) return 'İstenen kaynak bulunamadı.';
    if (status == 422) return raw; // backend'den anlamlı doğrulama mesajı geleceği için
    if (status >= 500) return 'Sunucu hatası ($status). Lütfen daha sonra tekrar deneyin.';
  }

  return raw;
}
