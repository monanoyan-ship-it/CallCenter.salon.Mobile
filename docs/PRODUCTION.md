# Production hazırlık — callcenter_salon_mobil

Yayına almadan önce tamamlanması gereken konfigürasyon ve hesap aksiyonları.
Kod tarafı hazır; aşağıdaki maddeler **sen sağlamadan** mobil mağaza yayınına çıkamaz.

## 1. Harita döşeme (tile) sağlayıcı — ZORUNLU

OpenStreetMap Foundation'ın public tile sunucuları **mağaza yayınında yasak**:
<https://operations.osmfoundation.org/policies/tiles>

Üç pratik seçenek:

| Sağlayıcı | Ücretsiz kademe | Hız | Türkçe etiket |
|---|---|---|---|
| **MapTiler** | 100k tile/ay | Hızlı | İyi |
| **Mapbox** | 50k load/ay | Hızlı | İyi |
| **Stadia / Carto** | Sınırlı | Orta | Sınırlı |

Kurulum:
1. Sağlayıcıdan API key al
2. `--dart-define=MAP_TILE_URL=https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=XYZ` ile build et
3. `--dart-define=MAP_TILE_ATTRIBUTION='© MapTiler © OpenStreetMap'`

Build:
```powershell
.\scripts\build.ps1 -Target apk -Env prod `
  -MapTileUrl 'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=YOUR_KEY' `
  -MapTileAttribution '© MapTiler © OpenStreetMap'
```

## 2. Production API URL — ZORUNLU

`scripts/build.ps1` içinde `prod.ApiUrl` varsayılanı `https://api.corplynk.com`. Gerçek prod domainine güncelle (kendi alan adın).

## 3. App icon ve splash — ZORUNLU

```yaml
# pubspec.yaml dev_dependencies
flutter_launcher_icons: ^0.14.0
flutter_native_splash: ^2.4.0
```

`assets/icon/icon.png` (1024x1024) ekle, sonra:
```powershell
flutter pub get
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create
```

## 4. Android signing — ZORUNLU

```powershell
keytool -genkey -v -keystore android/app/upload-keystore.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`android/key.properties` (gitignore'a ekle):
```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=upload-keystore.jks
```

`android/app/build.gradle` `signingConfigs` block'u (Flutter şablonu doc):
<https://docs.flutter.dev/deployment/android#signing-the-app>

Android 11+ package visibility (manifest):
```xml
<queries>
  <intent><action android:name="android.intent.action.DIAL"/></intent>
  <intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="mailto"/></intent>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
</queries>
```

## 5. iOS signing + Info.plist — ZORUNLU

- Apple Developer hesabı (yıllık $99)
- Xcode → Runner target → Signing & Capabilities → Team seç
- `ios/Runner/Info.plist` ek:
  ```xml
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>Yakındaki salonları haritada gösterebilmek için konumunuza erişiyoruz.</string>
  <key>LSApplicationQueriesSchemes</key>
  <array>
    <string>tel</string>
    <string>mailto</string>
    <string>https</string>
  </array>
  ```

## 6. Mağaza listing — ZORUNLU

### Google Play
- Geliştirici hesabı ($25 tek seferlik)
- Privacy policy URL (KVKK + Google'ın istediği)
- Screenshot (telefon: en az 2, tablet: opsiyonel)
- Feature graphic 1024x500
- Açıklama (kısa 80 + uzun 4000)
- İçerik derecelendirme anketi

### App Store
- App Store Connect kayıt
- Privacy policy URL + Privacy nutrition label (App Privacy Details)
- Screenshot her cihaz boyutu için
- App icon 1024x1024 (alpha kanalsız)
- Description, keywords, support URL

## 7. Deep linking — platform manifest konfigürasyonu

Flutter tarafı (`lib/services/deep_link_handler.dart`) hazır. Native manifest
güncellemeleri yapılmazsa OS deep link'i yakalamaz.

### Custom scheme (`corplynk-salon://`)

Yakalanan URI desenleri:
- `corplynk-salon://salon/{slug}` → SalonProfilePage
- `corplynk-salon://reset-password?token=...` → ResetPasswordPage

**Android** — `android/app/src/main/AndroidManifest.xml`, `<activity android:name=".MainActivity">` içine:
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="corplynk-salon" />
</intent-filter>
```

**iOS** — `ios/Runner/Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key><string>com.corplynk.salon</string>
    <key>CFBundleURLSchemes</key><array><string>corplynk-salon</string></array>
  </dict>
</array>
```

### Universal/App Links (`https://*.corplynk.com/...`)

Yakalanan path desenleri:
- `/salon/{slug}` → SalonProfilePage
- `/reset-password?token=...` → ResetPasswordPage

> **Not:** Backend şifre sıfırlama maili web sayfasına yönlendiriyorsa, mobil tarafında deep link tetiklenmez — kullanıcı mailde linki açar, web reset sayfasında işlemi tamamlar. Mobil-içi reset için backend'e mailing template'inde `corplynk-salon://reset-password?token=...` veya doğrulanmış `https://*.corplynk.com/reset-password?token=...` URI'sini gömülü hale getirmesi gerekir.

Senin domain'i sahip olduğunu ima eder; her domain için ayrı dosya host'la.

**Android** — manifest'e ek intent-filter (`autoVerify`):
```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="corplynk.com" android:pathPrefix="/salon/" />
</intent-filter>
```
Domain'de `https://corplynk.com/.well-known/assetlinks.json` host'la (Android paket adın + SHA-256 imza fingerprint'i).

**iOS** — Xcode → Runner → Signing & Capabilities → **+ Associated Domains** → `applinks:corplynk.com`. Domain'de `https://corplynk.com/.well-known/apple-app-site-association` host'la (App ID + path patterns).

Doğrulama araçları:
- Android: `adb shell pm verify-app-links --re-verify <package>`
- iOS: <https://branch.io/resources/aasa-validator>

## 8. Push notification kurulumu (Phase 6)

Backend tarafı hazır:
- `POST /api/platform/push-token` — token kaydet/güncelle
- `DELETE /api/platform/push-token?token=...` — pasifleştir
- `GET /api/platform/push-token` — aktif tokenlar (cihazlarım)

Mobile API client metodları (`CorpApiClient.registerPushToken` / `unregisterPushToken`)
hazır. Eksik olan: **Firebase projesi + firebase_messaging entegrasyonu**.

### 8a. Firebase projesi

1. <https://console.firebase.google.com/> → yeni proje (`corplynk-salon`)
2. Android app ekle: package name = `com.corplynk.salon.callcenter_salon_mobil`
   - SHA-1: `keytool -list -v -keystore upload-keystore.jks -alias upload`
   - `google-services.json` indir → `android/app/`
3. iOS app ekle: bundle ID = `com.corplynk.salon.callcenterSalonMobil`
   - `GoogleService-Info.plist` indir → `ios/Runner/`
4. **Cloud Messaging API (HTTP v1)** etkinleştir
5. **APNs auth key** yükle (Apple Developer'dan alınır) — iOS push için zorunlu

### 8b. Flutter paketleri

```yaml
dependencies:
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3
```

`flutter pub get`, sonra:
- Android: `android/build.gradle`'a Google Services classpath
- Android: `android/app/build.gradle`'a `apply plugin: 'com.google.gms.google-services'`
- iOS: `ios/Runner/AppDelegate.swift`'e `FirebaseApp.configure()`

### 8c. Token register entegrasyonu

`main.dart` veya `SessionState.signIn()` sonrası:

```dart
final token = await FirebaseMessaging.instance.getToken();
if (token != null) {
  final platform = Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : 'web';
  final deviceId = (await DeviceInfoPlugin().androidInfo).id; // Android örneği
  await api.registerPushToken(token: token, platform: platform, deviceId: deviceId);
}

FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
  api.registerPushToken(token: newToken, platform: platform, deviceId: deviceId);
});
```

`SessionState.signOut()` öncesi:

```dart
if (lastFcmToken != null) {
  await api.unregisterPushToken(lastFcmToken).catchError((_) {});
}
```

### 8d. Backend FCM gönderim (eksik)

Backend commit notunda: *"Eksik (sonraki seans): IPushNotificationService interface
+ FCM HTTP v1 implementasyonu (servis hesabı credential'ı, JWT signing, gerçek
push gönderim)."* — yani token kaydı çalışıyor ama **push gönderim henüz yok**.
Backend ekibi bu kısmı tamamlayınca uygulama bildirim alabilir hale gelir.

## 9. Backend hâlâ eksik

- **Push gönderim servisi** (yukarıda 8d)
- **In-app notification listesi** (`GET /api/platform/notifications`) — kullanıcının geçmiş bildirimlerini göstermek için
