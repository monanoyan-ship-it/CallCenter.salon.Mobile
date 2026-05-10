import 'package:flutter/foundation.dart';

/// API tabanı. **`--dart-define=API_BASE_URL=...` her zaman bunun üzerine yazar** — şema ve port senin API ayarına göre olmalı.
///
/// **CallCenter.Api `launchSettings.json`:**
/// - `http` profili → `http://localhost:5041`
/// - `https` profili → **`https://localhost:7147`** (aynı anda genelde 5041 HTTP de açık kalır; hangisiyle çalışıyorsan onu yaz).
///
/// **Flutter Web + Chrome** (`flutter run -d chrome --web-port=53852`):
/// Örnek: `flutter run -d chrome --web-port=53852 --dart-define=API_BASE_URL=https://localhost:7147`
/// Geliştirme sertifikasına güvenmiyorsan önce `dotnet dev-certs https --trust` (Windows).
/// Web'de TLS tarayıcıdadır; `ALLOW_BAD_SSL` yalnızca mobil/masaüstü IO istemcisinde kullanılır.
///
/// **Android emülatör** (CORS yok; Keşfet için genelde en kolay yerel test):
/// Örnek: `flutter run -d emulator --dart-define=API_BASE_URL=http://10.0.2.2:5041`
/// API’yi yalnız HTTPS ile dinliyorsan emülatörden `https://10.0.2.2:7147` denenebilir; localhost sertifikası ile hostname uyumsuzluğu olursa pratikte çoğu ekip **HTTP 5041** ile geliştirir veya gerçek cihaz + LAN IP kullanır.
///
/// **Port:** Bu uygulama yerelde dinleyici değildir; tek sabit adres, buraya giden **`API_BASE_URL`** tabanıdır.
///
/// Platform varsayılanları (`API_BASE_URL` verilmezse):
/// - **Web:** `http://localhost:5041`
/// - **Android:** `http://10.0.2.2:5041`
/// - **Diğer:** `http://localhost:5041`
class AppConfig {
  AppConfig._();

  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv.trimRight();
    if (kIsWeb) return 'http://localhost:5041';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:5041';
      default:
        return 'http://localhost:5041';
    }
  }

  /// Yerel geliştirmede boş self-signed sertifikayı kabul et (yalnızca HTTPS test için).
  static const bool allowBadSsl = bool.fromEnvironment(
    'ALLOW_BAD_SSL',
    defaultValue: false,
  );

  /// Harita döşeme (tile) URL kalıbı. Varsayılan OSM yalnızca **geliştirme**
  /// içindir; mağaza yayınında OSM Foundation kullanım politikasına aykırıdır.
  /// Production için Mapbox/MapTiler/Stadia/Carto vs. ile değiştir:
  /// `--dart-define=MAP_TILE_URL=https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=YOUR_KEY`
  static const String mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  /// Bazı sağlayıcıların atıf metni gerektirir (ör. Mapbox); UI altına yazılır.
  /// Default OSM atıfı: '© OpenStreetMap'.
  static const String mapTileAttribution = String.fromEnvironment(
    'MAP_TILE_ATTRIBUTION',
    defaultValue: '© OpenStreetMap',
  );

  /// User-Agent başlığı (OSM ve diğer sağlayıcılar için bot/abuse takibi).
  static const String mapTileUserAgent = String.fromEnvironment(
    'MAP_TILE_USER_AGENT',
    defaultValue: 'com.corplynk.salon.callcenter_salon_mobil',
  );

  /// Sentry DSN — boşsa Sentry hiç başlatılmaz (dev varsayılanı).
  /// Prod build: `--dart-define=SENTRY_DSN=https://abc@oXXX.ingest.sentry.io/YYY`
  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  /// Sentry trace örnekleme oranı (0.0–1.0). Performans monitoring için.
  /// Dart `double.fromEnvironment` desteklemediğinden string olarak verilir.
  static const String _sentryTracesSampleRateStr = String.fromEnvironment(
    'SENTRY_TRACES_SAMPLE_RATE',
    defaultValue: '0.1',
  );
  static double get sentryTracesSampleRate =>
      double.tryParse(_sentryTracesSampleRateStr) ?? 0.1;

  /// Sentry environment etiketi: dev / staging / prod.
  static const String sentryEnvironment = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: 'dev',
  );
}
