import 'package:callcenter_salon_mobil/state/app_localization_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
      switch (call.method) {
        case 'read':
          return null;
        case 'readAll':
          return <String, String>{};
        case 'containsKey':
          return false;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  group('AppLocalizationState fallback', () {
    test('returns _fallbackTr value when key is in core map', () {
      final state = AppLocalizationState();
      expect(state.t('salon.mobile.app.title'), 'CorpLynk Salon');
      expect(
        state.t('salon.mobile.appointments.status.confirmed'),
        'Onaylandı',
      );
      expect(
        state.t('salon.mobile.profile.map.directions'),
        'Yol tarifi',
      );
    });

    test('returns provided fallback when key is missing', () {
      final state = AppLocalizationState();
      expect(
        state.t('salon.mobile.does.not.exist', 'literal-default'),
        'literal-default',
      );
    });

    test('returns key itself when no fallback chain matches', () {
      final state = AppLocalizationState();
      expect(state.t('totally.unknown.key'), 'totally.unknown.key');
    });

    test('default locale is Turkish before any cache load', () {
      final state = AppLocalizationState();
      expect(state.locale, const Locale('tr', 'TR'));
      expect(state.supportedLocales, isNotEmpty);
      expect(
        state.supportedLocales.first.languageCode,
        anyOf('tr', 'en'),
      );
    });
  });

  testWidgets('context.tr resolves fallback inside a widget tree',
      (WidgetTester tester) async {
    String? resolvedTitle;
    String? resolvedFallback;

    await tester.pumpWidget(
      ChangeNotifierProvider<AppLocalizationState>(
        create: (_) => AppLocalizationState(),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              resolvedTitle = context.tr('salon.mobile.app.title');
              resolvedFallback = context.tr(
                'salon.mobile.unknown.smoke.key',
                'smoke-default',
              );
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );

    expect(resolvedTitle, 'CorpLynk Salon');
    expect(resolvedFallback, 'smoke-default');
  });
}
