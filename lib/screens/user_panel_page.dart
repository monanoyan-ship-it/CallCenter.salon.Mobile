import 'package:callcenter_salon_mobil/constants/app_audience.dart';
import 'package:callcenter_salon_mobil/models/booking_models.dart';
import 'package:callcenter_salon_mobil/models/platform_models.dart';
import 'package:callcenter_salon_mobil/screens/login_page.dart';
import 'package:callcenter_salon_mobil/screens/receipt_view_page.dart';
import 'package:callcenter_salon_mobil/screens/register_page.dart';
import 'package:callcenter_salon_mobil/screens/salon_profile_page.dart';
import 'package:callcenter_salon_mobil/services/corp_api.dart';
import 'package:callcenter_salon_mobil/state/session_state.dart';
import 'package:callcenter_salon_mobil/util/api_errors.dart';
import 'package:callcenter_salon_mobil/widgets/platform_appointments_tab.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Web `/user/panel` ile aynı sekme başlıkları: Salonlarım, Randevularım, Sadakat, Profilim, Fatura.
class UserPanelPage extends StatelessWidget {
  const UserPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();

    if (!session.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hesabım')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(AppAudience.platformCustomerTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(AppAudience.platformCustomerDescription, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.35),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(AppAudience.notSalonStaffNotice),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const LoginPage())),
              child: const Text('Giriş yap'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
              child: const Text('Kayıt ol'),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(session.user?.fullName ?? 'Hesabım'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Çıkış',
              onPressed: () => session.signOut(),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.storefront), text: 'Salonlarım'),
              Tab(icon: Icon(Icons.calendar_month), text: 'Randevularım'),
              Tab(icon: Icon(Icons.star_outline), text: 'Sadakat'),
              Tab(icon: Icon(Icons.payments_outlined), text: 'Ödemeler'),
              Tab(icon: Icon(Icons.person_outline), text: 'Profilim'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Fatura'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MySalonsTab(),
            PlatformAppointmentsTab(),
            _LoyaltyTab(),
            _PaymentsTab(),
            _ProfileTab(),
            _BillingTab(),
          ],
        ),
      ),
    );
  }
}

class _MySalonsTab extends StatefulWidget {
  const _MySalonsTab();

  @override
  State<_MySalonsTab> createState() => _MySalonsTabState();
}

class _MySalonsTabState extends State<_MySalonsTab> {
  Future<List<PlatformJoinedSalon>>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  void _reload() {
    setState(() {
      _future = context.read<CorpApiClient>().fetchJoinedSalons();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<PlatformJoinedSalon>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return ListView(children: [const SizedBox(height: 120), Center(child: CircularProgressIndicator())]);
          }
          if (snap.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [Padding(padding: const EdgeInsets.all(24), child: Text(dioErrorMessage(snap.error!)))],
            );
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: const [
                Icon(Icons.storefront, size: 48, color: Colors.black26),
                SizedBox(height: 12),
                Text('Henüz bir salona üye değilsiniz. Keşfet sekmesinden salon bulabilirsiniz.'),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final s = list[i];
              final loc = [s.district, s.city].where((x) => (x ?? '').isNotEmpty).join(' · ');
              return Card(
                child: ListTile(
                  leading: s.logoUrl != null ? CircleAvatar(backgroundImage: NetworkImage(s.logoUrl!)) : const CircleAvatar(child: Icon(Icons.store)),
                  title: Text(s.salonName),
                  subtitle: Text(loc.isEmpty ? 'Üye' : loc),
                  trailing: IconButton(
                    icon: Icon(s.isFavorite ? Icons.star : Icons.star_border),
                    tooltip: 'Favori',
                    onPressed: () async {
                      try {
                        await context.read<CorpApiClient>().toggleSalonFavorite(s.customerId);
                        _reload();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
                        }
                      }
                    },
                  ),
                  onTap: () async {
                    final slug = await _resolveSlug(context, s);
                    if (!context.mounted || slug == null || slug.isEmpty) return;
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(builder: (_) => SalonProfilePage(slug: slug)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// `PlatformSalonDto` slug içermez: önce yayın şube listesi (`/api/salon`), sonra sayfalı discover.
Future<String?> _resolveSlug(BuildContext context, PlatformJoinedSalon s) async {
  final api = context.read<CorpApiClient>();
  String norm(String x) => x.trim().toLowerCase();
  final target = norm(s.salonName);

  try {
    final branches = await api.fetchPublishedBranches();
    final byName = branches.where((b) => norm(b.salonName) == target).toList();
    if (byName.isNotEmpty) {
      final hq = byName.where((b) => b.isHeadquarter).toList();
      return (hq.isNotEmpty ? hq.first : byName.first).slug;
    }
  } catch (_) {
    // `/api/salon` başarısız olursa discover ile devam et.
  }

  List<DiscoverSalonItem> pick(DiscoverSalonsResult r) {
    return r.salons
        .where((x) => x.customerId == s.customerId || norm(x.name) == target)
        .toList();
  }

  try {
    for (final search in <String?>[s.salonName, null]) {
      for (var page = 1; page <= 40; page++) {
        final r = await api.discoverSalons(search: search, page: page);
        final hits = pick(r);
        if (hits.isNotEmpty) return hits.first.slug;
        if (r.salons.isEmpty) break;
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
    }
    return null;
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Salon kısa adresi bulunamadı. Randevu sekmesinden slug ile veya Keşfet’ten seçerek deneyin.',
        ),
      ),
    );
  }
  return null;
}

class _LoyaltyTab extends StatefulWidget {
  const _LoyaltyTab();

  @override
  State<_LoyaltyTab> createState() => _LoyaltyTabState();
}

class _LoyaltyTabState extends State<_LoyaltyTab> {
  Future<List<PlatformLoyaltyEntry>>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  void _reload() {
    setState(() => _future = context.read<CorpApiClient>().fetchPlatformLoyalty());
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<PlatformLoyaltyEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return ListView(children: [const SizedBox(height: 120), Center(child: CircularProgressIndicator())]);
          }
          if (snap.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [Padding(padding: const EdgeInsets.all(24), child: Text(dioErrorMessage(snap.error!)))],
            );
          }
          final rows = snap.data ?? [];
          if (rows.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: const [Text('Sadakat bilgisi bulunamadı.')],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.salonName, style: Theme.of(context).textTheme.titleMedium),
                      Text('Puan: ${r.currentPoints.toStringAsFixed(0)} (toplam ${r.totalEarned.toStringAsFixed(0)})'),
                      if (r.membershipPlanName != null && r.membershipPlanName!.isNotEmpty)
                        Text('Üyelik: ${r.membershipPlanName}'),
                      if (r.giftCards.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Hediye kartları', style: TextStyle(fontWeight: FontWeight.w600)),
                        for (final g in r.giftCards)
                          Text('${g.code} — ${g.remainingBalance.toStringAsFixed(2)} TL (${g.isActive ? 'aktif' : 'pasif'})'),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PaymentsTab extends StatefulWidget {
  const _PaymentsTab();

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  static final NumberFormat _money =
      NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
  static final DateFormat _date = DateFormat('d MMM y · HH:mm', 'tr_TR');

  Future<List<PaymentHistoryEntry>>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  void _reload() {
    setState(() {
      _future = context.read<CorpApiClient>().fetchPaymentHistory();
    });
  }

  Future<void> _openReceipt(PaymentHistoryEntry e) async {
    if (!e.canDownloadReceipt) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu kayıt için makbuz mevcut değil.')),
      );
      return;
    }
    try {
      final html = await context.read<CorpApiClient>().fetchMyReceiptHtml(e.uid);
      if (!mounted) return;
      if (html.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Makbuz boş döndü.')),
        );
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptViewPage(
            htmlContent: html,
            title: 'Makbuz · ${e.paymentType}',
          ),
        ),
      );
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dioErrorMessage(err))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<PaymentHistoryEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return ListView(
              children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator())],
            );
          }
          if (snap.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(dioErrorMessage(snap.error!)),
                ),
              ],
            );
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Icon(Icons.payments_outlined, size: 48, color: scheme.onSurfaceVariant),
                const SizedBox(height: 12),
                const Text('Henüz ödeme kaydınız yok.', textAlign: TextAlign.center),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final e = list[i];
              final isSuccess = e.status.toLowerCase().contains('başarı') ||
                  e.status.toLowerCase().contains('basari') ||
                  e.status.toLowerCase().contains('success');
              return Card(
                child: InkWell(
                  onTap: e.canDownloadReceipt ? () => _openReceipt(e) : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.receipt_long, color: scheme.onPrimaryContainer),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.paymentType,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _date.format(e.createdAt.toLocal()),
                                style: TextStyle(
                                    fontSize: 12, color: scheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSuccess
                                          ? Colors.green.withValues(alpha: 0.12)
                                          : scheme.errorContainer.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      e.status,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isSuccess
                                            ? Colors.green.shade800
                                            : scheme.onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _money.format(e.amount),
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary),
                            ),
                            if (e.canDownloadReceipt)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.description_outlined,
                                        size: 14, color: scheme.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Makbuz',
                                      style: TextStyle(
                                          fontSize: 11, color: scheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pwdCur = TextEditingController();
  final _pwdNew = TextEditingController();
  final _pwdNew2 = TextEditingController();
  bool _loading = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pwdCur.dispose();
    _pwdNew.dispose();
    _pwdNew2.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await context.read<CorpApiClient>().fetchPlatformProfile();
      _name.text = p.fullName;
      _email.text = p.email ?? '';
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = dioErrorMessage(e);
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _saveProfile() async {
    try {
      await context.read<CorpApiClient>().updatePlatformProfile(
            fullName: _name.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          );
      final session = context.read<SessionState>();
      await session.replaceUser(
        PlatformUser(
          fullName: _name.text.trim(),
          phone: session.user?.phone ?? '',
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        ),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil güncellendi')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
    }
  }

  Future<void> _changePwd() async {
    if (_pwdNew.text != _pwdNew2.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yeni şifreler eşleşmiyor')));
      return;
    }
    try {
      await context.read<CorpApiClient>().changePlatformPassword(
            currentPassword: _pwdCur.text,
            newPassword: _pwdNew.text,
          );
      _pwdCur.clear();
      _pwdNew.clear();
      _pwdNew2.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifre güncellendi')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Ad Soyad', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'E-posta', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _saveProfile, child: const Text('Profili kaydet')),
        const Divider(height: 32),
        const Text('Şifre değiştir', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _pwdCur,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Mevcut şifre', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _pwdNew,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Yeni şifre', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _pwdNew2,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Yeni şifre (tekrar)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _changePwd, child: const Text('Şifreyi güncelle')),
      ],
    );
  }
}

class _BillingTab extends StatefulWidget {
  const _BillingTab();

  @override
  State<_BillingTab> createState() => _BillingTabState();
}

class _BillingTabState extends State<_BillingTab> {
  int _billingType = 1;
  final _fullName = TextEditingController();
  final _company = TextEditingController();
  final _taxOffice = TextEditingController();
  final _taxNo = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _postal = TextEditingController();
  bool _loading = true;

  @override
  void dispose() {
    _fullName.dispose();
    _company.dispose();
    _taxOffice.dispose();
    _taxNo.dispose();
    _address.dispose();
    _city.dispose();
    _district.dispose();
    _postal.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await context.read<CorpApiClient>().fetchPlatformProfile();
      _billingType = p.billingType;
      _fullName.text = p.billingFullName ?? '';
      _company.text = p.billingCompanyName ?? '';
      _taxOffice.text = p.billingTaxOffice ?? '';
      _taxNo.text = p.billingTaxNumber ?? '';
      _address.text = p.billingAddress ?? '';
      _city.text = p.billingCity ?? '';
      _district.text = p.billingDistrict ?? '';
      _postal.text = p.billingPostalCode ?? '';
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _save() async {
    try {
      await context.read<CorpApiClient>().updatePlatformBilling({
        'billingType': _billingType,
        'billingFullName': _fullName.text.trim().isEmpty ? null : _fullName.text.trim(),
        'billingCompanyName': _company.text.trim().isEmpty ? null : _company.text.trim(),
        'billingTaxOffice': _taxOffice.text.trim().isEmpty ? null : _taxOffice.text.trim(),
        'billingTaxNumber': _taxNo.text.trim().isEmpty ? null : _taxNo.text.trim(),
        'billingAddress': _address.text.trim().isEmpty ? null : _address.text.trim(),
        'billingCity': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'billingDistrict': _district.text.trim().isEmpty ? null : _district.text.trim(),
        'billingPostalCode': _postal.text.trim().isEmpty ? null : _postal.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fatura bilgileri kaydedildi')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<int>(
          value: _billingType,
          decoration: const InputDecoration(labelText: 'Fatura tipi', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 1, child: Text('Bireysel')),
            DropdownMenuItem(value: 2, child: Text('Kurumsal')),
          ],
          onChanged: (v) => setState(() => _billingType = v ?? 1),
        ),
        const SizedBox(height: 12),
        TextField(controller: _fullName, decoration: const InputDecoration(labelText: 'Ad Soyad / Ünvan', border: OutlineInputBorder())),
        TextField(controller: _company, decoration: const InputDecoration(labelText: 'Şirket adı', border: OutlineInputBorder())),
        TextField(controller: _taxOffice, decoration: const InputDecoration(labelText: 'Vergi dairesi', border: OutlineInputBorder())),
        TextField(controller: _taxNo, decoration: const InputDecoration(labelText: 'Vergi no', border: OutlineInputBorder())),
        TextField(controller: _address, decoration: const InputDecoration(labelText: 'Adres', border: OutlineInputBorder())),
        TextField(controller: _city, decoration: const InputDecoration(labelText: 'Şehir', border: OutlineInputBorder())),
        TextField(controller: _district, decoration: const InputDecoration(labelText: 'İlçe', border: OutlineInputBorder())),
        TextField(controller: _postal, decoration: const InputDecoration(labelText: 'Posta kodu', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: const Text('Kaydet')),
      ],
    );
  }
}
