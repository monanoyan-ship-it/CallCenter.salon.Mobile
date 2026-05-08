import 'package:callcenter_salon_mobil/models/booking_models.dart';
import 'package:callcenter_salon_mobil/services/corp_api.dart';
import 'package:callcenter_salon_mobil/util/api_errors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Web `/user/panel` → Randevularım sekmesi ile aynı API: `GET /api/platform/appointments`.
class PlatformAppointmentsTab extends StatefulWidget {
  const PlatformAppointmentsTab({super.key});

  @override
  State<PlatformAppointmentsTab> createState() => _PlatformAppointmentsTabState();
}

class _PlatformAppointmentsTabState extends State<PlatformAppointmentsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _fmt = DateFormat.yMMMEd('tr');
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<List<PlatformAppointment>> _load(bool past) {
    return context.read<CorpApiClient>().fetchMyAppointments(past: past);
  }

  Future<void> _cancel(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İptal'),
        content: const Text('Bu randevuyu iptal etmek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('İptal et')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<CorpApiClient>().cancelAppointment(id);
      setState(() => _epoch++);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Yaklaşan'),
            Tab(text: 'Geçmiş'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _AppointmentList(
                key: ValueKey('up-$_epoch'),
                loader: () => _load(false),
                onCancel: _cancel,
                allowCancel: true,
                dateFmt: _fmt,
              ),
              _AppointmentList(
                key: ValueKey('past-$_epoch'),
                loader: () => _load(true),
                onCancel: _cancel,
                allowCancel: false,
                dateFmt: _fmt,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppointmentList extends StatelessWidget {
  const _AppointmentList({
    super.key,
    required this.loader,
    required this.onCancel,
    required this.allowCancel,
    required this.dateFmt,
  });

  final Future<List<PlatformAppointment>> Function() loader;
  final Future<void> Function(int id) onCancel;
  final bool allowCancel;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PlatformAppointment>>(
      future: loader(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Yüklenemedi: ${dioErrorMessage(snap.error!)}'));
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('Randevu bulunamadı.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final a = items[i];
            final services = a.serviceNames.join(', ');
            final scheme = Theme.of(context).colorScheme;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            a.salonName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        _StatusBadge(appointment: a),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${dateFmt.format(a.appointmentDate)} · ${a.startLabel} — ${a.endLabel}'),
                    if (services.isNotEmpty)
                      Text(services, style: TextStyle(color: scheme.onSurfaceVariant)),
                    if (a.personnelName != null && a.personnelName!.isNotEmpty)
                      Text('Personel: ${a.personnelName}', style: const TextStyle(fontSize: 13)),
                    if (a.totalPrice > 0)
                      Text(
                        a.isPrepaid && a.prepaidAmount > 0
                            ? '${a.totalPrice.toStringAsFixed(2)} TL · ${a.prepaidAmount.toStringAsFixed(2)} TL ödendi'
                            : '${a.totalPrice.toStringAsFixed(2)} TL',
                      ),
                    if (a.awaitsSalonApproval)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Salon randevunuzu onayladığında bilgilendirileceksiniz.',
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    if (allowCancel && !a.isCancelled)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => onCancel(a.id),
                          child: const Text('İptal et'),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.appointment});
  final PlatformAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    if (appointment.isCancelled) {
      bg = scheme.errorContainer;
      fg = scheme.onErrorContainer;
    } else if (appointment.isCompleted) {
      bg = scheme.surfaceContainerHighest;
      fg = scheme.onSurfaceVariant;
    } else if (appointment.isConfirmed) {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF065F46);
    } else if (appointment.awaitsSalonApproval) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    } else {
      bg = scheme.primaryContainer;
      fg = scheme.onPrimaryContainer;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        appointment.statusLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
