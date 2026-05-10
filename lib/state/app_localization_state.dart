import 'dart:async';
import 'dart:convert';

import 'package:callcenter_salon_mobil/models/localization_models.dart';
import 'package:callcenter_salon_mobil/services/corp_api.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

class AppLocalizationState extends ChangeNotifier {
  AppLocalizationState() {
    unawaited(loadCached());
  }

  static const _module = 'salon';
  static const _kLocale = 'i18n_locale';
  static const _kLanguagesJson = 'i18n_languages_json';
  static const _kLanguagesEtag = 'i18n_languages_etag';

  static const _fallbackLanguages = <AppLanguage>[
    AppLanguage(
      code: 'tr',
      name: 'Türkçe',
      label: 'TR',
      isDefault: true,
    ),
    AppLanguage(code: 'en', name: 'English', label: 'EN'),
  ];

  static const _fallbackTr = <String, String>{
    'salon.mobile.app.title': 'CorpLynk Salon',
    'salon.mobile.nav.discover': 'Keşfet',
    'salon.mobile.nav.booking': 'Randevu',
    'salon.mobile.nav.account': 'Hesabım',
    'salon.mobile.language.tooltip': 'Dil seç',
    'salon.mobile.common.retry': 'Tekrar dene',
    'salon.mobile.common.ok': 'Tamam',
    'salon.mobile.common.cancel': 'Vazgeç',
    'salon.mobile.auth.login.title': 'Giriş',
    'salon.mobile.auth.login.button': 'Giriş yap',
    'salon.mobile.auth.login.forgotPassword': 'Şifremi unuttum',
    'salon.mobile.auth.login.registerCta': 'Hesabım yok — kayıt ol',
    'salon.mobile.auth.login.customerNotice':
        'Salon müşterisi (platform) hesabı — işletme/personel girişi değildir. Telefon ve şifre web ile aynıdır.',
    'salon.mobile.auth.login.resendVerification':
        'Doğrulama mailini tekrar gönder',
    'salon.mobile.auth.login.verificationSent':
        'Doğrulama maili tekrar gönderildi.',
    'salon.mobile.auth.login.emailRequired':
        'Doğrulama maili için hesap email adresinizi girin.',
    'salon.mobile.auth.register.title': 'Kayıt ol',
    'salon.mobile.auth.register.notice':
        'Platform müşteri hesabı oluşturun (salon işletme paneli değildir).',
    'salon.mobile.auth.register.button': 'Kayıt ol',
    'salon.mobile.auth.fields.fullName': 'Ad Soyad',
    'salon.mobile.auth.fields.phone': 'Telefon',
    'salon.mobile.auth.fields.email': 'E-posta',
    'salon.mobile.auth.fields.emailOptional': 'E-posta (isteğe bağlı)',
    'salon.mobile.auth.fields.password': 'Şifre',
    'salon.mobile.auth.forgot.title': 'Şifremi unuttum',
    'salon.mobile.auth.forgot.intro':
        'Hesabınızla ilişkili email adresini girin. Sıfırlama linki içeren bir mail göndereceğiz.',
    'salon.mobile.auth.forgot.sent':
        'Eğer bu email ile kayıtlı bir hesap varsa, sıfırlama linki içeren bir mail gönderildi.',
    'salon.mobile.auth.forgot.sentHint':
        'Maili açıp linke tıklayın; sonra bu uygulamaya geri dönüp giriş yapın.',
    'salon.mobile.auth.forgot.submit': 'Sıfırlama maili gönder',
    'salon.mobile.auth.validation.emailRequired': 'E-posta zorunlu',
    'salon.mobile.auth.validation.emailInvalid':
        'Geçerli bir e-posta girin',
    'salon.mobile.account.billing.address': 'Adres',
    'salon.mobile.account.billing.city': 'Şehir',
    'salon.mobile.account.billing.company': 'Şirket adı',
    'salon.mobile.account.billing.corporate': 'Kurumsal',
    'salon.mobile.account.billing.district': 'İlçe',
    'salon.mobile.account.billing.fullNameTitle': 'Ad Soyad / Ünvan',
    'salon.mobile.account.billing.individual': 'Bireysel',
    'salon.mobile.account.billing.postalCode': 'Posta kodu',
    'salon.mobile.account.billing.saved': 'Fatura bilgileri kaydedildi',
    'salon.mobile.account.billing.taxNo': 'Vergi no',
    'salon.mobile.account.billing.taxOffice': 'Vergi dairesi',
    'salon.mobile.account.billing.type': 'Fatura tipi',
    'salon.mobile.account.customerDescription':
        'Telefon ve şifre ile giriş yaparsınız. Randevularınız ve üyelikleriniz API üzerinde Platform kullanıcısı olarak tutulur.',
    'salon.mobile.account.customerTitle': 'Salon müşterisi (platform)',
    'salon.mobile.account.logout': 'Çıkış',
    'salon.mobile.account.loyalty.empty': 'Sadakat bilgisi bulunamadı.',
    'salon.mobile.account.loyalty.giftCardLine':
        '{code} — {amount} TL ({status})',
    'salon.mobile.account.loyalty.giftCards': 'Hediye kartları',
    'salon.mobile.account.loyalty.loading': 'Sadakat bilgileri yükleniyor…',
    'salon.mobile.account.loyalty.membershipLine': 'Üyelik: {plan}',
    'salon.mobile.account.loyalty.pointsLine':
        'Puan: {current} (toplam {total})',
    'salon.mobile.account.notStaffNotice':
        'Bu uygulama işletme/personel paneli değildir; masaüstü CorpLynk Salon panelinden giriş yapan salon ekibi burada oturum açamaz.',
    'salon.mobile.account.payments.empty': 'Henüz ödeme kaydınız yok.',
    'salon.mobile.account.payments.receipt': 'Makbuz',
    'salon.mobile.account.payments.receiptEmpty': 'Makbuz boş döndü.',
    'salon.mobile.account.payments.receiptTitle': 'Makbuz · {type}',
    'salon.mobile.account.payments.receiptUnavailable':
        'Bu kayıt için makbuz mevcut değil.',
    'salon.mobile.account.profile.changePassword': 'Şifre değiştir',
    'salon.mobile.account.profile.currentPassword': 'Mevcut şifre',
    'salon.mobile.account.profile.newPassword': 'Yeni şifre',
    'salon.mobile.account.profile.newPasswordAgain': 'Yeni şifre (tekrar)',
    'salon.mobile.account.profile.passwordMismatch':
        'Yeni şifreler eşleşmiyor',
    'salon.mobile.account.profile.passwordSaved': 'Şifre güncellendi',
    'salon.mobile.account.profile.save': 'Profili kaydet',
    'salon.mobile.account.profile.saved': 'Profil güncellendi',
    'salon.mobile.account.profile.updatePassword': 'Şifreyi güncelle',
    'salon.mobile.account.salons.empty':
        'Henüz bir salona üye değilsiniz. Keşfet sekmesinden salon bulabilirsiniz.',
    'salon.mobile.account.salons.favorite': 'Favori',
    'salon.mobile.account.salons.member': 'Üye',
    'salon.mobile.account.salons.slugNotFound':
        'Salon kısa adresi bulunamadı. Randevu sekmesinden slug ile veya Keşfet’ten seçerek deneyin.',
    'salon.mobile.account.tabs.appointments': 'Randevularım',
    'salon.mobile.account.tabs.billing': 'Fatura',
    'salon.mobile.account.tabs.loyalty': 'Sadakat',
    'salon.mobile.account.tabs.payments': 'Ödemeler',
    'salon.mobile.account.tabs.profile': 'Profilim',
    'salon.mobile.account.tabs.salons': 'Salonlarım',
    'salon.mobile.appointments.awaitingApproval':
        'Salon randevunuzu onayladığında bilgilendirileceksiniz.',
    'salon.mobile.appointments.cancelAction': 'İptal et',
    'salon.mobile.appointments.cancelConfirm':
        'Bu randevuyu iptal etmek istiyor musunuz?',
    'salon.mobile.appointments.cancelTitle': 'İptal',
    'salon.mobile.appointments.empty': 'Randevu bulunamadı.',
    'salon.mobile.appointments.past': 'Geçmiş',
    'salon.mobile.appointments.personnelLine': 'Personel: {name}',
    'salon.mobile.appointments.prepaidLine': '{total} TL · {paid} TL ödendi',
    'salon.mobile.appointments.status.awaiting': 'Onay bekliyor',
    'salon.mobile.appointments.status.cancelled': 'İptal',
    'salon.mobile.appointments.status.completed': 'Tamamlandı',
    'salon.mobile.appointments.status.confirmed': 'Onaylandı',
    'salon.mobile.appointments.status.planned': 'Planlandı',
    'salon.mobile.appointments.status.unknown': 'Bilinmiyor',
    'salon.mobile.appointments.upcoming': 'Yaklaşan',
    'salon.mobile.auth.fields.fullNameRequired': 'Ad Soyad *',
    'salon.mobile.auth.fields.phoneRequired': 'Telefon *',
    'salon.mobile.auth.login.accountEmail': 'Hesap email adresi',
    'salon.mobile.auth.reset.newPassword': 'Yeni şifre',
    'salon.mobile.auth.reset.newPasswordRepeat': 'Yeni şifre (tekrar)',
    'salon.mobile.auth.reset.passwordMin': 'En az 6 karakter',
    'salon.mobile.auth.reset.passwordMismatch': 'Şifreler eşleşmiyor.',
    'salon.mobile.auth.reset.submit': 'Şifreyi güncelle',
    'salon.mobile.auth.reset.success':
        'Şifreniz başarıyla güncellendi. Yeni şifrenizle giriş yapabilirsiniz.',
    'salon.mobile.auth.reset.title': 'Yeni şifre belirle',
    'salon.mobile.auth.reset.tokenHelper':
        'Email\'den gelen linke tıkladıysanız otomatik dolar.',
    'salon.mobile.auth.reset.tokenInvalid': 'Geçerli bir token girin',
    'salon.mobile.auth.reset.tokenLabel': 'Doğrulama token',
    'salon.mobile.auth.validation.phoneInvalid': 'Geçerli bir telefon girin',
    'salon.mobile.booking.awaitingApprovalMessage':
        'Salon randevunuzu onayladığında bilgilendirileceksiniz. Durumu Randevularım bölümünden takip edebilirsiniz.',
    'salon.mobile.booking.bookNow': 'Randevu al',
    'salon.mobile.booking.confirmedTitle': 'Randevunuz onaylandı',
    'salon.mobile.booking.createFailed': 'Randevu oluşturulamadı',
    'salon.mobile.booking.date': 'Tarih',
    'salon.mobile.booking.dayClosed':
        'Salon bugün kapalı. Başka bir tarih seçin.',
    'salon.mobile.booking.disabled':
        'Bu salon online randevuyu kapalı tutuyor.',
    'salon.mobile.booking.flexibleStaffHint':
        'Aynı saatte birden fazla personel müsaitse saat ayrı ayrı görünür; harf personeli belirtir.',
    'salon.mobile.booking.joinWaitlist': 'Bekleme listesine yazıl',
    'salon.mobile.booking.noOnlinePaymentMessage':
        'Bu salon online ödeme almıyor. Salon randevunuzu onayladığında bilgilendirileceksiniz.',
    'salon.mobile.booking.noSlotForDate': 'Bu tarih için müsait slot yok.',
    'salon.mobile.booking.noStaffForService':
        'Bu hizmet için listelenen personel yok.',
    'salon.mobile.booking.notes': 'Notlar',
    'salon.mobile.booking.paymentFailed': 'Ödeme tamamlanamadı.',
    'salon.mobile.booking.paymentPageMissing':
        'Ödeme adımı bekleniyordu ancak sayfa açılamadı. Lütfen tekrar deneyin.',
    'salon.mobile.booking.paymentSuccessMessage':
        'Ödeme tamamlandı, randevunuz oluşturuldu. Randevularım bölümünden takip edebilirsiniz.',
    'salon.mobile.booking.requestReceivedTitle': 'Randevu talebiniz alındı',
    'salon.mobile.booking.staffFlexible': 'Fark etmez',
    'salon.mobile.booking.staffFlexibleHint':
        'Saat ekranında müsait personeli seçin',
    'salon.mobile.booking.staffNotSelected': 'Personel seçilmedi',
    'salon.mobile.booking.step.confirm': 'Onay',
    'salon.mobile.booking.step.contact': 'İletişim bilgileri',
    'salon.mobile.booking.step.datetime': 'Tarih ve saat',
    'salon.mobile.booking.step.service': 'Hizmet seçimi',
    'salon.mobile.booking.step.staff': 'Personel',
    'salon.mobile.booking.stepCounter': 'Adım {current} / {total}',
    'salon.mobile.booking.summary.date': 'Tarih: {date} - {time}',
    'salon.mobile.booking.summary.deposit': 'Depozito: {amount}',
    'salon.mobile.booking.summary.depositRedirect':
        'Depozitolu randevuda güvenli ödeme sayfasına yönlendirileceksiniz.',
    'salon.mobile.booking.summary.freeCancellation':
        'Ücretsiz iptal: {hours} saat öncesine kadar',
    'salon.mobile.booking.summary.guest': 'Misafir: {name} - {phone}',
    'salon.mobile.booking.summary.noShowFee': 'Gelmeme: {amount}',
    'salon.mobile.booking.summary.policy': 'Politika',
    'salon.mobile.booking.summary.price': 'Ücret: {price}',
    'salon.mobile.booking.summary.service': 'Hizmet: {service}',
    'salon.mobile.booking.summary.staff': 'Personel: {staff}',
    'salon.mobile.booking.titleWithSalon': 'Randevu · {salon}',
    'salon.mobile.booking.waitlist.added': 'Listeye eklendi',
    'salon.mobile.booking.waitlist.anytime': 'Fark etmez',
    'salon.mobile.booking.waitlist.evening': 'Akşam',
    'salon.mobile.booking.waitlist.morning': 'Sabah',
    'salon.mobile.booking.waitlist.namePhoneRequired': 'Ad ve telefon zorunlu.',
    'salon.mobile.booking.waitlist.noon': 'Öğle',
    'salon.mobile.booking.waitlist.note': 'Not',
    'salon.mobile.booking.waitlist.timePreference': 'Saat tercihi',
    'salon.mobile.booking.waitlist.title': 'Bekleme listesi',
    'salon.mobile.common.active': 'aktif',
    'salon.mobile.common.back': 'Geri',
    'salon.mobile.common.free': 'Ücretsiz',
    'salon.mobile.common.loadFailedWithMessage': 'Yüklenemedi: {message}',
    'salon.mobile.common.minutes': '{count} dk',
    'salon.mobile.common.next': 'İleri',
    'salon.mobile.common.no': 'Hayır',
    'salon.mobile.common.passive': 'pasif',
    'salon.mobile.common.refresh': 'Yenile',
    'salon.mobile.common.save': 'Kaydet',
    'salon.mobile.common.send': 'Gönder',
    'salon.mobile.common.sending': 'Gönderiliyor…',
    'salon.mobile.discover.checking': 'Kontrol…',
    'salon.mobile.discover.descriptionEmpty': 'Açıklama henüz eklenmemiş.',
    'salon.mobile.discover.empty': 'Salon bulunamadı.',
    'salon.mobile.discover.goToMyLocation': 'Konumuma git',
    'salon.mobile.discover.headquarter': 'Merkez',
    'salon.mobile.discover.loadingLocation': 'Konumunuz belirleniyor…',
    'salon.mobile.discover.loadingSalons': 'Salonlar yükleniyor…',
    'salon.mobile.discover.loadingSalonsAndLocation':
        'Salonlar ve konum yükleniyor…',
    'salon.mobile.discover.locationMissing': 'Konum belirtilmemiş',
    'salon.mobile.discover.locationPermissionRequired':
        'Konum izni gerekli. Ayarlardan izin verebilirsiniz.',
    'salon.mobile.discover.locationTitle': 'Konum',
    'salon.mobile.discover.locationUnavailable':
        'Konum alınamadı. GPS açık mı kontrol edin.',
    'salon.mobile.discover.moveHere': 'Evet, buraya taşı',
    'salon.mobile.discover.moveLocationConfirm':
        'Konumunuzu buraya taşımak ister misiniz?',
    'salon.mobile.discover.nearbyHint':
        'Konumunuza göre {km} km içindeki şubeler öncelikli.',
    'salon.mobile.discover.noMatches':
        'Aramanızla eşleşen şube yok veya yakınınızda kayıt yok.',
    'salon.mobile.discover.openSalon': 'Salonu aç',
    'salon.mobile.discover.reviewCount': '({count} yorum)',
    'salon.mobile.discover.salonsTitle': 'Salonlar',
    'salon.mobile.discover.searchHint': 'Salon veya şehir ara…',
    'salon.mobile.discover.sessionOpen': 'Oturum açık',
    'salon.mobile.discover.slugHint': 'ornek-sube',
    'salon.mobile.discover.slugLabel': 'Salon kısa adresi (slug)',
    'salon.mobile.discover.slugMissing':
        'Bu şube için kısa adres (slug) tanımlı değil.',
    'salon.mobile.discover.slugRailDescription':
        'Paylaşılan bağlantıdaki kısa adresi yazın. Haritadan seçmek istemezseniz buradan da randevuya gidebilirsiniz.',
    'salon.mobile.discover.slugRailTitle': 'Link bilgisinden randevu',
    'salon.mobile.discover.slugRequired':
        'Salon kısa adresini girin veya listeden / haritadan seçin.',
    'salon.mobile.discover.subtitle':
        'Harita ile yakınınızdaki salonlar · liste ve slug ile randevu',
    'salon.mobile.payment.title': 'Ödeme',
    'salon.mobile.payment.unsupported':
        'Bu platformda ödeme ekranı desteklenmiyor.',
    'salon.mobile.profile.empty.bodyNoBooking':
        'Bu salon henüz hizmetlerini, ekibini veya çalışma saatlerini eklememiş. Salon randevu kabul etmiyor olabilir; iletişim bilgisi varsa doğrudan arayabilirsiniz.',
    'salon.mobile.profile.empty.bodyWithBooking':
        'Bu salon henüz hizmetlerini, ekibini veya çalışma saatlerini eklememiş. Yine de aşağıdaki Randevu Al butonu ile randevu talebi gönderebilirsiniz.',
    'salon.mobile.profile.empty.title': 'Profil bilgileri henüz tamamlanmadı',
    'salon.mobile.profile.hours.closed': 'Kapalı',
    'salon.mobile.profile.hours.day.fri': 'Cuma',
    'salon.mobile.profile.hours.day.mon': 'Pazartesi',
    'salon.mobile.profile.hours.day.sat': 'Cumartesi',
    'salon.mobile.profile.hours.day.sun': 'Pazar',
    'salon.mobile.profile.hours.day.thu': 'Perşembe',
    'salon.mobile.profile.hours.day.tue': 'Salı',
    'salon.mobile.profile.hours.day.wed': 'Çarşamba',
    'salon.mobile.profile.hours.today': 'Bugün',
    'salon.mobile.profile.linkOpenFailed': 'Açılamadı: {uri}',
    'salon.mobile.profile.map.directions': 'Yol tarifi',
    'salon.mobile.profile.map.directionsAction': 'Yol tarifi al',
    'salon.mobile.profile.map.locationInfo': 'Konum bilgisi',
    'salon.mobile.profile.membership.applyCta': 'Başvur →',
    'salon.mobile.profile.membership.confirmAndPay': 'Onayla ve ödemeye geç',
    'salon.mobile.profile.membership.discount': '%{percent} indirim',
    'salon.mobile.profile.membership.durationDays': '/ {days} gün',
    'salon.mobile.profile.membership.htmlMissing': 'Ödeme formu alınamadı.',
    'salon.mobile.profile.membership.join': 'Üye ol',
    'salon.mobile.profile.membership.joinCta': 'Üye ol →',
    'salon.mobile.profile.membership.paidNotice':
        'Ücretli plan. Bilgilerinizi onayladıktan sonra ödeme adımına geçilecek.',
    'salon.mobile.profile.membership.paymentIncomplete': 'Ödeme tamamlanmadı.',
    'salon.mobile.profile.membership.paymentSuccess':
        'Ödeme alındı, üyeliğiniz aktif.',
    'salon.mobile.profile.membership.priorityBooking': 'Öncelikli randevu',
    'salon.mobile.profile.membership.received': 'Üyelik başvurunuz alındı.',
    'salon.mobile.profile.reviews.approvalHint':
        'Yorumunuz salon onayından sonra herkese görünür olacak.',
    'salon.mobile.profile.reviews.commentLabel': 'Yorum (opsiyonel)',
    'salon.mobile.profile.reviews.countShort': '({count} yorum)',
    'salon.mobile.profile.reviews.displayName': 'Görünen ad (opsiyonel)',
    'salon.mobile.profile.reviews.empty':
        'Henüz onaylı yorum yok. İlk yorumu siz yazın.',
    'salon.mobile.profile.reviews.guest': 'Misafir',
    'salon.mobile.profile.reviews.received':
        'Yorumunuz alındı, salon onayından sonra listede görünecek.',
    'salon.mobile.profile.reviews.sheetTitle': 'Yorumunuz',
    'salon.mobile.profile.reviews.write': 'Yorum yaz',
    'salon.mobile.profile.sections.banners': 'Duyurular',
    'salon.mobile.profile.sections.contact': 'İletişim',
    'salon.mobile.profile.sections.gallery': 'Galeri',
    'salon.mobile.profile.sections.hours': 'Çalışma saatleri',
    'salon.mobile.profile.sections.map': 'Konum',
    'salon.mobile.profile.sections.memberships': 'Üyelik planları',
    'salon.mobile.profile.sections.reviews': 'Yorumlar',
    'salon.mobile.profile.sections.services': 'Hizmetler',
    'salon.mobile.profile.sections.team': 'Ekip',
    'salon.mobile.profile.title': 'Salon',
    'salon.mobile.receipt.unsupported':
        'Bu platformda makbuz görüntüleme desteklenmiyor.',
  };

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  CorpApiClient? _api;
  Future<void>? _loadFuture;
  bool _refreshing = false;

  Locale _locale = const Locale('tr', 'TR');
  List<AppLanguage> _languages = _fallbackLanguages;
  Map<String, String> _translations = _fallbackTr;

  Locale get locale => _locale;
  List<AppLanguage> get languages => List.unmodifiable(_languages);
  bool get isRefreshing => _refreshing;

  List<Locale> get supportedLocales {
    final locales = _languages
        .where((l) => l.isActive && l.code.isNotEmpty)
        .map((l) => l.locale)
        .toList();
    return locales.isEmpty
        ? _fallbackLanguages.map((l) => l.locale).toList()
        : locales;
  }

  String t(String key, [String? fallback]) {
    return _translations[key] ?? _fallbackTr[key] ?? fallback ?? key;
  }

  Future<void> loadCached() {
    return _loadFuture ??= _loadCached();
  }

  Future<void> _loadCached() async {
    final savedCode = await _storage.read(key: _kLocale);
    if (savedCode != null && savedCode.isNotEmpty) {
      _locale = _localeFromCode(savedCode);
    }

    final rawLanguages = await _storage.read(key: _kLanguagesJson);
    final cachedLanguages = _decodeLanguages(rawLanguages);
    if (cachedLanguages.isNotEmpty) {
      _languages = cachedLanguages;
    }

    final cachedTranslations =
        await _storage.read(key: _translationsJsonKey(_locale.languageCode));
    final decodedTranslations = _decodeTranslations(cachedTranslations);
    if (decodedTranslations.isNotEmpty) {
      _translations = {..._fallbackTr, ...decodedTranslations};
    }

    notifyListeners();
  }

  void bindApi(CorpApiClient api) {
    if (identical(_api, api)) return;
    _api = api;
    unawaited(refresh());
  }

  Future<void> setLanguage(String code) async {
    final normalized = code.trim().toLowerCase();
    if (normalized.isEmpty || normalized == _locale.languageCode) return;

    _locale = _localeFromCode(normalized);
    await _storage.write(key: _kLocale, value: normalized);

    final cachedTranslations =
        await _storage.read(key: _translationsJsonKey(normalized));
    _translations = {
      ..._fallbackTr,
      ..._decodeTranslations(cachedTranslations),
    };
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    final api = _api;
    if (api == null || _refreshing) return;

    await loadCached();

    _refreshing = true;
    notifyListeners();

    try {
      await _refreshLanguages(api);
      await _refreshTranslations(api, _locale.languageCode);
    } catch (_) {
      // Cache/fallback ile devam edilir; lokalizasyon uygulama acilisini bloklamaz.
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> _refreshLanguages(CorpApiClient api) async {
    final etag = await _storage.read(key: _kLanguagesEtag);
    final result = await api.fetchTranslationLanguages(ifNoneMatch: etag);
    if (result.notModified) return;

    final active = result.languages.where((l) => l.isActive).toList();
    if (active.isEmpty) return;

    _languages = active;
    await _storage.write(
      key: _kLanguagesJson,
      value: jsonEncode(active.map((l) => l.toJson()).toList()),
    );
    if (result.etag != null) {
      await _storage.write(key: _kLanguagesEtag, value: result.etag);
    }
  }

  Future<void> _refreshTranslations(CorpApiClient api, String code) async {
    final etag = await _storage.read(key: _translationsEtagKey(code));
    final result = await api.fetchTranslations(
      code,
      module: _module,
      ifNoneMatch: etag,
    );
    if (result.notModified) return;

    _translations = {..._fallbackTr, ...result.translations};
    await _storage.write(
      key: _translationsJsonKey(code),
      value: jsonEncode(result.translations),
    );
    if (result.etag != null) {
      await _storage.write(key: _translationsEtagKey(code), value: result.etag);
    }
  }

  static String _translationsJsonKey(String code) =>
      'i18n_${_module}_${code}_translations_json';

  static String _translationsEtagKey(String code) =>
      'i18n_${_module}_${code}_translations_etag';

  static Locale _localeFromCode(String code) {
    return _fallbackLanguages
        .firstWhere(
          (l) => l.code == code,
          orElse: () => AppLanguage(
            code: code,
            name: code.toUpperCase(),
            label: code.toUpperCase(),
          ),
        )
        .locale;
  }

  static List<AppLanguage> _decodeLanguages(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AppLanguage.fromJson(e as Map<String, dynamic>))
          .where((l) => l.code.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Map<String, String> _decodeTranslations(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return const {};
    }
  }
}

extension AppLocalizationContext on BuildContext {
  String tr(String key, [String? fallback]) {
    return watch<AppLocalizationState>().t(key, fallback);
  }

  String trRead(String key, [String? fallback]) {
    return read<AppLocalizationState>().t(key, fallback);
  }
}
