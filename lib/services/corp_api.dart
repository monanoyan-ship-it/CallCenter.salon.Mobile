import 'dart:io';

import 'package:callcenter_salon_mobil/config/app_config.dart';
import 'package:callcenter_salon_mobil/models/booking_models.dart';
import 'package:callcenter_salon_mobil/models/platform_models.dart';
import 'package:callcenter_salon_mobil/util/api_errors.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

typedef AuthHeaderGetter = String? Function();
typedef UnauthorizedCallback = void Function();

/// CallCenter.Api ile doğrudan konuşur (Salon MVC proxy kullanılmaz).
///
/// Kimlik doğrulamalı uçların çoğu **platform müşterisi** (`PlatformUser`) içindir;
/// salon işletme paneli cookie/JWT’si bu istemicide yoktur.
class CorpApiClient {
  CorpApiClient({AuthHeaderGetter? getBearer, UnauthorizedCallback? onUnauthorized})
      : _getBearer = getBearer,
        _onUnauthorized = onUnauthorized {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl.trimRight(),
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 35),
        sendTimeout: const Duration(seconds: 35),
        headers: {'Accept': 'application/json'},
      ),
    );

    if (AppConfig.allowBadSsl && _dio.httpClientAdapter is IOHttpClientAdapter) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final c = HttpClient();
        c.badCertificateCallback = (cert, host, port) => true;
        return c;
      };
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final t = _getBearer?.call();
          if (t != null && t.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $t';
          }
          handler.next(options);
        },
        onError: (err, handler) {
          final code = err.response?.statusCode;
          final sent = err.requestOptions.headers['Authorization'];
          if (code == 401 && sent != null) {
            final cb = _onUnauthorized;
            if (cb != null) cb();
          }
          handler.next(err);
        },
      ),
    );
  }

  late final Dio _dio;
  final AuthHeaderGetter? _getBearer;
  final UnauthorizedCallback? _onUnauthorized;

  /// Discover ekranı gibi pahalı public listeler için bellek cache.
  /// Network hatası halinde son başarılı yanıt döner (TTL içindeyse).
  final Map<String, _CacheEntry> _cache = {};

  Future<T> _cachedGet<T>(
    String cacheKey,
    Duration ttl,
    Future<T> Function() request,
  ) async {
    try {
      final result = await request();
      _cache[cacheKey] = _CacheEntry(result, DateTime.now());
      return result;
    } catch (e) {
      final hit = _cache[cacheKey];
      if (hit != null && DateTime.now().difference(hit.savedAt) < ttl) {
        return hit.value as T;
      }
      rethrow;
    }
  }

  Future<SalonProfile> fetchSalonProfile(String slug) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/salon/$slug');
    final data = res.data;
    if (data == null) throw StateError('Boş yanıt');
    return SalonProfile.fromJson(data);
  }

  /// Web Discover ile aynı: `GET /api/salon` — yayında şubeler (SlnPublicController.GetAllPublished).
  /// Network hatasında 5 dakika içindeki son başarılı yanıt döner.
  Future<List<PublishedBranchItem>> fetchPublishedBranches() async {
    return _cachedGet('salon-list', const Duration(minutes: 5), () async {
      final res = await _dio.get<List<dynamic>>('/api/salon');
      final raw = res.data ?? [];
      return raw.map((e) => PublishedBranchItem.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  /// Harita pinleri: `GET /api/salon/branches-map`. 5 dakika cache.
  Future<List<PublishedBranchMapPin>> fetchBranchesMapPins() async {
    return _cachedGet('branches-map', const Duration(minutes: 5), () async {
      final res = await _dio.get<List<dynamic>>('/api/salon/branches-map');
      final raw = res.data ?? [];
      return raw.map((e) => PublishedBranchMapPin.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  /// Salon profil sayfası ekibi: `GET /api/salon/{slug}/team` (kimliksiz, public).
  Future<List<TeamMember>> fetchSalonTeam(String slug) async {
    final res = await _dio.get<List<dynamic>>('/api/salon/$slug/team');
    final raw = res.data ?? [];
    return raw.map((e) => TeamMember.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Onaylanmış müşteri yorumları + istatistik: `GET /api/salon/{slug}/reviews`.
  Future<ReviewsResponse> fetchSalonReviews(String slug) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/salon/$slug/reviews');
    final data = res.data;
    if (data == null) {
      return ReviewsResponse(
        reviews: const [],
        stats: SalonReviewStats(totalCount: 0, averageRating: 0),
      );
    }
    return ReviewsResponse.fromJson(data);
  }

  /// `POST /api/platform/reviews` — yorum yaz (PlatformUser auth).
  /// Aynı PlatformUser+Salon çiftinde mevcut yorum varsa update edilir;
  /// her durumda status=1 (Bekliyor) döner — admin onayı sonrası listede görünür.
  Future<PlatformReview> submitPlatformReview({
    required String slug,
    required int rating,
    String? comment,
    String? displayName,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/platform/reviews',
      data: {
        'salonSlug': slug,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
      },
    );
    final data = res.data;
    if (data == null) throw StateError('Boş yanıt');
    return PlatformReview.fromJson(data);
  }

  /// `GET /api/platform/reviews/me` — kullanıcının yazdığı tüm yorumlar.
  Future<List<PlatformReview>> fetchMyPlatformReviews() async {
    final res = await _dio.get<List<dynamic>>('/api/platform/reviews/me');
    final raw = res.data ?? [];
    return raw
        .map((e) => PlatformReview.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /api/platform/push-token` — FCM/APNs token kayıt (PlatformUser).
  /// `platform`: `'ios'`, `'android'` veya `'web'`. `deviceId` opsiyonel ama
  /// önerilen — backend aynı cihaza eski tokenları pasifleştirir.
  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? deviceId,
  }) async {
    await _dio.post<void>(
      '/api/platform/push-token',
      data: {
        'token': token,
        'platform': platform,
        if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      },
    );
  }

  /// `DELETE /api/platform/push-token?token=...` — logout veya cihaz çıkışı.
  Future<void> unregisterPushToken(String token) async {
    await _dio.delete<void>(
      '/api/platform/push-token',
      queryParameters: {'token': token},
    );
  }

  /// Salon üyelik planları: `GET /api/salon/{slug}/memberships`.
  Future<List<SalonMembership>> fetchSalonMemberships(String slug) async {
    final res = await _dio.get<List<dynamic>>('/api/salon/$slug/memberships');
    final raw = res.data ?? [];
    return raw.map((e) => SalonMembership.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Üyelik signup: `POST /api/salon/{slug}/membership-signup`. Ücretsiz planlar
  /// hemen onaylanır; ücretli planlar için `htmlContent` ödeme formu döner.
  Future<MembershipSignupResult> signupMembership({
    required String slug,
    required int planId,
    required String fullName,
    required String phone,
    String? email,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/salon/$slug/membership-signup',
      data: {
        'planId': planId,
        'fullName': fullName,
        'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    final data = res.data;
    if (data == null) throw StateError('Boş yanıt');
    return MembershipSignupResult.fromJson(data);
  }

  /// `POST /api/payments/membership-checkout` — ücretli üyelik için Iyzico
  /// checkout HTML formu. PlatformUser auth gerekir; signup'tan dönen
  /// slnClientId+planId ile çağrılır.
  Future<({String htmlContent, String? token})> payMembershipCheckout({
    required int planId,
    required int slnClientId,
    required String slug,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/payments/membership-checkout',
      data: {
        'planId': planId,
        'slnClientId': slnClientId,
        'slug': slug,
      },
    );
    final data = res.data;
    if (data == null) throw StateError('Boş yanıt');
    final ok = data['success'] as bool? ?? false;
    if (!ok) {
      throw StateError(data['error'] as String? ?? 'Ödeme başlatılamadı');
    }
    return (
      htmlContent: data['htmlContent'] as String? ?? '',
      token: data['token'] as String?,
    );
  }

  /// `GET /api/payments/history` — kullanıcının tüm ödeme kayıtları.
  Future<List<PaymentHistoryEntry>> fetchPaymentHistory() async {
    final res = await _dio.get<List<dynamic>>('/api/payments/history');
    final raw = res.data ?? [];
    return raw
        .map((e) => PaymentHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /api/payments/my-receipt/{uid}` — HTML makbuz (string).
  Future<String> fetchMyReceiptHtml(String uid) async {
    final res = await _dio.get<dynamic>(
      '/api/payments/my-receipt/$uid',
      options: Options(responseType: ResponseType.plain, headers: {
        'Accept': 'text/html',
      }),
    );
    final data = res.data;
    if (data is String) return data;
    return data?.toString() ?? '';
  }

  Future<BookingPolicy> fetchBookingPolicy(String slug) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/salon/$slug/booking-policy');
    final data = res.data;
    if (data == null) {
      return BookingPolicy(
        hasPolicy: false,
        requireDeposit: false,
        depositAmount: 0,
        freeCancellationHours: 0,
        noShowFee: 0,
      );
    }
    return BookingPolicy.fromJson(data);
  }

  Future<List<StaffMember>> fetchAvailableStaff(String slug, int serviceId) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/salon/$slug/available-staff',
      queryParameters: {'serviceId': serviceId},
    );
    final list = res.data ?? [];
    return list.map((e) => StaffMember.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<({bool isClosed, List<TimeSlot> slots})> fetchAvailableSlots({
    required String slug,
    required int serviceId,
    required DateTime date,
    int? personnelId,
  }) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final res = await _dio.get<dynamic>(
      '/api/salon/$slug/available-slots',
      queryParameters: <String, dynamic>{
        'serviceId': serviceId,
        'date': dateOnly.toIso8601String().split('T').first,
        if (personnelId != null) 'personnelId': personnelId,
      },
    );

    final raw = res.data;
    if (raw is List) {
      final slots = raw.map((e) => TimeSlot.fromJson(e as Map<String, dynamic>)).toList();
      return (isClosed: false, slots: slots);
    }
    if (raw is Map<String, dynamic>) {
      final closed = raw['isClosed'] as bool? ?? false;
      final slotList = raw['slots'] as List<dynamic>? ?? [];
      final slots = slotList.map((e) => TimeSlot.fromJson(e as Map<String, dynamic>)).toList();
      return (isClosed: closed, slots: slots);
    }
    return (isClosed: false, slots: <TimeSlot>[]);
  }

  Future<BookActionResult> bookSimple({
    required String slug,
    required Map<String, dynamic> body,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>('/api/salon/$slug/book', data: body);
    final data = res.data;
    if (data == null) throw StateError('Boş yanıt');
    return BookActionResult.fromJson(data);
  }

  Future<BookActionResult> bookCheckout({
    required String slug,
    required Map<String, dynamic> body,
  }) async {
    final res =
        await _dio.post<Map<String, dynamic>>('/api/salon/$slug/book-checkout', data: body);
    final data = res.data;
    if (data == null) throw StateError('Boş yanıt');
    return BookActionResult.fromJson(data);
  }

  Future<String?> joinWaitlist({
    required String slug,
    required Map<String, dynamic> body,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/api/salon/$slug/waitlist', data: body);
      final msg = res.data?['message'] as String?;
      return msg ?? 'Kayıt alındı.';
    } on DioException catch (e) {
      throw Exception(dioErrorMessage(e));
    }
  }

  Future<(String token, PlatformUser user)> platformLogin({
    required String phone,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/platform/login',
      data: {'phone': phone, 'password': password},
    );
    return _parsePlatformAuth(res.data);
  }

  /// `POST /api/platform/forgot-password` — sıfırlama maili istemini başlat.
  /// Backend her durumda 200 döner (hesap var/yok bilgisi sızdırılmaz).
  Future<void> platformForgotPassword({required String email}) async {
    await _dio.post<void>(
      '/api/platform/forgot-password',
      data: {'email': email},
    );
  }

  /// `POST /api/platform/reset-password` — emaildeki linkin token'ıyla yeni şifre.
  Future<void> platformResetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _dio.post<void>(
      '/api/platform/reset-password',
      data: {'token': token, 'newPassword': newPassword},
    );
  }

  /// `POST /api/platform/send-verification-email` — doğrulama mailini yeniden gönder.
  Future<void> platformSendVerificationEmail({required String email}) async {
    await _dio.post<void>(
      '/api/platform/send-verification-email',
      data: {'email': email},
    );
  }

  /// `GET /api/platform/verify-email?token=...` — token ile email doğrula.
  /// Mobile'ın çağırması nadir; çoğu kullanıcı email'deki linke tarayıcıda tıklar.
  Future<void> platformVerifyEmail({required String token}) async {
    await _dio.get<void>(
      '/api/platform/verify-email',
      queryParameters: {'token': token},
    );
  }

  Future<(String token, PlatformUser user)> platformRegister({
    required String fullName,
    required String phone,
    required String password,
    String? email,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/platform/register',
      data: {
        'fullName': fullName,
        'phone': phone,
        'password': password,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    return _parsePlatformAuth(res.data);
  }

  (String, PlatformUser) _parsePlatformAuth(Map<String, dynamic>? data) {
    if (data == null) throw StateError('Boş yanıt');
    final token = data['token'] as String?;
    final userMap = data['user'] as Map<String, dynamic>?;
    if (token == null || userMap == null) throw StateError('Geçersiz kimlik yanıtı');
    return (token, PlatformUser.fromJson(userMap));
  }

  Future<List<PlatformJoinedSalon>> fetchJoinedSalons() async {
    final res = await _dio.get<List<dynamic>>('/api/platform/salons');
    final list = res.data ?? [];
    return list.map((e) => PlatformJoinedSalon.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<bool> toggleSalonFavorite(int customerId) async {
    final res = await _dio.post<Map<String, dynamic>>('/api/platform/salons/$customerId/favorite');
    return res.data?['isFavorite'] as bool? ?? false;
  }

  Future<void> joinSalon({required int customerId}) async {
    await _dio.post<void>('/api/platform/salons/join', data: {'customerId': customerId});
  }

  Future<void> leaveSalon(int customerId) async {
    await _dio.delete<void>('/api/platform/salons/$customerId');
  }

  Future<List<PlatformLoyaltyEntry>> fetchPlatformLoyalty() async {
    final res = await _dio.get<List<dynamic>>('/api/platform/loyalty');
    final list = res.data ?? [];
    return list.map((e) => PlatformLoyaltyEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PlatformProfileFull> fetchPlatformProfile() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/platform/me');
    final data = res.data;
    if (data == null) throw StateError('Boş yanıt');
    return PlatformProfileFull.fromJson(data);
  }

  Future<void> updatePlatformProfile({String? fullName, String? email}) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['fullName'] = fullName;
    if (email != null) body['email'] = email;
    if (body.isEmpty) return;
    await _dio.put<void>('/api/platform/me', data: body);
  }

  Future<void> changePlatformPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.put<void>(
      '/api/platform/me/password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<void> updatePlatformBilling(Map<String, dynamic> body) async {
    await _dio.put<void>('/api/platform/billing-info', data: body);
  }

  /// Auth gerekmez (API AllowAnonymous).
  Future<DiscoverSalonsResult> discoverSalons({
    String? city,
    String? search,
    int page = 1,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/platform/discover',
      queryParameters: <String, dynamic>{
        'page': page,
        if (city != null && city.isNotEmpty) 'city': city,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final data = res.data;
    if (data == null) throw StateError('Boş yanıt');
    return DiscoverSalonsResult.fromJson(data);
  }

  Future<List<PlatformAppointment>> fetchMyAppointments({required bool past}) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/platform/appointments',
      queryParameters: {'past': past},
    );
    final list = res.data ?? [];
    return list.map((e) => PlatformAppointment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> cancelAppointment(int id) async {
    await _dio.delete<void>('/api/platform/appointments/$id');
  }
}

class _CacheEntry {
  _CacheEntry(this.value, this.savedAt);
  final Object? value;
  final DateTime savedAt;
}
