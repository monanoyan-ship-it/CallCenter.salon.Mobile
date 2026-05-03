double _money(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

double _parseDouble0(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

double? _parseDoubleNullable(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// `GET /api/salon` — CallCenter.Salon Discover ile aynı kaynak; her satır bir şube, slug randevu profili.
class PublishedBranchItem {
  PublishedBranchItem({
    required this.slug,
    required this.salonName,
    required this.branchName,
    required this.isHeadquarter,
    this.city,
    this.district,
    this.logoUrl,
    this.description,
    this.latitude,
    this.longitude,
    required this.averageRating,
    required this.reviewCount,
    this.priceRange,
  });

  final String slug;
  final String salonName;
  final String branchName;
  final bool isHeadquarter;
  final String? city;
  final String? district;
  final String? logoUrl;
  final String? description;
  final double? latitude;
  final double? longitude;
  final double averageRating;
  final int reviewCount;
  final String? priceRange;

  /// Web Discover: branchName || salonName
  String get displayTitle {
    final b = branchName.trim();
    if (b.isNotEmpty) return b;
    return salonName;
  }

  bool get showSalonSubtitle {
    final b = branchName.trim();
    return b.isNotEmpty && salonName.isNotEmpty && b != salonName;
  }

  factory PublishedBranchItem.fromJson(Map<String, dynamic> json) {
    return PublishedBranchItem(
      slug: json['slug'] as String? ?? '',
      salonName: json['salonName'] as String? ?? '',
      branchName: json['branchName'] as String? ?? '',
      isHeadquarter: json['isHeadquarter'] as bool? ?? false,
      city: json['city'] as String?,
      district: json['district'] as String?,
      logoUrl: json['logoUrl'] as String?,
      description: json['description'] as String?,
      latitude: _parseDoubleNullable(json['latitude']),
      longitude: _parseDoubleNullable(json['longitude']),
      averageRating: _parseDouble0(json['averageRating']),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      priceRange: json['priceRange'] as String?,
    );
  }
}

/// `GET /api/salon/branches-map` — harita pinleri.
class PublishedBranchMapPin {
  PublishedBranchMapPin({
    required this.slug,
    required this.salonName,
    required this.branchName,
    required this.isHeadquarter,
    this.city,
    this.district,
    required this.latitude,
    required this.longitude,
  });

  final String slug;
  final String salonName;
  final String branchName;
  final bool isHeadquarter;
  final String? city;
  final String? district;
  final double latitude;
  final double longitude;

  factory PublishedBranchMapPin.fromJson(Map<String, dynamic> json) {
    return PublishedBranchMapPin(
      slug: json['slug'] as String? ?? '',
      salonName: json['salonName'] as String? ?? '',
      branchName: json['branchName'] as String? ?? '',
      isHeadquarter: json['isHeadquarter'] as bool? ?? false,
      city: json['city'] as String?,
      district: json['district'] as String?,
      latitude: _parseDoubleNullable(json['latitude']) ?? 0,
      longitude: _parseDoubleNullable(json['longitude']) ?? 0,
    );
  }
}

/// `GET /api/platform/salons` — üye olunan salonlar.
class PlatformJoinedSalon {
  PlatformJoinedSalon({
    required this.id,
    required this.customerId,
    required this.salonName,
    required this.isFavorite,
    required this.joinedAt,
    this.logoUrl,
    this.city,
    this.district,
  });

  final int id;
  final int customerId;
  final String salonName;
  final String? logoUrl;
  final String? city;
  final String? district;
  final bool isFavorite;
  final DateTime joinedAt;

  factory PlatformJoinedSalon.fromJson(Map<String, dynamic> json) {
    final ja = json['joinedAt'];
    return PlatformJoinedSalon(
      id: json['id'] as int,
      customerId: json['customerId'] as int,
      salonName: json['salonName'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
      city: json['city'] as String?,
      district: json['district'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      joinedAt: ja != null ? DateTime.tryParse(ja.toString()) ?? DateTime.utc(1970) : DateTime.utc(1970),
    );
  }
}

/// `GET /api/platform/discover`
class DiscoverSalonItem {
  DiscoverSalonItem({
    required this.customerId,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.city,
    this.district,
    this.description,
  });

  final int customerId;
  final String name;
  final String slug;
  final String? logoUrl;
  final String? city;
  final String? district;
  final String? description;

  factory DiscoverSalonItem.fromJson(Map<String, dynamic> json) {
    return DiscoverSalonItem(
      customerId: json['customerId'] as int,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
      city: json['city'] as String?,
      district: json['district'] as String?,
      description: json['description'] as String?,
    );
  }
}

class DiscoverSalonsResult {
  DiscoverSalonsResult({required this.total, required this.page, required this.salons});

  final int total;
  final int page;
  final List<DiscoverSalonItem> salons;

  factory DiscoverSalonsResult.fromJson(Map<String, dynamic> json) {
    final raw = json['salons'] as List<dynamic>? ?? [];
    return DiscoverSalonsResult(
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      salons: raw.map((e) => DiscoverSalonItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// `GET /api/platform/me`
class PlatformProfileFull {
  PlatformProfileFull({
    required this.fullName,
    required this.phone,
    this.email,
    this.avatarUrl,
    this.salonCount = 0,
    this.billingType = 1,
    this.billingFullName,
    this.billingCompanyName,
    this.billingTaxOffice,
    this.billingTaxNumber,
    this.billingAddress,
    this.billingCity,
    this.billingDistrict,
    this.billingPostalCode,
  });

  final String fullName;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final int salonCount;
  final int billingType;
  final String? billingFullName;
  final String? billingCompanyName;
  final String? billingTaxOffice;
  final String? billingTaxNumber;
  final String? billingAddress;
  final String? billingCity;
  final String? billingDistrict;
  final String? billingPostalCode;

  factory PlatformProfileFull.fromJson(Map<String, dynamic> json) {
    return PlatformProfileFull(
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      salonCount: json['salonCount'] as int? ?? 0,
      billingType: json['billingType'] as int? ?? 1,
      billingFullName: json['billingFullName'] as String?,
      billingCompanyName: json['billingCompanyName'] as String?,
      billingTaxOffice: json['billingTaxOffice'] as String?,
      billingTaxNumber: json['billingTaxNumber'] as String?,
      billingAddress: json['billingAddress'] as String?,
      billingCity: json['billingCity'] as String?,
      billingDistrict: json['billingDistrict'] as String?,
      billingPostalCode: json['billingPostalCode'] as String?,
    );
  }
}

/// `GET /api/platform/loyalty`
class PlatformLoyaltyEntry {
  PlatformLoyaltyEntry({
    required this.salonName,
    required this.currentPoints,
    required this.totalEarned,
    this.membershipPlanName,
    this.membershipDiscount,
    this.giftCards = const [],
  });

  final String salonName;
  final double currentPoints;
  final double totalEarned;
  final String? membershipPlanName;
  final double? membershipDiscount;
  final List<PlatformGiftCardRow> giftCards;

  factory PlatformLoyaltyEntry.fromJson(Map<String, dynamic> json) {
    final gc = json['giftCards'] as List<dynamic>? ?? [];
    return PlatformLoyaltyEntry(
      salonName: json['salonName'] as String? ?? '',
      currentPoints: _money(json['currentPoints']),
      totalEarned: _money(json['totalEarned']),
      membershipPlanName: json['membershipPlanName'] as String?,
      membershipDiscount: json['membershipDiscount'] != null ? _money(json['membershipDiscount']) : null,
      giftCards: gc.map((e) => PlatformGiftCardRow.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class PlatformGiftCardRow {
  PlatformGiftCardRow({
    required this.code,
    required this.remainingBalance,
    required this.originalAmount,
    required this.isActive,
  });

  final String code;
  final double remainingBalance;
  final double originalAmount;
  final bool isActive;

  factory PlatformGiftCardRow.fromJson(Map<String, dynamic> json) {
    return PlatformGiftCardRow(
      code: json['code'] as String? ?? '',
      remainingBalance: _money(json['remainingBalance']),
      originalAmount: _money(json['originalAmount']),
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}
