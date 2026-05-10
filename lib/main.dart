import 'package:callcenter_salon_mobil/config/app_config.dart';
import 'package:callcenter_salon_mobil/screens/main_shell.dart';
import 'package:callcenter_salon_mobil/services/corp_api.dart';
import 'package:callcenter_salon_mobil/services/deep_link_handler.dart';
import 'package:callcenter_salon_mobil/services/session_store.dart';
import 'package:callcenter_salon_mobil/state/app_localization_state.dart';
import 'package:callcenter_salon_mobil/state/session_state.dart';
import 'package:callcenter_salon_mobil/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'tr_TR';
  await Future.wait([
    initializeDateFormatting('tr'),
    initializeDateFormatting('tr_TR'),
  ]);

  if (kDebugMode &&
      AppConfig.mapTileUrl.contains('tile.openstreetmap.org')) {
    debugPrint(
      '[map] Varsayılan OSM tile sunucusu kullanılıyor — '
      'mağaza yayınında YASAK. Prod için --dart-define=MAP_TILE_URL=... '
      '(Mapbox/MapTiler/Stadia/Carto) ile override edin. '
      'docs/PRODUCTION.md §1.',
    );
  }

  if (AppConfig.sentryDsn.isEmpty) {
    runApp(const SalonBookingApp());
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = AppConfig.sentryDsn;
      options.environment = AppConfig.sentryEnvironment;
      options.tracesSampleRate = AppConfig.sentryTracesSampleRate;
      options.attachScreenshot = true;
    },
    appRunner: () => runApp(const SalonBookingApp()),
  );
}

class SalonBookingApp extends StatelessWidget {
  const SalonBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionState(SessionStore())),
        ProxyProvider<SessionState, CorpApiClient>(
          update: (_, sess, __) => CorpApiClient(
            getBearer: () => sess.token,
            onUnauthorized: () {
              sess.signOut();
            },
          ),
        ),
        ChangeNotifierProxyProvider<CorpApiClient, AppLocalizationState>(
          create: (_) => AppLocalizationState(),
          update: (_, api, state) {
            final localization = state ?? AppLocalizationState();
            localization.bindApi(api);
            return localization;
          },
        ),
      ],
      child: Consumer<AppLocalizationState>(
        builder: (_, i18n, __) => MaterialApp(
          title: i18n.t('salon.mobile.app.title', 'CorpLynk Salon'),
          debugShowCheckedModeBanner: false,
          navigatorKey: _rootNavigatorKey,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
        // Türkçe DatePicker / TimePicker / Material varsayılanları için.
          locale: i18n.locale,
          supportedLocales: i18n.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: const _BootstrapShell(),
        ),
      ),
    );
  }
}

/// Oturum yüklemesi; ana ekran web `/discover` ile aynı (`DiscoverPage`).
class _BootstrapShell extends StatefulWidget {
  const _BootstrapShell();

  @override
  State<_BootstrapShell> createState() => _BootstrapShellState();
}

class _BootstrapShellState extends State<_BootstrapShell> {
  bool _ready = false;
  DeepLinkHandler? _deepLinks;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _deepLinks?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await context.read<SessionState>().loadFromDisk();
    if (mounted) setState(() => _ready = true);
    final handler = DeepLinkHandler(navigatorKey: _rootNavigatorKey);
    await handler.init();
    _deepLinks = handler;
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kDebugMode)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  kIsWeb
                      ? 'API hedefi: ${AppConfig.apiBaseUrl}. Flutter Web geliştirici sunucusu için örn. '
                          '`flutter run -d chrome --web-port=8080` ile port sabitlenebilir.'
                      : 'API hedefi: ${AppConfig.apiBaseUrl}. Bu mobil kurulum (Android/iOS/desktop) yerelde '
                          'TCP portu dinlemez; sabit olan tek adres buraya bağlanacağınız API tabanıdır.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          ),
        const Expanded(child: MainShell()),
      ],
    );
  }
}
