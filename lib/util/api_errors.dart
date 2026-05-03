import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

String dioErrorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    if (data is String) {
      try {
        final j = jsonDecode(data) as Map<String, dynamic>;
        return j['message']?.toString() ?? e.message ?? e.toString();
      } catch (_) {}
    }
    final msg = e.message ?? e.toString();
    if (kIsWeb &&
        (msg.contains('XMLHttpRequest') ||
            e.type == DioExceptionType.connectionError)) {
      return '$msg\n\n'
          'Tarayıcıda (Flutter Web) çalışıyorsunuz: API sunucusu isteğinizi CORS ile kabul etmeli. '
          'CallCenter.Api güncel ise localhost üzerindeki Flutter Web portuna izin verilir; API’yi yeniden başlatın. '
          'Kalıcı çözüm: Android/iOS emülatör veya gerçek cihazda çalıştırmak (CORS gerekmez).';
    }
    return msg;
  }
  return e.toString();
}
