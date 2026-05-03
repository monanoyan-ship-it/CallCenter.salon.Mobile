class SalonProfile {
  SalonProfile({
    required this.salonName,
    required this.slug,
    required this.showBooking,
    required this.categories,
    this.logoUrl,
  });

  final String salonName;
  final String slug;
  final bool showBooking;
  final String? logoUrl;
  final List<ServiceCategory> categories;

  factory SalonProfile.fromJson(Map<String, dynamic> json) {
    final rawCats = json['serviceCategories'] as List<dynamic>? ?? [];
    return SalonProfile(
      salonName: json['salonName'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      showBooking: json['showBooking'] as bool? ?? true,
      logoUrl: json['logoUrl'] as String?,
      categories:
          rawCats.map((e) => ServiceCategory.fromJson(e as Map<String, dynamic>)).toList(),
    );
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
