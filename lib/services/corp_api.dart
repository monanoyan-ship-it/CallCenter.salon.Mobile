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

  Future<SalonProfile> fetchSalonProfile(String slug) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/salon/$slug');
    final data = res.data;
    if (data == null) throw StateError('Boş yanıt');
    return SalonProfile.fromJson(data);
  }

  /// Web Discover ile aynı: `GET /api/salon` — yayında şubeler (SlnPublicController.GetAllPublished).
  Future<List<PublishedBranchItem>> fetchPublishedBranches() async {
    final res = await _dio.get<List<dynamic>>('/api/salon');
    final raw = res.data ?? [];
    return raw.map((e) => PublishedBranchItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Harita pinleri: `GET /api/salon/branches-map`
  Future<List<PublishedBranchMapPin>> fetchBranchesMapPins() async {
    final res = await _dio.get<List<dynamic>>('/api/salon/branches-map');
    final raw = res.data ?? [];
    return raw.map((e) => PublishedBranchMapPin.fromJson(e as Map<String, dynamic>)).toList();
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
