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
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.salonName, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('${dateFmt.format(a.appointmentDate)} · ${a.startLabel} — ${a.endLabel}'),
                    if (services.isNotEmpty) Text(services, style: const TextStyle(color: Colors.black54)),
                    if (a.personnelName != null && a.personnelName!.isNotEmpty)
                      Text('Personel: ${a.personnelName}', style: const TextStyle(fontSize: 13)),
                    if (a.totalPrice > 0) Text('${a.totalPrice.toStringAsFixed(2)} TL'),
                    if (allowCancel)
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
