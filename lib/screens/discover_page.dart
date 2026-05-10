import 'package:callcenter_salon_mobil/config/app_config.dart';
import 'package:callcenter_salon_mobil/constants/app_audience.dart';
import 'package:callcenter_salon_mobil/models/platform_models.dart';
import 'package:callcenter_salon_mobil/screens/login_page.dart';
import 'package:callcenter_salon_mobil/screens/salon_profile_page.dart';
import 'package:callcenter_salon_mobil/services/corp_api.dart';
import 'package:callcenter_salon_mobil/state/session_state.dart';
import 'package:callcenter_salon_mobil/util/api_errors.dart';
import 'package:callcenter_salon_mobil/util/haversine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

/// Web `Discover.cshtml` ile aynı davranış: OSM harita, konum (5 sn), 5 km pin/liste,
/// arama, şube kartları (`GET /api/salon` + `GET /api/salon/branches-map`).
///
/// [includeBookingSlugRail]: Paylaşılan linkten slug bilen kullanıcılar için (Randevu sekmesiyle aynı ekran).
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key, this.includeBookingSlugRail = true});

  final bool includeBookingSlugRail;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const double _maxRadiusKm = 5;
  static final LatLng _turkeyCenter = LatLng(39.9, 32.8);

  final _search = TextEditingController();
  final _slugCtl = TextEditingController();
  final _mapController = MapController();

  bool _slugBookingBusy = false;
  bool _salonsLoading = true;
  bool _locationPending = true;
  double? _userLat;
  double? _userLng;
  List<PublishedBranchItem> _salons = [];
  List<PublishedBranchMapPin> _mapPins = [];
  String? _error;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _bootstrapped) return;
      _bootstrapped = true;
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _slugCtl.dispose();
    super.dispose();
  }

  /// Slug'la salonu açar — profil sayfasına gider, login zorunlu değil
  /// (login profil içindeki Randevu al CTA'sından booking adımında istenir).
  Future<void> _openSalonBySlug(String slug, {bool showSlugBusy = false}) async {
    if (slug.isEmpty) return;
    if (showSlugBusy) setState(() => _slugBookingBusy = true);
    try {
      await context.read<CorpApiClient>().fetchSalonProfile(slug);
      if (!mounted) return;
      if (showSlugBusy) setState(() => _slugBookingBusy = false);
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => SalonProfilePage(slug: slug)),
      );
    } catch (e) {
      if (mounted) {
        if (showSlugBusy) setState(() => _slugBookingBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
      }
    }
  }

  Future<void> _openSalonFromSlugInput() async {
    final slug = _slugCtl.text.trim();
    if (slug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salon kısa adresini girin veya listeden / haritadan seçin.')),
      );
      return;
    }
    await _openSalonBySlug(slug, showSlugBusy: true);
  }

  Future<void> _recenterOnDeviceLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konum izni gerekli. Ayarlardan izin verebilirsiniz.')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: Duration(seconds: 10)),
      );
      if (!mounted) return;
      setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
        _locationPending = false;
      });
      _mapController.move(LatLng(pos.latitude, pos.longitude), 14);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum alınamadı. GPS açık mı kontrol edin.')),
        );
      }
    }
  }

  Future<void> _showSalonPinSheet(PublishedBranchMapPin pin) async {
    PublishedBranchItem? match;
    for (final s in _salons) {
      if (s.slug == pin.slug) {
        match = s;
        break;
      }
    }

    final title =
        pin.branchName.trim().isNotEmpty ? pin.branchName.trim() : pin.salonName;
    final subtitle = pin.branchName.trim().isNotEmpty &&
            pin.salonName.trim().isNotEmpty &&
            pin.branchName.trim() != pin.salonName.trim()
        ? pin.salonName
        : null;
    final loc = [
      if ((pin.district ?? '').isNotEmpty) pin.district,
      if ((pin.city ?? '').isNotEmpty) pin.city,
    ].join(', ');

    double? pinKm;
    final uLat = _userLat;
    final uLng = _userLng;
    if (uLat != null && uLng != null && pin.latitude != 0 && pin.longitude != 0) {
      pinKm = haversineKm(uLat, uLng, pin.latitude, pin.longitude);
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                  ),
                if (loc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.place_outlined, size: 18, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(child: Text(loc, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13))),
                      ],
                    ),
                  ),
                if (pinKm != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      distanceLabelKm(pinKm),
                      style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: pin.slug.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          if (match != null) {
                            await _openSalon(match);
                          } else {
                            await _openSalonBySlug(pin.slug);
                          }
                        },
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Salonu aç'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _bootstrap() async {
    await Future.wait<void>([
      _loadSalonsAndPins(),
      _initLocation(),
    ]);
  }

  Future<void> _reloadAll() async {
    setState(() {
      _salonsLoading = true;
      _error = null;
    });
    await _loadSalonsAndPins();
  }

  Future<void> _loadSalonsAndPins() async {
    try {
      final api = context.read<CorpApiClient>();
      final salons = await api.fetchPublishedBranches();
      final pins = await api.fetchBranchesMapPins();
      if (!mounted) return;
      setState(() {
        _salons = salons;
        _mapPins = pins;
        _salonsLoading = false;
      });
      _maybeCenterOnFirstPin();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = dioErrorMessage(e);
          _salonsLoading = false;
        });
      }
    }
  }

  Future<void> _initLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationPending = false);
        _maybeCenterOnFirstPin();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (!mounted) return;
      setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
        _locationPending = false;
      });
      _mapController.move(LatLng(pos.latitude, pos.longitude), 13);
    } catch (_) {
      if (mounted) setState(() => _locationPending = false);
      _maybeCenterOnFirstPin();
    }
  }

  void _maybeCenterOnFirstPin() {
    if (!mounted || _locationPending) return;
    if (_userLat != null) return;
    if (_mapPins.isEmpty) return;
    final pin = _mapPins.firstWhere(
      (p) => p.latitude != 0 && p.longitude != 0,
      orElse: () => _mapPins.first,
    );
    _mapController.move(LatLng(pin.latitude, pin.longitude), 12);
  }

  void _onMapTap(TapPosition tap, LatLng ll) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konum'),
        content: const Text('Konumunuzu buraya taşımak ister misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hayır')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _userLat = ll.latitude;
                _userLng = ll.longitude;
                _locationPending = false;
              });
              _mapController.move(ll, 13);
            },
            child: const Text('Evet, buraya taşı'),
          ),
        ],
      ),
    );
  }

  void _onPinTapped(PublishedBranchMapPin pin) {
    _showSalonPinSheet(pin);
  }

  List<_EnrichedBranch> _filteredList() {
    if (_locationPending) return [];

    final q = normalizeForSearch(_search.text.trim());
    final uLat = _userLat;
    final uLng = _userLng;

    var enriched = _salons.where((s) => s.slug.isNotEmpty).map((s) {
      double? d;
      if (uLat != null && uLng != null && s.latitude != null && s.longitude != null) {
        d = haversineKm(uLat, uLng, s.latitude!, s.longitude!);
      }
      return _EnrichedBranch(s, d);
    }).toList();

    if (q.isNotEmpty) {
      enriched = enriched.where((e) {
        final s = e.item;
        final name = normalizeForSearch(s.branchName);
        final salon = normalizeForSearch(s.salonName);
        final city = normalizeForSearch(s.city ?? '');
        final dist = normalizeForSearch(s.district ?? '');
        return name.contains(q) || salon.contains(q) || city.contains(q) || dist.contains(q);
      }).toList();
    } else if (uLat != null) {
      enriched = enriched
          .where((e) => e.distanceKm == null || e.distanceKm! <= _maxRadiusKm)
          .toList();
    }

    if (uLat != null) {
      enriched.sort((a, b) {
        if (a.distanceKm == null && b.distanceKm == null) return 0;
        if (a.distanceKm == null) return 1;
        if (b.distanceKm == null) return -1;
        return a.distanceKm!.compareTo(b.distanceKm!);
      });
    } else if (q.isEmpty) {
      enriched.sort((a, b) => a.item.displayTitle.toLowerCase().compareTo(b.item.displayTitle.toLowerCase()));
    }

    return enriched;
  }

  List<Marker> _mapMarkers() {
    final markers = <Marker>[];
    final uLat = _userLat;
    final uLng = _userLng;
    for (final pin in _mapPins) {
      if (pin.slug.isEmpty || (pin.latitude == 0 && pin.longitude == 0)) continue;
      if (uLat != null && uLng != null) {
        final d = haversineKm(uLat, uLng, pin.latitude, pin.longitude);
        if (d > _maxRadiusKm) continue;
      }
      markers.add(
        Marker(
          point: LatLng(pin.latitude, pin.longitude),
          width: 40,
          height: 40,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _onPinTapped(pin),
            child: const Icon(Icons.location_on, color: Color(0xFF7B1FA2), size: 40),
          ),
        ),
      );
    }

    if (_userLat != null && _userLng != null) {
      markers.add(
        Marker(
          point: LatLng(_userLat!, _userLng!),
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  /// Şube kartına tıklayınca profil sayfası açılır; login profil içindeki
  /// Randevu al CTA'sından booking adımında istenir.
  Future<void> _openSalon(PublishedBranchItem b) async {
    if (b.slug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu şube için kısa adres (slug) tanımlı değil.')),
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => SalonProfilePage(slug: b.slug)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    const gradStart = Color(0xFF2D1B3D);
    const gradEnd = Color(0xFF4A1A6B);
    const headerMuted = Color(0xFFCE93D8);
    const mapBorder = Color(0xFF7B1FA2);

    final filtered = _filteredList();
    final showBlockingSpinner = _salonsLoading || _locationPending;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _reloadAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [gradStart, gradEnd],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.content_cut, color: headerMuted, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      children: [
                                        const TextSpan(text: 'CorpLynk '),
                                        TextSpan(text: 'Salon', style: TextStyle(color: headerMuted)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Harita ile yakınınızdaki salonlar · liste ve slug ile randevu',
                                    style: TextStyle(fontSize: 12, color: headerMuted.withValues(alpha: 0.95)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Yenile',
                              onPressed: _salonsLoading ? null : _reloadAll,
                              icon: _salonsLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.refresh, color: Colors.white),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: session.isLoggedIn
                                ? null
                                : () => Navigator.push<void>(
                                      context,
                                      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                                    ),
                            icon: Icon(
                              session.isLoggedIn ? Icons.check_circle_outline : Icons.login,
                              size: 18,
                              color: session.isLoggedIn ? headerMuted : Colors.white70,
                            ),
                            label: Text(
                              session.isLoggedIn ? 'Oturum açık' : 'Giriş yap',
                              style: TextStyle(
                                color: session.isLoggedIn ? headerMuted : Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                height: 400,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: mapBorder, width: 3)),
                ),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _turkeyCenter,
                          initialZoom: 6,
                          onTap: _onMapTap,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.drag |
                                InteractiveFlag.pinchZoom |
                                InteractiveFlag.doubleTapZoom |
                                InteractiveFlag.scrollWheelZoom,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: AppConfig.mapTileUrl,
                            userAgentPackageName: AppConfig.mapTileUserAgent,
                          ),
                          MarkerLayer(markers: _mapMarkers()),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            AppConfig.mapTileAttribution,
                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Material(
                        elevation: 4,
                        shape: const CircleBorder(),
                        color: Theme.of(context).colorScheme.surface,
                        clipBehavior: Clip.antiAlias,
                        child: IconButton(
                          tooltip: 'Konumuma git',
                          onPressed: _recenterOnDeviceLocation,
                          icon: Icon(Icons.my_location, color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Salonlar',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${filtered.length})',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        hintText: 'Salon veya şehir ara…',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.search,
                    ),
                  ],
                ),
              ),
            ),
            if (showBlockingSpinner && _error == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 14),
                      Text(
                        _salonsLoading && _locationPending
                            ? 'Salonlar ve konum yükleniyor…'
                            : _locationPending
                                ? 'Konumunuz belirleniyor…'
                                : 'Salonlar yükleniyor…',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_userLat != null && _userLng != null && _search.text.trim().isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Konumunuza göre ${_maxRadiusKm.toStringAsFixed(0)} km içindeki şubeler öncelikli (web Discover ile aynı).',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ),
            if (!_salonsLoading && !_locationPending && _salons.isEmpty && _error == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Salon bulunamadı.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            if (!_locationPending && _salons.isNotEmpty && filtered.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Aramanızla eşleşen şube yok veya yakınınızda kayıt yok.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final e = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BranchDiscoverCard(
                        item: e.item,
                        distanceText: distanceLabelKm(e.distanceKm),
                        onOpen: () => _openSalon(e.item),
                      ),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
            if (widget.includeBookingSlugRail)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.link, color: Theme.of(context).colorScheme.primary, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Link bilgisinden randevu',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Paylaşılan bağlantıdaki kısa adresi yazın (ör. …/salon/benim-sube için benim-sube). '
                            'Haritadan seçmek istemezseniz buradan da randevuya gidebilirsiniz.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              AppAudience.notSalonStaffNotice,
                              style: TextStyle(fontSize: 12, height: 1.35),
                            ),
                          ),
                          TextField(
                            controller: _slugCtl,
                            textInputAction: TextInputAction.go,
                            autocorrect: false,
                            onSubmitted: (_) => _openSalonFromSlugInput(),
                            decoration: const InputDecoration(
                              labelText: 'Salon kısa adresi (slug)',
                              hintText: 'ornek-sube',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _slugBookingBusy ? null : _openSalonFromSlugInput,
                            icon: _slugBookingBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.storefront_outlined),
                            label: Text(_slugBookingBusy ? 'Kontrol…' : 'Salonu aç'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EnrichedBranch {
  _EnrichedBranch(this.item, this.distanceKm);
  final PublishedBranchItem item;
  final double? distanceKm;
}

class _BranchDiscoverCard extends StatelessWidget {
  const _BranchDiscoverCard({
    required this.item,
    required this.onOpen,
    required this.distanceText,
  });

  final PublishedBranchItem item;
  final VoidCallback onOpen;
  final String distanceText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = [
      if ((item.district ?? '').isNotEmpty) item.district,
      if ((item.city ?? '').isNotEmpty) item.city,
    ].join(', ');
    final desc = (item.description ?? '').trim();
    final descText = desc.isEmpty ? 'Açıklama henüz eklenmemiş.' : desc;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.logoUrl != null && item.logoUrl!.isNotEmpty)
                CircleAvatar(radius: 28, backgroundImage: NetworkImage(item.logoUrl!))
              else
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.surfaceContainerHighest,
                  child: Icon(Icons.storefront_outlined, color: scheme.onSurfaceVariant),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.displayTitle,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (item.showSalonSubtitle)
                                Text(
                                  item.salonName,
                                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                        if (distanceText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                distanceText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          )
                        else if (item.isHeadquarter)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              'Merkez',
                              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                    if (item.reviewCount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                          Text(
                            ' ${item.averageRating.toStringAsFixed(1)} ',
                            style: const TextStyle(fontSize: 13, color: Color(0xFFF59E0B)),
                          ),
                          Text(
                            '(${item.reviewCount} yorum)',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      descText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.25),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            loc.isEmpty ? 'Konum belirtilmemiş' : loc,
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    if ((item.priceRange ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.priceRange!,
                        style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> ensureDiscoverLogin(BuildContext context) async {
  final session = context.read<SessionState>();
  if (session.isLoggedIn) return true;
  await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  if (!context.mounted) return false;
  return context.read<SessionState>().isLoggedIn;
}
