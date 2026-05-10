import 'package:callcenter_salon_mobil/config/app_config.dart';
import 'package:callcenter_salon_mobil/models/booking_models.dart';
import 'package:callcenter_salon_mobil/screens/booking_wizard_page.dart';
import 'package:callcenter_salon_mobil/screens/gallery_viewer_page.dart';
import 'package:callcenter_salon_mobil/screens/login_page.dart';
import 'package:callcenter_salon_mobil/screens/payment_webview_page.dart';
import 'package:callcenter_salon_mobil/services/corp_api.dart';
import 'package:callcenter_salon_mobil/state/app_localization_state.dart';
import 'package:callcenter_salon_mobil/state/session_state.dart';
import 'package:callcenter_salon_mobil/util/api_errors.dart';
import 'package:callcenter_salon_mobil/widgets/responsive_center.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web `Profile.cshtml` ile aynı içerik, mobil tek-kolon: `GET /api/salon/{slug}`
/// + opsiyonel `team` / `reviews` / `memberships`. Sıralama
/// `sectionOrderJson`'a, görünürlük `show*` flag'lerine bağlı.
class SalonProfilePage extends StatefulWidget {
  const SalonProfilePage({super.key, required this.slug});

  final String slug;

  @override
  State<SalonProfilePage> createState() => _SalonProfilePageState();
}

class _SalonProfilePageState extends State<SalonProfilePage> {
  static final NumberFormat _money =
      NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);

  bool _loading = true;
  String? _error;
  SalonProfile? _profile;
  List<TeamMember> _team = const [];
  ReviewsResponse? _reviews;
  List<SalonMembership> _memberships = const [];

  List<SalonBanner> _banners = const [];
  List<String> _gallery = const [];
  List<WorkingHourEntry> _hours = const [];
  List<String> _sectionOrder = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<CorpApiClient>();
      final profile = await api.fetchSalonProfile(widget.slug);
      if (!mounted) return;

      final banners = profile.showBanners
          ? parseBanners(profile.bannersJson)
          : const <SalonBanner>[];
      final gallery = parseGalleryImages(profile.galleryImagesJson);
      final hours = parseWorkingHours(profile.workingHoursJson);
      final sectionOrder = parseSectionOrder(profile.sectionOrderJson);

      final teamFut = profile.showTeam
          ? api.fetchSalonTeam(widget.slug).catchError(
                (_) => const <TeamMember>[],
              )
          : Future<List<TeamMember>>.value(const []);
      final reviewsFut = profile.showReviews
          ? api
              .fetchSalonReviews(widget.slug)
              .then<ReviewsResponse?>((v) => v)
              .catchError((_) => null)
          : Future<ReviewsResponse?>.value(null);
      final memberFut = profile.showMemberships
          ? api.fetchSalonMemberships(widget.slug).catchError(
                (_) => const <SalonMembership>[],
              )
          : Future<List<SalonMembership>>.value(const []);

      final team = await teamFut;
      final reviews = await reviewsFut;
      final memberships = await memberFut;
      if (!mounted) return;

      setState(() {
        _profile = profile;
        _team = team;
        _reviews = reviews;
        _memberships = memberships;
        _banners = banners;
        _gallery = gallery;
        _hours = hours;
        _sectionOrder = sectionOrder;
        _loading = false;
      });
      if (kDebugMode) {
        final orderedDebug = _buildOrderedSections(profile);
        final hoursOpenDays = hours.where((h) => !h.isClosed).length;
        debugPrint(
          '[salon-profile] slug=${profile.slug} '
          'orderedSectionsRendered=${orderedDebug.length} '
          'sectionOrder=${sectionOrder.length} '
          'cats=${profile.categories.length} '
          'team=${team.length} '
          'reviews=${reviews?.reviews.length ?? 0} '
          'memberships=${memberships.length} '
          'banners=${banners.length} '
          'gallery=${gallery.length} '
          'hoursOpenDays=$hoursOpenDays '
          'show: services=${profile.showServices} memberships=${profile.showMemberships} '
          'team=${profile.showTeam} reviews=${profile.showReviews} '
          'hours=${profile.showHours} contact=${profile.showContact} map=${profile.showMap}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = dioErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _openBooking() async {
    final p = _profile;
    if (p == null || !p.showBooking) return;
    final session = context.read<SessionState>();
    if (!session.isLoggedIn) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (!mounted) return;
      if (!context.read<SessionState>().isLoggedIn) return;
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => BookingWizardPage(slug: p.slug)),
    );
  }

  /// Yorum yaz CTA'sına dokununca: login yoksa al, sonra form bottom sheet.
  /// Submit sonrası backend `status=Bekliyor` döner; onaylanana kadar listede görünmez.
  Future<void> _handleReviewWrite(SalonProfile profile) async {
    final session = context.read<SessionState>();
    if (!session.isLoggedIn) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (!mounted) return;
      if (!context.read<SessionState>().isLoggedIn) return;
    }
    if (!mounted) return;
    final user = context.read<SessionState>().user;
    final review = await showModalBottomSheet<PlatformReview>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReviewWriteSheet(
        slug: profile.slug,
        defaultDisplayName: user?.fullName,
      ),
    );
    if (!mounted || review == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.trRead(
            'salon.mobile.profile.reviews.received',
            'Yorumunuz alındı, salon onayından sonra listede görünecek.',
          ),
        ),
      ),
    );
  }

  /// Üyelik kartına dokununca: ücretsizse direkt form, ücretliyse önce login,
  /// signup → checkout → PaymentWebViewPage akışı.
  Future<void> _handleMembershipTap(SalonProfile profile, SalonMembership plan) async {
    final paid = plan.price > 0;
    if (paid) {
      final session = context.read<SessionState>();
      if (!session.isLoggedIn) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
        if (!mounted) return;
        if (!context.read<SessionState>().isLoggedIn) return;
      }
    }
    if (!mounted) return;
    final user = context.read<SessionState>().user;
    final result = await showModalBottomSheet<MembershipSignupResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MembershipSignupSheet(
        plan: plan,
        slug: profile.slug,
        prefillName: user?.fullName,
        prefillPhone: user?.phone,
        prefillEmail: user?.email,
        money: _money,
      ),
    );
    if (!mounted || result == null) return;

    if (result.requiresPayment && result.slnClientId != null && result.planId != null) {
      try {
        final api = context.read<CorpApiClient>();
        final checkout = await api.payMembershipCheckout(
          planId: result.planId!,
          slnClientId: result.slnClientId!,
          slug: profile.slug,
        );
        if (!mounted) return;
        if (checkout.htmlContent.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.trRead(
                'salon.mobile.profile.membership.htmlMissing',
                'Ödeme formu alınamadı.',
              )),
            ),
          );
          return;
        }
        final paid = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentWebViewPage(htmlContent: checkout.htmlContent),
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(paid == true
                ? context.trRead(
                    'salon.mobile.profile.membership.paymentSuccess',
                    'Ödeme alındı, üyeliğiniz aktif.',
                  )
                : context.trRead(
                    'salon.mobile.profile.membership.paymentIncomplete',
                    'Ödeme tamamlanmadı.',
                  )),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dioErrorMessage(e))),
        );
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ??
            context.trRead(
              'salon.mobile.profile.membership.received',
              'Üyelik başvurunuz alındı.',
            )),
      ),
    );
  }

  Future<void> _launch(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.trRead(
              'salon.mobile.profile.linkOpenFailed',
              'Açılamadı: {uri}',
            ).replaceFirst('{uri}', uri.toString())),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.trRead(
              'salon.mobile.profile.linkOpenFailed',
              'Açılamadı: {uri}',
            ).replaceFirst('{uri}', uri.toString())),
          ),
        );
      }
    }
  }

  void _openExternalMaps(SalonProfile p) {
    final lat = p.latitude;
    final lng = p.longitude;
    final explicit = p.googleMapsUrl?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      final uri = Uri.tryParse(explicit);
      if (uri != null) {
        _launch(uri);
        return;
      }
    }
    if (lat != null && lng != null) {
      _launch(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('salon.mobile.profile.title', 'Salon'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('salon.mobile.profile.title', 'Salon'))),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _bootstrap,
                icon: const Icon(Icons.refresh),
                label: Text(context.tr('salon.mobile.common.retry', 'Tekrar dene')),
              ),
            ],
          ),
        ),
      );
    }
    final p = _profile!;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: RefreshIndicator(
        onRefresh: _bootstrap,
        child: ResponsiveCenter(
          child: Builder(builder: (context) {
            final orderedSections = _buildOrderedSections(p);
            final hoursOpenDays = _hours.where((h) => !h.isClosed).length;
            final hasContact = (p.phone ?? '').isNotEmpty ||
                (p.email ?? '').isNotEmpty ||
                (p.address ?? '').isNotEmpty ||
                (p.website ?? '').isNotEmpty ||
                (p.instagramHandle ?? '').isNotEmpty ||
                (p.facebookUrl ?? '').isNotEmpty;
            final showHoursSection = hoursOpenDays > 0;
            final showContactSection = hasContact;
            final hasAnyContent =
                orderedSections.isNotEmpty || showHoursSection || showContactSection;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                _HeroSection(
                  profile: p,
                  reviewStats: _reviews?.stats,
                ),
                if (!hasAnyContent) _EmptyProfileNotice(profile: p),
                ...orderedSections,
                if (showHoursSection) _HoursSection(hours: _hours),
                if (showContactSection) _ContactSection(profile: p, onLaunch: _launch),
                const SizedBox(height: 24),
              ],
            );
          }),
        ),
      ),
      bottomNavigationBar: p.showBooking
          ? ResponsiveCenter(
              expandHeight: false,
              child: _BottomBookCta(onTap: _openBooking),
            )
          : null,
    );
  }

  /// Section render kuralı: data varsa **göster** — backend `show*` flag'i
  /// `false` döndürse bile veri yüklenmişse kullanıcıdan saklamak yerine sergile.
  /// (`showReviews` özel: yorum yazma CTA'sı değer kattığı için flag true ise
  /// veri yoksa bile section render edilir; map flag'i koordinat yokken anlamsız.)
  List<Widget> _buildOrderedSections(SalonProfile p) {
    final out = <Widget>[];
    for (final key in _sectionOrder) {
      switch (key) {
        case 'banners':
          if (_banners.isNotEmpty) {
            out.add(_BannersSection(banners: _banners, onTap: _launch));
          }
          break;
        case 'gallery':
          if (_gallery.isNotEmpty) {
            out.add(_GallerySection(images: _gallery));
          }
          break;
        case 'services':
          if (p.categories.isNotEmpty) {
            out.add(_ServicesSection(categories: p.categories, money: _money));
          }
          break;
        case 'memberships':
          if (_memberships.isNotEmpty) {
            out.add(_MembershipsSection(
              memberships: _memberships,
              money: _money,
              onTapPlan: (plan) => _handleMembershipTap(p, plan),
            ));
          }
          break;
        case 'team':
          if (_team.isNotEmpty) {
            out.add(_TeamSection(team: _team));
          }
          break;
        case 'reviews':
          if (p.showReviews || (_reviews?.reviews.isNotEmpty ?? false)) {
            out.add(_ReviewsSection(
              data: _reviews,
              onTapWrite: () => _handleReviewWrite(p),
            ));
          }
          break;
        case 'map':
          if (p.latitude != null && p.longitude != null) {
            out.add(_MapSection(profile: p, onOpenMaps: () => _openExternalMaps(p)));
          }
          break;
      }
    }
    return out;
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.profile, this.reviewStats});

  final SalonProfile profile;
  final SalonReviewStats? reviewStats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverUrl = (profile.coverImageUrl ?? '').trim();
    final logoUrl = (profile.logoUrl ?? '').trim();
    final loc = [
      if ((profile.district ?? '').isNotEmpty) profile.district,
      if ((profile.city ?? '').isNotEmpty) profile.city,
    ].whereType<String>().join(', ');
    final desc = (profile.description ?? '').trim();
    final showSubtitle = profile.branchName?.trim().isNotEmpty == true &&
        !profile.isHeadquarter &&
        profile.salonName.trim() != profile.branchName?.trim();
    final stats = reviewStats;

    return Container(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: coverUrl.isNotEmpty
                ? Image.network(coverUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
                    return _GradientCover(scheme: scheme);
                  })
                : _GradientCover(scheme: scheme),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.outline, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 8,
                          offset: Offset(0, 2),
                          color: Color(0x14000000),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: logoUrl.isNotEmpty
                          ? Image.network(
                              logoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.storefront_outlined,
                                color: scheme.onSurfaceVariant,
                              ),
                            )
                          : Icon(
                              Icons.storefront_outlined,
                              color: scheme.onSurfaceVariant,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayTitle,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (showSubtitle)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                profile.salonName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          if (loc.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.place_outlined,
                                    size: 14, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    loc,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (stats != null && stats.totalCount > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    size: 16, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 4),
                                Text(
                                  stats.averageRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '(${stats.totalCount} yorum)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                desc,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: scheme.onSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyProfileNotice extends StatelessWidget {
  const _EmptyProfileNotice({required this.profile});
  final SalonProfile profile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    context.tr(
                      'salon.mobile.profile.empty.title',
                      'Profil bilgileri henüz tamamlanmadı',
                    ),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  profile.showBooking
                      ? 'salon.mobile.profile.empty.bodyWithBooking'
                      : 'salon.mobile.profile.empty.bodyNoBooking',
                  profile.showBooking
                      ? 'Bu salon henüz hizmetlerini, ekibini veya çalışma saatlerini eklememiş. Yine de aşağıdaki Randevu Al butonu ile randevu talebi gönderebilirsiniz.'
                      : 'Bu salon henüz hizmetlerini, ekibini veya çalışma saatlerini eklememiş. Salon randevu kabul etmiyor olabilir; iletişim bilgisi varsa doğrudan arayabilirsiniz.',
                ),
                style: TextStyle(
                    fontSize: 13, color: scheme.onSurfaceVariant, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientCover extends StatelessWidget {
  const _GradientCover({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.85),
            scheme.primary.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _BannersSection extends StatelessWidget {
  const _BannersSection({required this.banners, required this.onTap});
  final List<SalonBanner> banners;
  final ValueChanged<Uri> onTap;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      icon: Icons.campaign_outlined,
      title: 'Duyurular',
      child: SizedBox(
        height: 160,
        child: PageView.builder(
          itemCount: banners.length,
          controller: PageController(viewportFraction: 0.92),
          itemBuilder: (_, i) {
            final b = banners[i];
            final link = (b.link ?? '').trim();
            final hero = ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                b.url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
              ),
            );
            return Padding(
              padding: EdgeInsets.only(right: i == banners.length - 1 ? 0 : 8),
              child: link.isEmpty
                  ? hero
                  : InkWell(
                      onTap: () {
                        final uri = Uri.tryParse(link);
                        if (uri != null) onTap(uri);
                      },
                      child: hero,
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.images});
  final List<String> images;

  void _open(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GalleryViewerPage(images: images, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      icon: Icons.photo_library_outlined,
      title: 'Galeri',
      child: SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final url = images[i];
            return GestureDetector(
              onTap: () => _open(context, i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: 140,
                  errorBuilder: (_, __, ___) => Container(
                    width: 140,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ServicesSection extends StatefulWidget {
  const _ServicesSection({required this.categories, required this.money});
  final List<ServiceCategory> categories;
  final NumberFormat money;

  @override
  State<_ServicesSection> createState() => _ServicesSectionState();
}

class _ServicesSectionState extends State<_ServicesSection> {
  int? _expandedId;

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) {
      _expandedId = widget.categories.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SectionShell(
      icon: Icons.list_alt,
      title: 'Hizmetler',
      child: Column(
        children: [
          for (final cat in widget.categories)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 4),
                key: PageStorageKey<int>(cat.id),
                initiallyExpanded: _expandedId == cat.id,
                onExpansionChanged: (open) {
                  if (open) setState(() => _expandedId = cat.id);
                },
                title: Text(
                  cat.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                children: [
                  for (final s in cat.services)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name,
                                    style: const TextStyle(fontSize: 13.5)),
                                if (s.durationMinutes > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '${s.durationMinutes} dk',
                                      style: TextStyle(
                                          fontSize: 11.5, color: scheme.onSurfaceVariant),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            widget.money.format(s.price),
                            style: TextStyle(
                                fontSize: 13.5,
                                color: scheme.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.team});
  final List<TeamMember> team;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SectionShell(
      icon: Icons.groups_2_outlined,
      title: 'Ekip',
      child: SizedBox(
        height: 168,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: team.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final t = team[i];
            final photo = (t.photoUrl ?? '').trim();
            return SizedBox(
              width: 120,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: scheme.surfaceContainerHighest,
                    backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                    child: photo.isEmpty
                        ? Icon(Icons.person, size: 32, color: scheme.onSurfaceVariant)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  if ((t.title ?? '').isNotEmpty)
                    Text(
                      t.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  if ((t.specialty ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        t.specialty!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: scheme.primary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.data, required this.onTapWrite});
  final ReviewsResponse? data;
  final VoidCallback onTapWrite;

  static const int _maxItems = 5;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reviews = data?.reviews ?? const <SalonReview>[];
    final items = reviews.take(_maxItems).toList();
    final stats = data?.stats;
    return _SectionShell(
      icon: Icons.reviews_outlined,
      title: 'Yorumlar',
      trailing: stats != null && stats.totalCount > 0
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Text(
                  stats.averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${stats.totalCount})',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Henüz onaylı yorum yok. İlk yorumu siz yazın.',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(color: scheme.outlineVariant, height: 16),
            _ReviewTile(review: items[i]),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onTapWrite,
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: Text(context.tr('salon.mobile.profile.reviews.write', 'Yorum yaz')),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewWriteSheet extends StatefulWidget {
  const _ReviewWriteSheet({required this.slug, this.defaultDisplayName});

  final String slug;
  final String? defaultDisplayName;

  @override
  State<_ReviewWriteSheet> createState() => _ReviewWriteSheetState();
}

class _ReviewWriteSheetState extends State<_ReviewWriteSheet> {
  int _rating = 5;
  late final TextEditingController _comment;
  late final TextEditingController _displayName;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _comment = TextEditingController();
    _displayName = TextEditingController(text: widget.defaultDisplayName ?? '');
  }

  @override
  void dispose() {
    _comment.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final result = await context.read<CorpApiClient>().submitPlatformReview(
            slug: widget.slug,
            rating: _rating,
            comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
            displayName:
                _displayName.text.trim().isEmpty ? null : _displayName.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.rate_review_outlined, color: scheme.primary),
                    const SizedBox(width: 10),
                    Text(
                      'Yorumunuz',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final filled = i < _rating;
                    return IconButton(
                      onPressed: () => setState(() => _rating = i + 1),
                      icon: Icon(
                        filled ? Icons.star : Icons.star_border,
                        size: 36,
                        color: const Color(0xFFF59E0B),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _displayName,
                  decoration: InputDecoration(
                    labelText: context.tr(
                      'salon.mobile.profile.reviews.displayName',
                      'Görünen ad (opsiyonel)',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _comment,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    labelText: context.tr(
                      'salon.mobile.profile.reviews.commentLabel',
                      'Yorum (opsiyonel)',
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
                Text(
                  'Yorumunuz salon onayından sonra herkese görünür olacak.',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: Text(_saving
                      ? context.tr('salon.mobile.common.sending', 'Gönderiliyor…')
                      : context.tr('salon.mobile.common.send', 'Gönder')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final SalonReview review;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateText = DateFormat('d MMM y', 'tr_TR').format(review.createdAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                review.clientName.isNotEmpty ? review.clientName : 'Misafir',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final filled = i < review.rating;
                return Icon(
                  filled ? Icons.star : Icons.star_border,
                  size: 14,
                  color: const Color(0xFFF59E0B),
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          dateText,
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
        ),
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            review.comment,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ],
    );
  }
}

class _MembershipsSection extends StatelessWidget {
  const _MembershipsSection({
    required this.memberships,
    required this.money,
    required this.onTapPlan,
  });
  final List<SalonMembership> memberships;
  final NumberFormat money;
  final ValueChanged<SalonMembership> onTapPlan;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      icon: Icons.workspace_premium_outlined,
      title: 'Üyelik planları',
      child: SizedBox(
        height: 200,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: memberships.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _MembershipCard(
            plan: memberships[i],
            money: money,
            onTap: () => onTapPlan(memberships[i]),
          ),
        ),
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({
    required this.plan,
    required this.money,
    required this.onTap,
  });
  final SalonMembership plan;
  final NumberFormat money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final desc = (plan.description ?? '').trim();
    return SizedBox(
      width: 240,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      plan.price > 0 ? money.format(plan.price) : 'Ücretsiz',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        plan.durationDays > 0 ? '/ ${plan.durationDays} gün' : '',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      desc,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant, height: 1.35),
                    ),
                  ),
                ] else
                  const Spacer(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (plan.discountPercent > 0)
                      _MembershipChip(text: '%${plan.discountPercent} indirim'),
                    if (plan.priorityBooking)
                      const _MembershipChip(text: 'Öncelikli randevu'),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    plan.price > 0 ? 'Üye ol →' : 'Başvur →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MembershipSignupSheet extends StatefulWidget {
  const _MembershipSignupSheet({
    required this.plan,
    required this.slug,
    required this.money,
    this.prefillName,
    this.prefillPhone,
    this.prefillEmail,
  });

  final SalonMembership plan;
  final String slug;
  final NumberFormat money;
  final String? prefillName;
  final String? prefillPhone;
  final String? prefillEmail;

  @override
  State<_MembershipSignupSheet> createState() => _MembershipSignupSheetState();
}

class _MembershipSignupSheetState extends State<_MembershipSignupSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.prefillName ?? '');
    _phone = TextEditingController(text: widget.prefillPhone ?? '');
    _email = TextEditingController(text: widget.prefillEmail ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final api = context.read<CorpApiClient>();
      final result = await api.signupMembership(
        slug: widget.slug,
        planId: widget.plan.id,
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paid = widget.plan.price > 0;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium_outlined, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.plan.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Text(
                      paid ? widget.money.format(widget.plan.price) : 'Ücretsiz',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary),
                    ),
                  ],
                ),
                if (paid) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Ücretli plan — bilgilerinizi onayladıktan sonra ödeme adımına geçilecek.',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.tr('salon.mobile.auth.fields.fullName', 'Ad Soyad'),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ad soyad zorunlu' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phone,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: context.tr('salon.mobile.auth.fields.phone', 'Telefon'),
                  ),
                  validator: (v) => (v == null || v.trim().length < 7)
                      ? 'Geçerli bir telefon girin'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: context.tr(
                      'salon.mobile.auth.fields.emailOptional',
                      'E-posta (isteğe bağlı)',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(paid ? Icons.payment : Icons.check_circle_outline),
                  label: Text(_saving
                      ? 'Gönderiliyor…'
                      : (paid ? 'Onayla ve ödemeye geç' : 'Üye ol')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MembershipChip extends StatelessWidget {
  const _MembershipChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HoursSection extends StatelessWidget {
  const _HoursSection({required this.hours});
  final List<WorkingHourEntry> hours;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SectionShell(
      icon: Icons.schedule_outlined,
      title: 'Çalışma saatleri',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final h in hours)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      h.dayLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: h.isToday ? FontWeight.w700 : FontWeight.w500,
                        color: h.isToday ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      h.hoursText,
                      style: TextStyle(
                        fontSize: 13,
                        color: h.isClosed
                            ? scheme.onSurfaceVariant
                            : (h.isToday ? scheme.primary : scheme.onSurface),
                        fontWeight: h.isToday ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (h.isToday)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Bugün',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({required this.profile, required this.onLaunch});
  final SalonProfile profile;
  final ValueChanged<Uri> onLaunch;

  @override
  Widget build(BuildContext context) {
    final phone = (profile.phone ?? '').trim();
    final email = (profile.email ?? '').trim();
    final website = (profile.website ?? '').trim();
    final instagram = (profile.instagramHandle ?? '').trim();
    final facebook = (profile.facebookUrl ?? '').trim();
    final address = (profile.address ?? '').trim();
    final loc = [
      if ((profile.district ?? '').isNotEmpty) profile.district,
      if ((profile.city ?? '').isNotEmpty) profile.city,
    ].whereType<String>().join(', ');

    final rows = <Widget>[];
    if (address.isNotEmpty || loc.isNotEmpty) {
      rows.add(_ContactRow(
        icon: Icons.place_outlined,
        text: [address, loc].where((s) => s.isNotEmpty).join('\n'),
      ));
    }
    if (phone.isNotEmpty) {
      rows.add(_ContactRow(
        icon: Icons.call_outlined,
        text: phone,
        onTap: () => onLaunch(Uri(scheme: 'tel', path: phone)),
      ));
    }
    if (email.isNotEmpty) {
      rows.add(_ContactRow(
        icon: Icons.email_outlined,
        text: email,
        onTap: () => onLaunch(Uri(scheme: 'mailto', path: email)),
      ));
    }
    if (website.isNotEmpty) {
      rows.add(_ContactRow(
        icon: Icons.language,
        text: website,
        onTap: () {
          final uri = Uri.tryParse(
              website.startsWith('http') ? website : 'https://$website');
          if (uri != null) onLaunch(uri);
        },
      ));
    }
    if (instagram.isNotEmpty) {
      final handle = instagram.replaceFirst(RegExp(r'^@'), '');
      rows.add(_ContactRow(
        icon: Icons.camera_alt_outlined,
        text: '@$handle',
        onTap: () => onLaunch(Uri.parse('https://instagram.com/$handle')),
      ));
    }
    if (facebook.isNotEmpty) {
      rows.add(_ContactRow(
        icon: Icons.facebook_outlined,
        text: facebook,
        onTap: () {
          final uri = Uri.tryParse(
              facebook.startsWith('http') ? facebook : 'https://$facebook');
          if (uri != null) onLaunch(uri);
        },
      ));
    }

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return _SectionShell(
      icon: Icons.contact_support_outlined,
      title: 'İletişim',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.text, this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: onTap == null ? scheme.onSurface : scheme.primary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(onTap: onTap, child: body);
  }
}

class _MapSection extends StatelessWidget {
  const _MapSection({required this.profile, required this.onOpenMaps});
  final SalonProfile profile;
  final VoidCallback onOpenMaps;

  /// Mağaza yayını riski: OSM Foundation public tile sunucusu kullanım politikası
  /// uygulama mağazalarında izin vermez. Prod build'de Mapbox/MapTiler/Stadia/Carto
  /// key'i sağlanmadıysa gerçek harita yerine adres + "Yol tarifi" placeholder
  /// gösterilir; key set edilirse normal interaktif harita.
  bool get _isPublicOsm =>
      AppConfig.mapTileUrl.contains('tile.openstreetmap.org');

  bool get _suppressTiles => kReleaseMode && _isPublicOsm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lat = profile.latitude!;
    final lng = profile.longitude!;
    final point = LatLng(lat, lng);

    final addressLine = [
      if ((profile.address ?? '').isNotEmpty) profile.address!.trim(),
      [
        if ((profile.district ?? '').isNotEmpty) profile.district!.trim(),
        if ((profile.city ?? '').isNotEmpty) profile.city!.trim(),
      ].where((s) => s.isNotEmpty).join(', '),
    ].where((s) => s.isNotEmpty).join('\n');

    return _SectionShell(
      icon: Icons.map_outlined,
      title: 'Konum',
      trailing: TextButton.icon(
        onPressed: onOpenMaps,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.directions, size: 16),
        label: Text(context.tr('salon.mobile.profile.map.directions', 'Yol tarifi')),
      ),
      child: _suppressTiles
          ? _MapPlaceholder(
              addressLine: addressLine,
              onOpenMaps: onOpenMaps,
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 180,
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: point,
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: AppConfig.mapTileUrl,
                          userAgentPackageName: AppConfig.mapTileUserAgent,
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: point,
                              width: 36,
                              height: 36,
                              alignment: Alignment.topCenter,
                              child: Icon(Icons.location_on,
                                  color: scheme.primary, size: 36),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(onTap: onOpenMaps),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Prod'da harita tile sağlayıcı yoksa gösterilen sade kart — adres + Yol tarifi.
class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.addressLine, required this.onOpenMaps});
  final String addressLine;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.place_outlined, size: 32, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            addressLine.isNotEmpty ? addressLine : 'Konum bilgisi',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: scheme.onSurface, height: 1.35),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onOpenMaps,
            icon: const Icon(Icons.directions),
            label: Text(context.tr('salon.mobile.profile.map.directionsAction', 'Yol tarifi al')),
          ),
        ],
      ),
    );
  }
}

class _BottomBookCta extends StatelessWidget {
  const _BottomBookCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.calendar_month),
          label: const Text(
            'Randevu al',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
