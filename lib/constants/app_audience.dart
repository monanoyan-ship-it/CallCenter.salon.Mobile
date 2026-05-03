/// Bu uygulamanın hedef kitlesi — backend rolleriyle uyumlu.
///
/// **Salon müşterisi (platform kullanıcısı)** — JWT rolü `PlatformUser`.
/// Web karşılığı: `/user/login`, `/user/panel`, `localStorage.platformToken`,
/// `PublicSalon/Book.cshtml` (randevu için giriş zorunlu).
///
/// **Salon işletmesi / personel** — JWT cookie `CorpLynk.Salon.Auth`, sidebar menüsü
/// (`_Layout.cshtml`: Dashboard, Müşteriler, iç randevular vb.) — **bu mobil uygulama
/// bu kullanıcı tipini desteklemez** (ayrı masaüstü/panel).
abstract final class AppAudience {
  static const String platformCustomerTitle = 'Salon müşterisi (platform)';
  static const String platformCustomerDescription =
      'Telefon ve şifre ile giriş yaparsınız. Randevularınız ve üyelikleriniz '
      'API üzerinde Platform kullanıcısı olarak tutulur.';
  static const String notSalonStaffNotice =
      'Bu uygulama işletme/personel paneli değildir; masaüstü CorpLynk Salon '
      'panelinden giriş yapan salon ekibi burada oturum açamaz.';
}
