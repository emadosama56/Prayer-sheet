import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prayer_sheet/main.dart';
import 'package:prayer_sheet/models/prayer.dart';
import 'package:prayer_sheet/services/prayer_store.dart';
import 'package:prayer_sheet/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_notification_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => initializeDateFormatting('ar'));

  late FakeNotificationPlatform notifications;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    notifications = FakeNotificationPlatform()..install();
    // A tall phone-sized surface, so the whole home screen is laid out at
    // once instead of the ListView lazily skipping everything below 600px.
    final TestFlutterView view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 3.0;
    view.physicalSize = const Size(1200, 4200);
  });

  tearDown(() {
    notifications.remove();
    final TestFlutterView view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<PrayerStore> pumpApp(WidgetTester tester) async {
    final store = PrayerStore();
    await store.load();
    final reminders = ReminderService();
    await reminders.init();
    await tester.pumpWidget(
      PrayerSheetApp(store: store, reminders: reminders),
    );
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

  testWidgets('the dua shows at the foot of the home screen',
      (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('تقبل الله من عمداوى و جانجوناااا'), findsOneWidget);
    expect(find.text('و جمعهم دايما مع بعض فى كل حاجة حلوة'), findsOneWidget);
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

  testWidgets('settings can turn the reminder and its sound on and off',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('الإعدادات'), findsOneWidget);

    final reminderSwitch = find.widgetWithText(SwitchListTile, 'تشغيل التذكير');
    expect(tester.widget<SwitchListTile>(reminderSwitch).value, isFalse);

    await tester.tap(reminderSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(reminderSwitch).value, isTrue);
    expect(notifications.hasCallTo('periodicallyShowWithDuration'), isTrue);

    final soundSwitch = find.widgetWithText(SwitchListTile, 'صوت التذكير');
    expect(tester.widget<SwitchListTile>(soundSwitch).value, isTrue);

    await tester.tap(soundSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(soundSwitch).value, isFalse);

    await tester.tap(reminderSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(reminderSwitch).value, isFalse);
    expect(notifications.hasCallTo('cancel'), isTrue);
  });

  testWidgets('history screen is empty before anything is logged',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();

    expect(find.text('لا يوجد سجل بعد'), findsOneWidget);
  });
}
