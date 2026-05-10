import 'package:callcenter_salon_mobil/models/booking_models.dart';
import 'package:callcenter_salon_mobil/screens/login_page.dart';
import 'package:callcenter_salon_mobil/screens/payment_webview_page.dart';
import 'package:callcenter_salon_mobil/services/corp_api.dart';
import 'package:callcenter_salon_mobil/state/app_localization_state.dart';
import 'package:callcenter_salon_mobil/state/session_state.dart';
import 'package:callcenter_salon_mobil/util/api_errors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Web'deki Book.cshtml akışına paralel: hizmet, personel, tarih/saat, iletişim, onay.
class BookingWizardPage extends StatefulWidget {
  const BookingWizardPage({super.key, required this.slug});

  final String slug;

  @override
  State<BookingWizardPage> createState() => _BookingWizardPageState();
}

class _BookingWizardPageState extends State<BookingWizardPage> {
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
  int? _slotStaffId;
  String? _slotStaffName;

  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();

  bool _saving = false;
  String? _expandedCategoryKey;

  final _money =
      NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);

  String _stepTitle(int index) {
    switch (index) {
      case 0:
        return context.tr('salon.mobile.booking.step.service', 'Hizmet seçimi');
      case 1:
        return context.tr('salon.mobile.booking.step.staff', 'Personel');
      case 2:
        return context.tr('salon.mobile.booking.step.datetime', 'Tarih ve saat');
      case 3:
        return context.tr('salon.mobile.booking.step.contact', 'İletişim bilgileri');
      default:
        return context.tr('salon.mobile.booking.step.confirm', 'Onay');
    }
  }

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
      _slotStaffId = null;
      _slotStaffName = null;
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
      _slotStaffId = null;
      _slotStaffName = null;
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
        return _slot != null &&
            !_dayClosed &&
            (_personnelId != null || _slotStaffId != null);
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
    if (personnel == null && _slotStaffId != null) personnel = _slotStaffId;

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
            await _showOkAndPop(
              title: context.tr(
                'salon.mobile.booking.confirmedTitle',
                'Randevunuz onaylandı',
              ),
              message: context.tr(
                'salon.mobile.booking.paymentSuccessMessage',
                'Ödeme tamamlandı, randevunuz oluşturuldu. Randevularım bölümünden takip edebilirsiniz.',
              ),
            );
            return;
          }
          if (paid == false && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr(
                  'salon.mobile.booking.paymentFailed',
                  'Ödeme tamamlanamadı.',
                )),
              ),
            );
          }
        } else if (r.success && deposit > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                r.message ??
                    context.tr(
                      'salon.mobile.booking.paymentPageMissing',
                      'Ödeme adımı bekleniyordu ancak sayfa açılamadı. Lütfen tekrar deneyin.',
                    ),
              ),
            ),
          );
        } else if (r.success) {
          await _showOkAndPop(
            title: context.tr(
              'salon.mobile.booking.requestReceivedTitle',
              'Randevu talebiniz alındı',
            ),
            message: r.message ??
                context.tr(
                  'salon.mobile.booking.awaitingApprovalMessage',
                  'Salon randevunuzu onayladığında bilgilendirileceksiniz. Durumu Randevularım bölümünden takip edebilirsiniz.',
                ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(r.message ??
                  context.tr(
                    'salon.mobile.booking.createFailed',
                    'Randevu oluşturulamadı',
                  )),
            ),
          );
        }
      } else {
        final r = await api.bookSimple(slug: widget.slug, body: body);
        if (!mounted) return;
        if (r.success) {
          await _showOkAndPop(
            title: context.tr(
              'salon.mobile.booking.requestReceivedTitle',
              'Randevu talebiniz alındı',
            ),
            message: r.message ??
                context.tr(
                  'salon.mobile.booking.noOnlinePaymentMessage',
                  'Bu salon online ödeme almıyor. Salon randevunuzu onayladığında bilgilendirileceksiniz.',
                ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(r.message ??
                  context.tr(
                    'salon.mobile.booking.createFailed',
                    'Randevu oluşturulamadı',
                  )),
            ),
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

  Future<void> _showOkAndPop({required String title, required String message}) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('salon.mobile.common.ok', 'Tamam'))),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  String _confirmedStaffLabel() {
    if (_personnelId != null) return _staffPick?.name ?? '';
    if (_slotStaffName != null && _slotStaffName!.isNotEmpty) {
      return _slotStaffName!;
    }
    return context.tr('salon.mobile.booking.staffNotSelected', 'Personel seçilmedi');
  }

  String _staffSymbol(SlotStaffMini staff) {
    final trimmed = staff.name.trim();
    if (trimmed.isNotEmpty) {
      return String.fromCharCode(trimmed.runes.first).toUpperCase();
    }
    final fallback = staff.initials?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      return String.fromCharCode(fallback.runes.first).toUpperCase();
    }
    return '?';
  }

  void _selectFlexibleStaff() {
    setState(() {
      _personnelId = null;
      _staffPick = null;
      _slot = null;
      _slotStaffId = null;
      _slotStaffName = null;
    });
  }

  void _selectStaff(StaffMember staff) {
    setState(() {
      _personnelId = staff.id;
      _staffPick = staff;
      _slot = null;
      _slotStaffId = null;
      _slotStaffName = null;
    });
  }

  void _selectSlot(TimeSlot slot, {SlotStaffMini? staff}) {
    setState(() {
      _slot = slot;
      if (_personnelId == null) {
        _slotStaffId = staff?.id;
        _slotStaffName = staff?.name;
      } else {
        _slotStaffId = null;
        _slotStaffName = null;
      }
    });
  }

  Future<void> _waitlistDialog() async {
    final svc = _service;
    if (svc == null) return;
    final nameCtl = TextEditingController(text: _fullName.text);
    final phoneCtl = TextEditingController(text: _phone.text);
    final emailCtl = TextEditingController(text: _email.text);
    final notesCtl = TextEditingController();
    const anytime = 'Farketmez';
    const morning = 'Sabah';
    const noon = 'Ogle';
    const evening = 'Aksam';
    var slotPref = anytime;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(context.tr(
            'salon.mobile.booking.waitlist.title',
            'Bekleme listesi',
          )),
          content: StatefulBuilder(
            builder: (context, setLocal) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: nameCtl,
                        decoration: InputDecoration(
                          labelText: context.tr(
                            'salon.mobile.auth.fields.fullName',
                            'Ad Soyad',
                          ),
                        )),
                    TextField(
                        controller: phoneCtl,
                        decoration: InputDecoration(
                          labelText: context.tr(
                            'salon.mobile.auth.fields.phone',
                            'Telefon',
                          ),
                        )),
                    TextField(
                        controller: emailCtl,
                        decoration: InputDecoration(
                          labelText: context.tr(
                            'salon.mobile.auth.fields.email',
                            'E-posta',
                          ),
                        )),
                    DropdownButtonFormField<String>(
                      initialValue: slotPref,
                      items: [
                        DropdownMenuItem(
                            value: anytime,
                            child: Text(context.tr(
                              'salon.mobile.booking.waitlist.anytime',
                              'Fark etmez',
                            ))),
                        DropdownMenuItem(
                            value: morning,
                            child: Text(context.tr(
                              'salon.mobile.booking.waitlist.morning',
                              'Sabah',
                            ))),
                        DropdownMenuItem(
                            value: noon,
                            child: Text(context.tr(
                              'salon.mobile.booking.waitlist.noon',
                              'Öğle',
                            ))),
                        DropdownMenuItem(
                            value: evening,
                            child: Text(context.tr(
                              'salon.mobile.booking.waitlist.evening',
                              'Akşam',
                            ))),
                      ],
                      onChanged: (v) =>
                          setLocal(() => slotPref = v ?? anytime),
                      decoration: InputDecoration(
                        labelText: context.tr(
                          'salon.mobile.booking.waitlist.timePreference',
                          'Saat tercihi',
                        ),
                      ),
                    ),
                    TextField(
                        controller: notesCtl,
                        decoration: InputDecoration(
                          labelText: context.tr(
                            'salon.mobile.booking.waitlist.note',
                            'Not',
                          ),
                        )),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.tr('salon.mobile.common.cancel', 'Vazgeç'))),
            FilledButton(
              onPressed: () async {
                if (nameCtl.text.trim().isEmpty ||
                    phoneCtl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr(
                        'salon.mobile.booking.waitlist.namePhoneRequired',
                        'Ad ve telefon zorunlu.',
                      )),
                    ),
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
                      SnackBar(
                        content: Text(context.tr(
                          'salon.mobile.booking.waitlist.added',
                          'Listeye eklendi',
                        )),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(dioErrorMessage(e))));
                  }
                }
              },
              child: Text(context.tr('salon.mobile.common.save', 'Kaydet')),
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
        body: Center(
          child: Text(context.tr(
            'salon.mobile.booking.disabled',
            'Bu salon online randevuyu kapalı tutuyor.',
          )),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(
          'salon.mobile.booking.titleWithSalon',
          'Randevu · {salon}',
        ).replaceFirst('{salon}', profile.salonName)),
      ),
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
                      context.tr(
                        'salon.mobile.booking.stepCounter',
                        'Adım {current} / {total}',
                      )
                          .replaceFirst('{current}', '${_step + 1}')
                          .replaceFirst('{total}', '5'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    Text(
                      _stepTitle(_step),
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
                TextButton(
                  onPressed: _back,
                  child: Text(context.tr('salon.mobile.common.back', 'Geri')),
                ),
                const Spacer(),
                if (_step < 4)
                  FilledButton(
                      onPressed: _canNext() ? _next : null,
                      child: Text(context.tr('salon.mobile.common.next', 'İleri'))),
                if (_step == 4)
                  FilledButton(
                    onPressed: (_saving || !_canNext()) ? null : _confirm,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.tr('salon.mobile.booking.bookNow', 'Randevu al')),
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
                      subtitle: Text(context.tr(
                        'salon.mobile.common.minutes',
                        '{count} dk',
                      ).replaceFirst('{count}', '${s.durationMinutes}')),
                      trailing: Text(_money.format(s.price)),
                      onTap: () => setState(() {
                        _service = s;
                        _staff = [];
                        _staffPick = null;
                        _personnelId = null;
                        _slots = [];
                        _slotsLoaded = false;
                        _slot = null;
                        _slotStaffId = null;
                        _slotStaffName = null;
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
                title: Text(context.tr('salon.mobile.booking.staffFlexible', 'Fark etmez')),
                subtitle: Text(context.tr(
                  'salon.mobile.booking.staffFlexibleHint',
                  'Saat ekranında müsait personeli seçin',
                )),
                onTap: _selectFlexibleStaff,
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
                  onTap: () => _selectStaff(st),
                ),
              ),
            if (_staff.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr(
                    'salon.mobile.booking.noStaffForService',
                    'Bu hizmet için listelenen personel yok.',
                  ),
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
              title: Text(context.tr('salon.mobile.booking.date', 'Tarih')),
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
                  title: Text(context.tr(
                    'salon.mobile.booking.dayClosed',
                    'Salon bugün kapalı. Başka bir tarih seçin.',
                  )),
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
              Text(context.tr(
                'salon.mobile.booking.noSlotForDate',
                'Bu tarih için müsait slot yok.',
              )),
              TextButton.icon(
                onPressed: _waitlistDialog,
                icon: const Icon(Icons.notifications),
                label: Text(context.tr(
                  'salon.mobile.booking.joinWaitlist',
                  'Bekleme listesine yazıl',
                )),
              ),
            ],
            if (_slotsLoaded && !_dayClosed && _slots.isNotEmpty) ...[
              if (_personnelId == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.tr(
                      'salon.mobile.booking.flexibleStaffHint',
                      'Aynı saatte birden fazla personel müsaitse saat ayrı ayrı görünür; harf personeli belirtir.',
                    ),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13),
                  ),
                ),
              if (_personnelId != null)
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              backgroundColor: sel
                                  ? scheme.primaryContainer
                                  : scheme.surface,
                              foregroundColor: sel
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurface,
                              side: BorderSide(
                                  color: sel ? scheme.primary : scheme.outline),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _selectSlot(sl),
                            child: Text(sl.timeText),
                          );
                        },
                      ),
                  ],
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final sl in _slots)
                      for (final staff in sl.availableStaff)
                        Builder(
                          builder: (ctx) {
                            final scheme = Theme.of(ctx).colorScheme;
                            final sel = _slot?.startTime == sl.startTime &&
                                _slotStaffId == staff.id;
                            return Tooltip(
                              message: staff.name,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(96, 44),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  backgroundColor: sel
                                      ? scheme.primaryContainer
                                      : scheme.surface,
                                  foregroundColor: sel
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurface,
                                  side: BorderSide(
                                      color: sel
                                          ? scheme.primary
                                          : scheme.outline),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _selectSlot(sl, staff: staff),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(sl.timeText),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 22,
                                      height: 22,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: sel
                                            ? scheme.primary
                                            : scheme.surfaceContainerHighest,
                                      ),
                                      child: Text(
                                        _staffSymbol(staff),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: sel
                                              ? scheme.onPrimary
                                              : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
              decoration: InputDecoration(
                  labelText: context.tr(
                    'salon.mobile.auth.fields.fullNameRequired',
                    'Ad Soyad *',
                  ),
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  labelText: context.tr(
                    'salon.mobile.auth.fields.phoneRequired',
                    'Telefon *',
                  ),
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                  labelText: context.tr('salon.mobile.auth.fields.email', 'E-posta'),
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: context.tr('salon.mobile.booking.notes', 'Notlar'),
                  border: const OutlineInputBorder()),
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
            Text(
              context.tr(
                'salon.mobile.booking.summary.service',
                'Hizmet: {service}',
              ).replaceFirst('{service}', svc.name),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              context.tr(
                'salon.mobile.booking.summary.date',
                'Tarih: {date} - {time}',
              )
                  .replaceFirst('{date}', DateFormat.yMMMMEEEEd('tr').format(_selectedDay))
                  .replaceFirst('{time}', slot.timeText),
            ),
            Text(context.tr(
              'salon.mobile.booking.summary.staff',
              'Personel: {staff}',
            ).replaceFirst('{staff}', _confirmedStaffLabel())),
            Text(context.tr(
              'salon.mobile.booking.summary.price',
              'Ücret: {price}',
            ).replaceFirst('{price}', _money.format(svc.price))),
            const Divider(height: 24),
            Text(context.tr(
              'salon.mobile.booking.summary.guest',
              'Misafir: {name} - {phone}',
            )
                .replaceFirst('{name}', _fullName.text)
                .replaceFirst('{phone}', _phone.text)),
            if (pol != null && pol.hasPolicy) ...[
              const SizedBox(height: 16),
              Text(
                context.tr('salon.mobile.booking.summary.policy', 'Politika'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (pol.requireDeposit && pol.depositAmount > 0)
                Text(context.tr(
                  'salon.mobile.booking.summary.deposit',
                  'Depozito: {amount}',
                ).replaceFirst('{amount}', _money.format(pol.depositAmount))),
              if (pol.freeCancellationHours > 0)
                Text(context.tr(
                  'salon.mobile.booking.summary.freeCancellation',
                  'Ücretsiz iptal: {hours} saat öncesine kadar',
                ).replaceFirst('{hours}', '${pol.freeCancellationHours}')),
              if (pol.noShowFee > 0)
                Text(context.tr(
                  'salon.mobile.booking.summary.noShowFee',
                  'Gelmeme: {amount}',
                ).replaceFirst('{amount}', _money.format(pol.noShowFee))),
            ],
            if ((pol?.depositAmount ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  context.tr(
                    'salon.mobile.booking.summary.depositRedirect',
                    'Depozitolu randevuda güvenli ödeme sayfasına yönlendirileceksiniz.',
                  ),
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
