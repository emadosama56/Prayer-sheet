import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prayer_sheet/main.dart';
import 'package:prayer_sheet/models/prayer.dart';
import 'package:prayer_sheet/services/prayer_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => initializeDateFormatting('ar'));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // A tall phone-sized surface, so the whole home screen is laid out at
    // once instead of the ListView lazily skipping everything below 600px.
    final TestFlutterView view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 3.0;
    view.physicalSize = const Size(1200, 3600);
  });

  tearDown(() {
    final TestFlutterView view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<PrayerStore> pumpApp(WidgetTester tester) async {
    final store = PrayerStore();
    await store.load();
    await tester.pumpWidget(PrayerSheetApp(store: store));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('home screen lists the five prayers', (WidgetTester tester) async {
    await pumpApp(tester);

    for (final prayer in Prayer.values) {
      expect(find.text(prayer.arabicName), findsWidgets);
    }
    expect(find.text('0/5'), findsOneWidget);
  });

  testWidgets('tapping a prayer records it', (WidgetTester tester) async {
    final store = await pumpApp(tester);

    await tester.tap(find.text(Prayer.asr.arabicName));
    await tester.pumpAndSettle();

    expect(store.isDone(DateTime.now(), Prayer.asr), isTrue);
    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets('marking all completes the day', (WidgetTester tester) async {
    final store = await pumpApp(tester);

    await tester.tap(find.text('تسجيل كل صلوات اليوم'));
    await tester.pumpAndSettle();

    expect(store.recordFor(DateTime.now()).isComplete, isTrue);
    expect(find.text('5/5'), findsOneWidget);
    // The shortcut hides itself once there is nothing left to mark.
    expect(find.text('تسجيل كل صلوات اليوم'), findsNothing);
  });

  testWidgets('history screen shows logged days', (WidgetTester tester) async {
    final store = await pumpApp(tester);
    await store.toggle(DateTime.now(), Prayer.fajr);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();

    expect(find.text('سجل الأيام'), findsOneWidget);
    expect(find.text('لا يوجد سجل بعد'), findsNothing);
    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets('history screen is empty before anything is logged',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();

    expect(find.text('لا يوجد سجل بعد'), findsOneWidget);
  });
}
