import 'dart:convert';

/// Tek slug için tam profil yanıtı (`GET /api/salon/{slug}`).
///
/// Profil sayfası bu modelin tamamını kullanır; BookingWizard sadece
/// `salonName`, `slug`, `showBooking` ve `categories` alanlarına bakar.
class SalonProfile {
  SalonProfile({
    required this.salonName,
    required this.slug,
    required this.showBooking,
    required this.categories,
    this.logoUrl,
    this.id,
    this.customerId,
    this.branchName,
    this.isHeadquarter = false,
    this.description,
    this.coverImageUrl,
    this.faviconUrl,
    this.bannersJson,
    this.galleryImagesJson,
    this.workingHoursJson,
    this.sectionOrderJson,
    this.address,
    this.city,
    this.district,
    this.phone,
    this.email,
    this.website,
    this.instagramHandle,
    this.facebookUrl,
    this.googleMapsUrl,
    this.latitude,
    this.longitude,
    this.showBanners = true,
    this.showServices = true,
    this.showMemberships = true,
    this.showHours = true,
    this.showContact = true,
    this.showTeam = true,
    this.showReviews = true,
    this.showMap = true,
  });

  final String salonName;
  final String slug;
  final bool showBooking;
  final String? logoUrl;
  final List<ServiceCategory> categories;

  final int? id;
  final int? customerId;
  final String? branchName;
  final bool isHeadquarter;
  final String? description;
  final String? coverImageUrl;
  final String? faviconUrl;
  final String? bannersJson;
  final String? galleryImagesJson;
  final String? workingHoursJson;
  final String? sectionOrderJson;
  final String? address;
  final String? city;
  final String? district;
  final String? phone;
  final String? email;
  final String? website;
  final String? instagramHandle;
  final String? facebookUrl;
  final String? googleMapsUrl;
  final double? latitude;
  final double? longitude;
  final bool showBanners;
  final bool showServices;
  final bool showMemberships;
  final bool showHours;
  final bool showContact;
  final bool showTeam;
  final bool showReviews;
  final bool showMap;

  /// Şube adı doluysa onu, değilse salon adını döndür (web Discover ile aynı).
  String get displayTitle {
    final b = branchName?.trim() ?? '';
    if (b.isNotEmpty && !isHeadquarter) return b;
    return salonName;
  }

  factory SalonProfile.fromJson(Map<String, dynamic> json) {
    final rawCats = json['serviceCategories'] as List<dynamic>? ?? [];
    return SalonProfile(
      salonName: json['salonName'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      showBooking: json['showBooking'] as bool? ?? true,
      logoUrl: json['logoUrl'] as String?,
      categories:
          rawCats.map((e) => ServiceCategory.fromJson(e as Map<String, dynamic>)).toList(),
      id: json['id'] as int?,
      customerId: json['customerId'] as int?,
      branchName: json['branchName'] as String?,
      isHeadquarter: json['isHeadquarter'] as bool? ?? false,
      description: json['description'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      faviconUrl: json['faviconUrl'] as String?,
      bannersJson: json['bannersJson'] as String?,
      galleryImagesJson: json['galleryImagesJson'] as String?,
      workingHoursJson: json['workingHoursJson'] as String?,
      sectionOrderJson: json['sectionOrderJson'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      district: json['district'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      instagramHandle: json['instagramHandle'] as String?,
      facebookUrl: json['facebookUrl'] as String?,
      googleMapsUrl: json['googleMapsUrl'] as String?,
      latitude: _toNullableDouble(json['latitude']),
      longitude: _toNullableDouble(json['longitude']),
      showBanners: json['showBanners'] as bool? ?? true,
      showServices: json['showServices'] as bool? ?? true,
      showMemberships: json['showMemberships'] as bool? ?? true,
      showHours: json['showHours'] as bool? ?? true,
      showContact: json['showContact'] as bool? ?? true,
      showTeam: json['showTeam'] as bool? ?? true,
      showReviews: json['showReviews'] as bool? ?? true,
      showMap: json['showMap'] as bool? ?? true,
    );
  }

  static double? _toNullableDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

class ServiceCategory {
  ServiceCategory({
    required this.id,
    required this.name,
    required this.services,
    this.iconClass,
  });

  final int id;
  final String name;
  final String? iconClass;
  final List<SalonService> services;

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    final raw = json['services'] as List<dynamic>? ?? [];
    return ServiceCategory(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      iconClass: json['iconClass'] as String?,
      services: raw.map((e) => SalonService.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class SalonService {
  SalonService({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.price,
  });

  final int id;
  final String name;
  final int durationMinutes;
  final double price;

  factory SalonService.fromJson(Map<String, dynamic> json) {
    return SalonService(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      price: _toDouble(json['price']),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

class StaffMember {
  StaffMember({
    required this.id,
    required this.name,
    this.title,
    this.photoUrl,
    this.specialty,
  });

  final int id;
  final String name;
  final String? title;
  final String? photoUrl;
  final String? specialty;

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      title: json['title'] as String?,
      photoUrl: json['photoUrl'] as String?,
      specialty: json['specialty'] as String?,
    );
  }
}

class SlotStaffMini {
  SlotStaffMini({required this.id, required this.name, this.photoUrl, this.initials});

  final int id;
  final String name;
  final String? photoUrl;
  final String? initials;

  factory SlotStaffMini.fromJson(Map<String, dynamic> json) {
    return SlotStaffMini(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      initials: json['initials'] as String?,
    );
  }
}

class TimeSlot {
  TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.timeText,
    required this.availableStaff,
  });

  final String startTime;
  final String endTime;
  final String timeText;
  final List<SlotStaffMini> availableStaff;

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    final raw = json['availableStaff'] as List<dynamic>? ?? [];
    return TimeSlot(
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      timeText: json['timeText'] as String? ?? '',
      availableStaff:
          raw.map((e) => SlotStaffMini.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class BookingPolicy {
  BookingPolicy({
    required this.hasPolicy,
    required this.requireDeposit,
    required this.depositAmount,
    required this.freeCancellationHours,
    required this.noShowFee,
  });

  final bool hasPolicy;
  final bool requireDeposit;
  final double depositAmount;
  final int freeCancellationHours;
  final double noShowFee;

  factory BookingPolicy.fromJson(Map<String, dynamic> json) {
    return BookingPolicy(
      hasPolicy: json['hasPolicy'] as bool? ?? false,
      requireDeposit: json['requireDeposit'] as bool? ?? false,
      depositAmount: _toMoney(json['depositAmount']),
      freeCancellationHours: json['freeCancellationHours'] as int? ?? 0,
      noShowFee: _toMoney(json['noShowFee']),
    );
  }

  static double _toMoney(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

/// Randevu sonrası API yanıtı (`book` veya `book-checkout`).
class BookActionResult {
  BookActionResult({
    required this.success,
    this.message,
    this.requireDeposit,
    this.htmlContent,
    this.token,
  });

  final bool success;
  final String? message;
  final bool? requireDeposit;
  final String? htmlContent;
  final String? token;

  factory BookActionResult.fromJson(Map<String, dynamic> json) {
    return BookActionResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      requireDeposit: json['requireDeposit'] as bool?,
      htmlContent: json['htmlContent'] as String?,
      token: json['token'] as String?,
    );
  }
}

class PlatformUser {
  PlatformUser({required this.fullName, required this.phone, this.email});

  final String fullName;
  final String phone;
  final String? email;

  factory PlatformUser.fromJson(Map<String, dynamic> json) {
    return PlatformUser(
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
    );
  }
}

class PlatformAppointment {
  PlatformAppointment({
    required this.id,
    required this.salonName,
    required this.appointmentDate,
    required this.startLabel,
    required this.endLabel,
    required this.serviceNames,
    required this.totalPrice,
    required this.statusId,
    this.personnelName,
    this.salonLogoUrl,
    this.isPrepaid = false,
    this.prepaidAmount = 0,
  });

  final int id;
  final String salonName;
  final String? salonLogoUrl;
  final DateTime appointmentDate;
  final String startLabel;
  final String endLabel;
  final List<String> serviceNames;
  final double totalPrice;
  final int statusId;
  final String? personnelName;
  final bool isPrepaid;
  final double prepaidAmount;

  factory PlatformAppointment.fromJson(Map<String, dynamic> json) {
    final svc = json['serviceNames'] as List<dynamic>? ?? [];
    final dateRaw = json['appointmentDate'];
    DateTime date = DateTime.now();
    if (dateRaw is String) {
      date = DateTime.tryParse(dateRaw) ?? date;
    } else if (dateRaw != null) {
      date = DateTime.tryParse(dateRaw.toString()) ?? date;
    }

    return PlatformAppointment(
      id: json['id'] as int,
      salonName: json['salonName'] as String? ?? '',
      salonLogoUrl: json['salonLogoUrl'] as String?,
      appointmentDate: date,
      startLabel: json['startTime']?.toString() ?? '',
      endLabel: json['endTime']?.toString() ?? '',
      serviceNames: svc.map((e) => e.toString()).toList(),
      totalPrice: SalonService.fromJson({'price': json['totalPrice']}).price,
      statusId: json['statusId'] as int? ?? 0,
      personnelName: json['personnelName'] as String?,
      isPrepaid: json['isPrepaid'] as bool? ?? false,
      prepaidAmount: SalonService.fromJson({'price': json['prepaidAmount']}).price,
    );
  }
}

class SalonReview {
  SalonReview({
    required this.clientName,
    required this.rating,
    required this.comment,
    required this.sourceId,
    required this.createdAt,
  });

  final String clientName;
  final int rating;
  final String comment;
  final int sourceId;
  final DateTime createdAt;

  factory SalonReview.fromJson(Map<String, dynamic> json) {
    DateTime created = DateTime.now();
    final dt = json['createdAt'];
    if (dt is String) {
      created = DateTime.tryParse(dt) ?? created;
    } else if (dt != null) {
      created = DateTime.tryParse(dt.toString()) ?? created;
    }
    return SalonReview(
      clientName: json['clientName'] as String? ?? '',
      rating: json['rating'] as int? ?? 0,
      comment: json['comment'] as String? ?? '',
      sourceId: json['sourceId'] as int? ?? 0,
      createdAt: created,
    );
  }
}

class SalonReviewStats {
  SalonReviewStats({required this.totalCount, required this.averageRating});
  final int totalCount;
  final double averageRating;

  factory SalonReviewStats.fromJson(Map<String, dynamic> json) {
    final avg = json['averageRating'];
    return SalonReviewStats(
      totalCount: json['totalCount'] as int? ?? 0,
      averageRating: avg is num ? avg.toDouble() : double.tryParse('$avg') ?? 0,
    );
  }
}

class ReviewsResponse {
  ReviewsResponse({required this.reviews, required this.stats});
  final List<SalonReview> reviews;
  final SalonReviewStats stats;

  factory ReviewsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['reviews'] as List<dynamic>? ?? [];
    final stats = json['stats'] as Map<String, dynamic>?;
    return ReviewsResponse(
      reviews: raw.map((e) => SalonReview.fromJson(e as Map<String, dynamic>)).toList(),
      stats: stats != null
          ? SalonReviewStats.fromJson(stats)
          : SalonReviewStats(totalCount: 0, averageRating: 0),
    );
  }
}

/// `/api/salon/{slug}/team` yanıtı (kimliksiz; rezervasyon için
/// `StaffMember` modeli kullanılır).
class TeamMember {
  TeamMember({
    required this.name,
    this.title,
    this.specialty,
    this.photoUrl,
    this.roleId = 0,
    this.services = const <String>[],
  });

  final String name;
  final String? title;
  final String? specialty;
  final String? photoUrl;
  final int roleId;
  final List<String> services;

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    final svc = json['services'] as List<dynamic>? ?? [];
    return TeamMember(
      name: json['name'] as String? ?? '',
      title: json['title'] as String?,
      specialty: json['specialty'] as String?,
      photoUrl: json['photoUrl'] as String?,
      roleId: json['roleId'] as int? ?? 0,
      services: svc.map((e) => e.toString()).toList(),
    );
  }
}

class MembershipServiceDetail {
  MembershipServiceDetail({
    required this.serviceId,
    required this.serviceName,
    required this.freeCount,
    required this.discountPercent,
  });

  final int serviceId;
  final String serviceName;
  final int freeCount;
  final int discountPercent;

  factory MembershipServiceDetail.fromJson(Map<String, dynamic> json) {
    return MembershipServiceDetail(
      serviceId: json['serviceId'] as int? ?? 0,
      serviceName: json['serviceName'] as String? ?? '',
      freeCount: json['freeCount'] as int? ?? 0,
      discountPercent: json['discountPercent'] as int? ?? 0,
    );
  }
}

class SalonMembership {
  SalonMembership({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.iconClass,
    this.color,
    this.durationType = 0,
    this.durationDays = 0,
    this.monthlyPrice = 0,
    this.currency = 'TRY',
    this.taxIncluded = true,
    this.isSalonCustomerMembership = true,
    this.discountPercent = 0,
    this.priorityBooking = false,
    this.serviceDetails = const <MembershipServiceDetail>[],
  });

  final int id;
  final String name;
  final String? description;
  final String? iconClass;
  final String? color;
  final int durationType;
  final int durationDays;
  final double price;
  final double monthlyPrice;
  final String currency;
  final bool taxIncluded;
  final bool isSalonCustomerMembership;
  final int discountPercent;
  final bool priorityBooking;
  final List<MembershipServiceDetail> serviceDetails;

  factory SalonMembership.fromJson(Map<String, dynamic> json) {
    final raw = json['serviceDetails'] as List<dynamic>? ?? [];
    return SalonMembership(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      iconClass: json['iconClass'] as String?,
      color: json['color'] as String?,
      durationType: json['durationType'] as int? ?? 0,
      durationDays: json['durationDays'] as int? ?? 0,
      price: _toMoney(json['price']),
      monthlyPrice: _toMoney(json['monthlyPrice']),
      currency: json['currency'] as String? ?? 'TRY',
      taxIncluded: json['taxIncluded'] as bool? ?? true,
      isSalonCustomerMembership: json['isSalonCustomerMembership'] as bool? ?? true,
      discountPercent: json['discountPercent'] as int? ?? 0,
      priorityBooking: json['priorityBooking'] as bool? ?? false,
      serviceDetails: raw
          .map((e) => MembershipServiceDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static double _toMoney(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

class SalonBanner {
  SalonBanner({required this.url, this.caption, this.link});
  final String url;
  final String? caption;
  final String? link;

  factory SalonBanner.fromJson(Map<String, dynamic> json) {
    return SalonBanner(
      url: json['url'] as String? ?? '',
      caption: json['caption'] as String?,
      link: json['link'] as String?,
    );
  }
}

/// Tek günün çalışma bilgisi: web `Profile.cshtml` ile aynı sıra ve etiketler.
class WorkingHourEntry {
  WorkingHourEntry({
    required this.dayKey,
    required this.dayLabel,
    required this.hoursText,
    required this.isClosed,
    required this.isToday,
  });

  final String dayKey;
  final String dayLabel;
  final String hoursText;
  final bool isClosed;
  final bool isToday;
}

const List<String> _kWorkingHourDayOrder = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const Map<String, String> _kWorkingHourDayLabels = {
  'mon': 'Pazartesi',
  'tue': 'Salı',
  'wed': 'Çarşamba',
  'thu': 'Perşembe',
  'fri': 'Cuma',
  'sat': 'Cumartesi',
  'sun': 'Pazar',
};
const List<String> kSalonProfileSectionOrderDefault = [
  'banners',
  'gallery',
  'services',
  'memberships',
  'team',
  'reviews',
  'map',
];

/// `workingHoursJson` ham string'inden Pazartesi-Pazar sıralı liste üret.
List<WorkingHourEntry> parseWorkingHours(String? json, {String closedText = 'Kapalı'}) {
  Map<String, dynamic>? map;
  if (json != null && json.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) map = decoded;
    } catch (_) {}
  }
  final todayIdx = (DateTime.now().weekday - 1).clamp(0, 6);
  final out = <WorkingHourEntry>[];
  for (var i = 0; i < _kWorkingHourDayOrder.length; i++) {
    final key = _kWorkingHourDayOrder[i];
    final raw = map?[key];
    final value = (raw is String && raw.trim().isNotEmpty) ? raw.trim() : 'closed';
    final isClosed = value.toLowerCase() == 'closed';
    out.add(WorkingHourEntry(
      dayKey: key,
      dayLabel: _kWorkingHourDayLabels[key] ?? key,
      hoursText: isClosed ? closedText : value,
      isClosed: isClosed,
      isToday: i == todayIdx,
    ));
  }
  return out;
}

List<String> parseGalleryImages(String? json) {
  if (json == null || json.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    final list = <String>[];
    for (final item in decoded) {
      if (item is String && item.isNotEmpty) {
        list.add(item);
      } else if (item is Map<String, dynamic>) {
        final url = item['url'] as String?;
        if (url != null && url.isNotEmpty) list.add(url);
      }
    }
    return list;
  } catch (_) {
    return const [];
  }
}

List<SalonBanner> parseBanners(String? json) {
  if (json == null || json.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .where((m) => (m['url'] as String?)?.isNotEmpty == true)
        .map(SalonBanner.fromJson)
        .toList();
  } catch (_) {
    return const [];
  }
}

/// `POST /api/platform/reviews` yanıtı / `GET /me` öğesi.
/// Status: 1=Bekliyor, 2=Onaylandı, 3=Reddedildi.
class PlatformReview {
  PlatformReview({
    required this.id,
    required this.customerId,
    required this.salonName,
    required this.rating,
    required this.statusId,
    required this.createdAt,
    this.comment,
  });

  final int id;
  final int customerId;
  final String salonName;
  final int rating;
  final String? comment;
  final int statusId;
  final DateTime createdAt;

  bool get isPending => statusId == 1;
  bool get isApproved => statusId == 2;
  bool get isRejected => statusId == 3;

  String get statusLabel {
    switch (statusId) {
      case 1:
        return 'Onay bekliyor';
      case 2:
        return 'Onaylandı';
      case 3:
        return 'Reddedildi';
      default:
        return 'Bilinmiyor';
    }
  }

  factory PlatformReview.fromJson(Map<String, dynamic> json) {
    DateTime created = DateTime.now();
    final c = json['createdAt'];
    if (c is String) created = DateTime.tryParse(c) ?? created;
    return PlatformReview(
      id: json['id'] as int? ?? 0,
      customerId: json['customerId'] as int? ?? 0,
      salonName: json['salonName'] as String? ?? '',
      rating: json['rating'] as int? ?? 0,
      comment: json['comment'] as String?,
      statusId: json['statusId'] as int? ?? 0,
      createdAt: created,
    );
  }
}

/// `POST /api/salon/{slug}/membership-signup` yanıtı.
class MembershipSignupResult {
  MembershipSignupResult({
    required this.success,
    required this.requiresPayment,
    this.slnClientId,
    this.planId,
    this.amount,
    this.message,
    this.htmlContent,
  });

  final bool success;
  final bool requiresPayment;
  final int? slnClientId;
  final int? planId;
  final double? amount;
  final String? message;

  /// Ücretli plan için ödeme HTML'i (3D secure form). Mobilde
  /// `payment_webview_page` ile yüklenir.
  final String? htmlContent;

  factory MembershipSignupResult.fromJson(Map<String, dynamic> json) {
    final amt = json['amount'];
    return MembershipSignupResult(
      success: json['success'] as bool? ?? false,
      requiresPayment: json['requiresPayment'] as bool? ?? false,
      slnClientId: json['slnClientId'] as int?,
      planId: json['planId'] as int?,
      amount: amt is num ? amt.toDouble() : double.tryParse('$amt'),
      message: json['message'] as String?,
      htmlContent: json['htmlContent'] as String?,
    );
  }
}

/// `GET /api/payments/history` — kullanıcının tüm ödeme kayıtları.
class PaymentHistoryEntry {
  PaymentHistoryEntry({
    required this.uid,
    required this.paymentTypeId,
    required this.paymentType,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.canDownloadReceipt,
    this.completedAt,
  });

  final String uid;
  final int paymentTypeId;
  final String paymentType;
  final double amount;
  final String currency;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool canDownloadReceipt;

  factory PaymentHistoryEntry.fromJson(Map<String, dynamic> json) {
    DateTime created = DateTime.now();
    final c = json['createdAt'];
    if (c is String) created = DateTime.tryParse(c) ?? created;
    DateTime? completed;
    final cm = json['completedAt'];
    if (cm is String && cm.isNotEmpty) completed = DateTime.tryParse(cm);

    final amt = json['amount'];
    return PaymentHistoryEntry(
      uid: json['uid']?.toString() ?? '',
      paymentTypeId: json['paymentTypeId'] as int? ?? 0,
      paymentType: json['paymentType'] as String? ?? '',
      amount: amt is num ? amt.toDouble() : double.tryParse('$amt') ?? 0,
      currency: json['currency'] as String? ?? 'TRY',
      status: json['status'] as String? ?? '',
      createdAt: created,
      completedAt: completed,
      canDownloadReceipt: json['canDownloadReceipt'] as bool? ?? false,
    );
  }
}

/// `sectionOrderJson` veya null → web ile aynı varsayılan sıra. Geçersiz/eksik
/// anahtarlar atılır, varsayılandaki ek bölümler sona eklenir.
List<String> parseSectionOrder(String? json) {
  if (json == null || json.trim().isEmpty) {
    return List.of(kSalonProfileSectionOrderDefault);
  }
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return List.of(kSalonProfileSectionOrderDefault);
    final saved = decoded
        .whereType<String>()
        .where(kSalonProfileSectionOrderDefault.contains)
        .toList();
    for (final key in kSalonProfileSectionOrderDefault) {
      if (!saved.contains(key)) saved.add(key);
    }
    return saved;
  } catch (_) {
    return List.of(kSalonProfileSectionOrderDefault);
  }
}
