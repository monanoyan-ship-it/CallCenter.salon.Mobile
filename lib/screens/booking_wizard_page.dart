import 'package:callcenter_salon_mobil/models/booking_models.dart';
import 'package:callcenter_salon_mobil/screens/login_page.dart';
import 'package:callcenter_salon_mobil/screens/payment_webview_page.dart';
import 'package:callcenter_salon_mobil/services/corp_api.dart';
import 'package:callcenter_salon_mobil/state/session_state.dart';
import 'package:callcenter_salon_mobil/util/api_errors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Web'deki Book.cshtml akisina paralel: hizmet, personel, tarih/saat, iletisim, onay.
class BookingWizardPage extends StatefulWidget {
  const BookingWizardPage({super.key, required this.slug});

  final String slug;

  @override
  State<BookingWizardPage> createState() => _BookingWizardPageState();
}

class _BookingWizardPageState extends State<BookingWizardPage> {
  static const List<String> _stepTitles = [
    'Hizmet seçimi',
    'Personel',
    'Tarih ve saat',
    'İletişim bilgileri',
    'Onay',
  ];

  int _step = 0;
  SalonProfile? _profile;
  BookingPolicy? _policy;
  List<StaffMember> _staff = [];
  bool _staffLoading = false;

  DateTime _selectedDay = DateTime.now();
  List<TimeSlot> _slots = [];
  bool _slotsLoaded = false;
  bool _dayClosed = false;

  SalonService? _service;
  StaffMember? _staffPick;
  int? _personnelId;
  TimeSlot? _slot;
  int? _autoStaffId;
  String? _autoStaffName;

  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();

  bool _saving = false;
  String? _expandedCategoryKey;

  final _money =
      NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final session = context.read<SessionState>();
    if (!session.isLoggedIn) {
      await Navigator.push<bool>(
          context, MaterialPageRoute(builder: (_) => const LoginPage()));
    }
    if (!mounted) return;
    if (!context.read<SessionState>().isLoggedIn) {
      Navigator.pop(context);
      return;
    }

    final user = context.read<SessionState>().user;
    if (user != null) {
      _fullName.text = user.fullName;
      _phone.text = user.phone;
      _email.text = user.email ?? '';
    }

    await _loadSalon();
  }

  Future<void> _loadSalon() async {
    try {
      final api = context.read<CorpApiClient>();
      final profile = await api.fetchSalonProfile(widget.slug);
      final policy = await api.fetchBookingPolicy(widget.slug);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _policy = policy;
        if (profile.categories.isNotEmpty) {
          _expandedCategoryKey = '${profile.categories.first.id}';
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadStaff() async {
    final svc = _service;
    if (svc == null) return;
    setState(() {
      _staffLoading = true;
      _staff = [];
      _personnelId = null;
      _staffPick = null;
      _slot = null;
      _autoStaffId = null;
      _autoStaffName = null;
    });
    try {
      final list = await context
          .read<CorpApiClient>()
          .fetchAvailableStaff(widget.slug, svc.id);
      if (!mounted) return;
      setState(() {
        _staff = list;
        _staffLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _staffLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
    }
  }

  Future<void> _loadSlots() async {
    final svc = _service;
    if (svc == null) return;
    setState(() {
      _slotsLoaded = false;
      _slot = null;
      _autoStaffId = null;
      _autoStaffName = null;
      _dayClosed = false;
    });
    try {
      final res = await context.read<CorpApiClient>().fetchAvailableSlots(
            slug: widget.slug,
            serviceId: svc.id,
            date: _selectedDay,
            personnelId: _personnelId,
          );
      if (!mounted) return;
      setState(() {
        _slots = res.slots;
        _dayClosed = res.isClosed;
        _slotsLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _slotsLoaded = true);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
    }
  }

  bool _canNext() {
    switch (_step) {
      case 0:
        return _service != null;
      case 1:
        return true;
      case 2:
        return _slot != null && !_dayClosed;
      case 3:
        return _fullName.text.trim().isNotEmpty &&
            _phone.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  void _next() {
    if (!_canNext()) return;
    if (_step == 0) {
      _loadStaff();
    }
    if (_step == 1) {
      _loadSlots();
    }
    setState(() => _step++);
  }

  void _back() {
    if (_step <= 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step--);
  }

  Future<void> _confirm() async {
    final svc = _service;
    final slot = _slot;
    final profile = _profile;
    if (svc == null || slot == null || profile == null) return;

    setState(() => _saving = true);

    int? personnel = _personnelId;
    if (personnel == null && _autoStaffId != null) personnel = _autoStaffId;

    final body = <String, dynamic>{
      'fullName': _fullName.text.trim(),
      'phone': _phone.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'serviceId': svc.id,
      'startTime': slot.startTime,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      if (personnel != null) 'personnelId': personnel,
    };

    try {
      final api = context.read<CorpApiClient>();
      final deposit = _policy?.depositAmount ?? 0;

      if (deposit > 0) {
        final r = await api.bookCheckout(slug: widget.slug, body: body);
        if (!mounted) return;
        if (r.success &&
            r.requireDeposit == true &&
            (r.htmlContent ?? '').isNotEmpty) {
          final paid = await Navigator.push<bool>(
            context,
            MaterialPageRoute<bool>(
              builder: (_) => PaymentWebViewPage(htmlContent: r.htmlContent!),
            ),
          );
          if (!mounted) return;
          if (paid == true) {
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Tamamlandi'),
                content: const Text(
                  'Odeme tamamlandi. Randevunuzu Randevularim bolumunden takip edebilirsiniz.',
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Kapat')),
                ],
              ),
            );
            if (mounted) Navigator.pop(context);
            return;
          }
          if (paid == false && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Odeme tamamlanamadi.')),
            );
          }
        } else if (r.success && deposit > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                r.message ??
                    'Ödeme adımı bekleniyordu ancak sayfa açılamadı. Lütfen tekrar deneyin.',
              ),
            ),
          );
        } else if (r.success) {
          await _showOkAndPop(r.message);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(r.message ?? 'Randevu olusturulamadi')),
          );
        }
      } else {
        final r = await api.bookSimple(slug: widget.slug, body: body);
        if (!mounted) return;
        if (r.success) {
          await _showOkAndPop(r.message);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(r.message ?? 'Randevu olusturulamadi')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showOkAndPop(String? msg) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Randevunuz alindi'),
        content: Text(msg ?? 'Salon onayi bekleniyor.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Tamam')),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  String _confirmedStaffLabel() {
    if (_personnelId != null) return _staffPick?.name ?? '';
    if (_autoStaffName != null && _autoStaffName!.isNotEmpty) {
      return '$_autoStaffName (otomatik)';
    }
    return 'Fark etmez';
  }

  Future<void> _waitlistDialog() async {
    final svc = _service;
    if (svc == null) return;
    final nameCtl = TextEditingController(text: _fullName.text);
    final phoneCtl = TextEditingController(text: _phone.text);
    final emailCtl = TextEditingController(text: _email.text);
    final notesCtl = TextEditingController();
    var slotPref = 'Farketmez';

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Bekleme listesi'),
          content: StatefulBuilder(
            builder: (context, setLocal) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: nameCtl,
                        decoration:
                            const InputDecoration(labelText: 'Ad Soyad')),
                    TextField(
                        controller: phoneCtl,
                        decoration:
                            const InputDecoration(labelText: 'Telefon')),
                    TextField(
                        controller: emailCtl,
                        decoration:
                            const InputDecoration(labelText: 'E-posta')),
                    DropdownButtonFormField<String>(
                      initialValue: slotPref,
                      items: const [
                        DropdownMenuItem(
                            value: 'Farketmez', child: Text('Farketmez')),
                        DropdownMenuItem(value: 'Sabah', child: Text('Sabah')),
                        DropdownMenuItem(value: 'Ogle', child: Text('Ogle')),
                        DropdownMenuItem(value: 'Aksam', child: Text('Aksam')),
                      ],
                      onChanged: (v) =>
                          setLocal(() => slotPref = v ?? 'Farketmez'),
                      decoration:
                          const InputDecoration(labelText: 'Saat tercihi'),
                    ),
                    TextField(
                        controller: notesCtl,
                        decoration: const InputDecoration(labelText: 'Not')),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Iptal')),
            FilledButton(
              onPressed: () async {
                if (nameCtl.text.trim().isEmpty ||
                    phoneCtl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ad ve telefon zorunlu.')),
                  );
                  return;
                }
                final d = DateTime.utc(
                    _selectedDay.year, _selectedDay.month, _selectedDay.day);
                try {
                  await context.read<CorpApiClient>().joinWaitlist(
                    slug: widget.slug,
                    body: {
                      'fullName': nameCtl.text.trim(),
                      'phone': phoneCtl.text.trim(),
                      'email': emailCtl.text.trim().isEmpty
                          ? null
                          : emailCtl.text.trim(),
                      'serviceId': svc.id,
                      'personnelId': _personnelId,
                      'preferredDate': d.toIso8601String(),
                      'preferredTimeSlot': slotPref,
                      'notes': notesCtl.text.trim().isEmpty
                          ? null
                          : notesCtl.text.trim(),
                    },
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Listeye eklendi')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(dioErrorMessage(e))));
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!profile.showBooking) {
      return Scaffold(
        appBar: AppBar(title: Text(profile.salonName)),
        body: const Center(
            child: Text('Bu salon online randevuyu kapali tutuyor.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Randevu · ${profile.salonName}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Adım ${_step + 1} / 5',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    Text(
                      _stepTitles[_step],
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / 5,
                    minHeight: 4,
                    backgroundColor:
                        Theme.of(context).colorScheme.outlineVariant,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _stepBody(profile)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Row(
              children: [
                TextButton(onPressed: _back, child: const Text('Geri')),
                const Spacer(),
                if (_step < 4)
                  FilledButton(
                      onPressed: _canNext() ? _next : null,
                      child: const Text('Ileri')),
                if (_step == 4)
                  FilledButton(
                    onPressed: (_saving || !_canNext()) ? null : _confirm,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Randevu al'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBody(SalonProfile profile) {
    switch (_step) {
      case 0:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final cat in profile.categories) ...[
              ListTile(
                title: Text(cat.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Icon(_expandedCategoryKey == '${cat.id}'
                    ? Icons.expand_less
                    : Icons.expand_more),
                onTap: () => setState(() {
                  _expandedCategoryKey =
                      _expandedCategoryKey == '${cat.id}' ? null : '${cat.id}';
                }),
              ),
              if (_expandedCategoryKey == '${cat.id}')
                for (final s in cat.services)
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: _service?.id == s.id
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: _service?.id == s.id ? 1.5 : 1,
                      ),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 0,
                    child: ListTile(
                      title: Text(s.name),
                      subtitle: Text('${s.durationMinutes} dk'),
                      trailing: Text(_money.format(s.price)),
                      onTap: () => setState(() {
                        _service = s;
                        _staff = [];
                        _staffPick = null;
                        _personnelId = null;
                        _slots = [];
                        _slotsLoaded = false;
                        _slot = null;
                        _autoStaffId = null;
                        _autoStaffName = null;
                      }),
                    ),
                  ),
            ],
          ],
        );
      case 1:
        if (_staffLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: _personnelId == null
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: _personnelId == null ? 1.5 : 1,
                ),
              ),
              color: Theme.of(context).colorScheme.surface,
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.shuffle),
                title: const Text('Fark etmez'),
                subtitle: const Text('Uygun personel atanir'),
                onTap: () => setState(() {
                  _personnelId = null;
                  _staffPick = null;
                }),
              ),
            ),
            for (final st in _staff)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: _personnelId == st.id
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: _personnelId == st.id ? 1.5 : 1,
                  ),
                ),
                color: Theme.of(context).colorScheme.surface,
                elevation: 0,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        st.photoUrl != null ? NetworkImage(st.photoUrl!) : null,
                    child:
                        st.photoUrl == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(st.name),
                  subtitle: Text(st.title ?? st.specialty ?? ''),
                  onTap: () => setState(() {
                    _personnelId = st.id;
                    _staffPick = st;
                  }),
                ),
              ),
            if (_staff.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bu hizmet icin listelenen personel yok.',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );
      case 2:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tarih'),
              subtitle: Text(DateFormat.yMMMMEEEEd('tr').format(_selectedDay)),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    initialDate:
                        _selectedDay.isBefore(now) ? now : _selectedDay,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (d != null) {
                    setState(() => _selectedDay = d);
                    _loadSlots();
                  }
                },
              ),
            ),
            if (_dayClosed)
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
                elevation: 0,
                child: ListTile(
                  leading: Icon(Icons.storefront_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  title:
                      const Text('Salon bu gun kapali. Baska bir tarih secin.'),
                ),
              ),
            if (!_slotsLoaded && !_dayClosed)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_slotsLoaded && !_dayClosed && _slots.isEmpty) ...[
              const Text('Bu tarih icin musait slot yok.'),
              TextButton.icon(
                onPressed: _waitlistDialog,
                icon: const Icon(Icons.notifications),
                label: const Text('Bekleme listesine yazil'),
              ),
            ],
            if (_slotsLoaded && !_dayClosed && _slots.isNotEmpty) ...[
              if (_personnelId == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Saatlerde musait personeller gosterilir; secimde ilk uygun atanir.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sl in _slots)
                    Builder(
                      builder: (ctx) {
                        final scheme = Theme.of(ctx).colorScheme;
                        final sel = _slot?.startTime == sl.startTime;
                        return OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(72, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            backgroundColor:
                                sel ? scheme.primaryContainer : scheme.surface,
                            foregroundColor: sel
                                ? scheme.onPrimaryContainer
                                : scheme.onSurface,
                            side: BorderSide(
                                color: sel ? scheme.primary : scheme.outline),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            setState(() {
                              _slot = sl;
                              if (_personnelId == null &&
                                  sl.availableStaff.isNotEmpty) {
                                final auto = sl.availableStaff.first;
                                _autoStaffId = auto.id;
                                _autoStaffName = auto.name;
                              } else {
                                _autoStaffId = null;
                                _autoStaffName = null;
                              }
                            });
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(sl.timeText),
                              if (_personnelId == null &&
                                  sl.availableStaff.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 70,
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 2,
                                    runSpacing: 2,
                                    children: [
                                      for (final staff
                                          in sl.availableStaff.take(4))
                                        Tooltip(
                                          message: staff.name,
                                          child: CircleAvatar(
                                            radius: 10,
                                            backgroundImage: staff.photoUrl !=
                                                    null
                                                ? NetworkImage(staff.photoUrl!)
                                                : null,
                                            child: staff.photoUrl == null
                                                ? Text(
                                                    staff.initials ?? '?',
                                                    style: const TextStyle(
                                                      fontSize: 8,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                      if (sl.availableStaff.length > 4)
                                        CircleAvatar(
                                          radius: 10,
                                          child: Text(
                                            '+${sl.availableStaff.length - 4}',
                                            style: const TextStyle(fontSize: 8),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ],
        );
      case 3:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _fullName,
              decoration: const InputDecoration(
                  labelText: 'Ad Soyad *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Telefon *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'E-posta', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Notlar', border: OutlineInputBorder()),
            ),
          ],
        );
      default:
        final svc = _service!;
        final slot = _slot!;
        final pol = _policy;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Hizmet: ${svc.name}',
                style: Theme.of(context).textTheme.titleMedium),
            Text(
                'Tarih: ${DateFormat.yMMMMEEEEd('tr').format(_selectedDay)} - ${slot.timeText}'),
            Text('Personel: ${_confirmedStaffLabel()}'),
            Text('Ucret: ${_money.format(svc.price)}'),
            const Divider(height: 24),
            Text('Misafir: ${_fullName.text} - ${_phone.text}'),
            if (pol != null && pol.hasPolicy) ...[
              const SizedBox(height: 16),
              const Text('Politika',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (pol.requireDeposit && pol.depositAmount > 0)
                Text('Depozito: ${_money.format(pol.depositAmount)}'),
              if (pol.freeCancellationHours > 0)
                Text(
                    'Ucretsiz iptal: ${pol.freeCancellationHours} saat oncesine kadar'),
              if (pol.noShowFee > 0)
                Text('Gelmeme: ${_money.format(pol.noShowFee)}'),
            ],
            if ((pol?.depositAmount ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Depozitolu randevuda guvenli odeme sayfasina yonlendirileceksiniz.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13),
                ),
              ),
          ],
        );
    }
  }
}
