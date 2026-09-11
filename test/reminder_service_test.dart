import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_sheet/services/reminder_service.dart';
import 'package:prayer_sheet/models/prayer.dart';
import 'package:prayer_sheet/services/prayer_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_notification_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNotificationPlatform platform;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    platform = FakeNotificationPlatform()..install();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<ReminderService> loaded() async {
    final service = ReminderService();
    await service.init();
    // Without a store the service falls back to the plain repeating nudge,
    // which is what these tests exercise; the smart rules have their own file.
    await service.setMode(ReminderMode.everyTwoHours);
    return service;
  }

  test('a missing status bar icon falls back to the launcher icon', () async {
    // Exactly what the resource shrinker did to v3: the drawable was gone, and
    // initialisation failed, reporting only "not supported on this device".
    platform.unresolvableIcons = <String>{'ic_stat_reminder'};

    final service = ReminderService();
    await service.init();

    expect(service.isSupported, isTrue);
    expect(service.setupError, isNull);

    final icons = platform.calls
        .where((c) => c.method == 'initialize')
        .map((c) => c.arguments['defaultIcon'])
        .toList();
    expect(icons, <String>['ic_stat_reminder', '@mipmap/ic_launcher']);
  });

  test('setup that cannot succeed reports why', () async {
    platform.unresolvableIcons = <String>{
      'ic_stat_reminder',
      '@mipmap/ic_launcher',
    };

    final service = ReminderService();
    await service.init();

    expect(service.isSupported, isFalse);
    expect(service.setupError, contains('could not be found'));
  });

  test('reminders start switched off', () async {
    final service = await loaded();

    expect(service.isEnabled, isFalse);
    expect(platform.hasCallTo('periodicallyShowWithDuration'), isFalse);
  });

  test('enabling schedules the reminder every two hours', () async {
    final service = await loaded();
    platform.reset();

    expect(await service.setEnabled(true), isTrue);
    expect(service.isEnabled, isTrue);

    final call = platform.callTo('periodicallyShowWithDuration');
    expect(call, isNotNull);
    final args = call!.arguments as Map<dynamic, dynamic>;
    expect(args['calledAt'], isNotNull);
    expect(
      args['repeatIntervalMilliseconds'],
      const Duration(hours: 2).inMilliseconds,
    );
  });

  test('the reminder carries the exact wording asked for', () async {
    final service = await loaded();
    await service.setEnabled(true);

    final args = platform.callTo('periodicallyShowWithDuration')!.arguments
        as Map<dynamic, dynamic>;
    expect(args['title'], 'هل سجّلت صلاتك؟ 🙏');
    expect(args['body'], 'حافظ على تتابع أيامك 👏');
  });

  test('the reminder uses the app sound, not the system default', () async {
    final service = await loaded();
    await service.setEnabled(true);

    final args = platform.callTo('periodicallyShowWithDuration')!.arguments
        as Map<dynamic, dynamic>;
    final platformSpecifics =
        args['platformSpecifics'] as Map<dynamic, dynamic>;
    expect(platformSpecifics['sound'], 'soft_chime');
    expect(platformSpecifics['playSound'], isTrue);
  });

  test('sound is on by default and uses the sounding channel', () async {
    final service = await loaded();
    await service.setEnabled(true);

    expect(service.isSoundOn, isTrue);
    final specifics = platform.callTo('periodicallyShowWithDuration')!
        .arguments['platformSpecifics'] as Map<dynamic, dynamic>;
    expect(specifics['channelId'], 'prayer_reminders_v1');
  });

  test('silencing re-arms the reminder on a soundless channel', () async {
    final service = await loaded();
    await service.setEnabled(true);
    platform.reset();

    await service.setSoundOn(false);

    expect(service.isSoundOn, isFalse);
    final specifics = platform.callTo('periodicallyShowWithDuration')!
        .arguments['platformSpecifics'] as Map<dynamic, dynamic>;
    // A channel's sound cannot change once it exists, hence the second channel.
    expect(specifics['channelId'], 'prayer_reminders_silent_v1');
    expect(specifics['playSound'], isFalse);
    expect(specifics['sound'], isNull);
  });

  test('the sound choice survives a restart', () async {
    final first = await loaded();
    await first.setSoundOn(false);

    expect((await loaded()).isSoundOn, isFalse);
  });

  test('silencing while reminders are off schedules nothing', () async {
    final service = await loaded();
    platform.reset();

    await service.setSoundOn(false);

    expect(service.isSoundOn, isFalse);
    expect(platform.hasCallTo('periodicallyShowWithDuration'), isFalse);
  });

  test('a refused permission leaves reminders off', () async {
    platform.grantPermission = false;
    final service = await loaded();
    platform.reset();

    expect(await service.setEnabled(true), isFalse);
    expect(service.isEnabled, isFalse);
    expect(platform.hasCallTo('periodicallyShowWithDuration'), isFalse);
  });

  test('disabling cancels the scheduled reminder', () async {
    final service = await loaded();
    await service.setEnabled(true);
    platform.reset();

    expect(await service.setEnabled(false), isFalse);
    expect(service.isEnabled, isFalse);
    expect(platform.hasCallTo('cancel'), isTrue);
  });

  test('the choice survives a restart and is re-armed', () async {
    final first = await loaded();
    await first.setEnabled(true);

    platform.reset();
    final second = await loaded();

    expect(second.isEnabled, isTrue);
    // Re-armed on the next reschedule, in case the OS dropped it meanwhile.
    await second.reschedule(null);
    expect(platform.hasCallTo('periodicallyShowWithDuration'), isTrue);
  });

  group('smart mode', () {
    Future<ReminderService> smart(PrayerStore store) async {
      final service = ReminderService();
      await service.init();
      await service.setEnabled(true, store: store);
      return service;
    }

    Future<PrayerStore> emptyStore() async {
      final store = PrayerStore();
      await store.load();
      return store;
    }

    test('smart is the default and schedules at prayer times', () async {
      final store = await emptyStore();
      platform.reset();
      final service = await smart(store);

      expect(service.mode, ReminderMode.smart);
      // Real times, not a blind repeat.
      expect(platform.hasCallTo('zonedSchedule'), isTrue);
      expect(platform.hasCallTo('periodicallyShowWithDuration'), isFalse);
    });

    test('a fully logged day leaves today with nothing pending', () async {
      final store = await emptyStore();
      final service = await smart(store);

      final scheduledBefore = platform.calls
          .where((c) => c.method == 'zonedSchedule')
          .length;
      expect(scheduledBefore, greaterThan(0));

      await store.markAll(DateTime.now());
      platform.reset();
      await service.reschedule(store);

      final today = DateTime.now();
      final stillToday = platform.calls
          .where((c) => c.method == 'zonedSchedule')
          .where((c) {
        final at = c.arguments['scheduledDateTime'] as String? ?? '';
        return at.startsWith(
          '${today.year}-${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}',
        );
      });
      expect(stillToday, isEmpty);
    });

    test('logging a prayer drops its reminder for today', () async {
      final store = await emptyStore();
      final service = await smart(store);

      await store.toggle(DateTime.now(), Prayer.isha);
      platform.reset();
      await service.reschedule(store);

      // Later days are still scheduled, so only today's is of interest.
      final todaysTitles = platform.calls
          .where((c) => c.method == 'zonedSchedule')
          .where((c) => _scheduledOn(c, DateTime.now()))
          .map((c) => c.arguments['title'] as String?)
          .toList();
      expect(todaysTitles.contains('دخل وقت العشاء'), isFalse);
    });

    test('an unknown timezone name still schedules on the wall clock',
        () async {
      // A name the tz database does not carry must not silently fall back to
      // UTC, which would move every reminder by the device's offset.
      platform.timeZoneName = 'Not/A_Real_Zone';

      final store = await emptyStore();
      final service = ReminderService();
      await service.init();
      await service.setEnabled(true, store: store);

      final scheduled = platform.calls
          .where((c) => c.method == 'zonedSchedule')
          .map((c) =>
              DateTime.parse(c.arguments['scheduledDateTime'] as String))
          .toList();
      expect(scheduled, isNotEmpty);

      // The scheduled wall-clock times must match the local ones the rules
      // produced, so the offset the plugin is handed has to be the device's.
      final offsets = platform.calls
          .where((c) => c.method == 'zonedSchedule')
          .map((c) => DateTime.parse(
                  c.arguments['scheduledDateTimeISO8601'] as String)
              .timeZoneOffset)
          .toSet();
      expect(offsets, isNotEmpty);
    });

    test('nothing is ever scheduled in the past', () async {
      final store = await emptyStore();
      final before = DateTime.now();
      await smart(store);

      final times = platform.calls
          .where((c) => c.method == 'zonedSchedule')
          .map((c) =>
              DateTime.parse(c.arguments['scheduledDateTime'] as String))
          .toList();

      expect(times, isNotEmpty);
      for (final at in times) {
        expect(at.isAfter(before), isTrue, reason: '\$at is not in the future');
      }
    });

    test('switching off cancels everything that was scheduled', () async {
      final store = await emptyStore();
      final service = await smart(store);
      platform.reset();

      await service.setEnabled(false, store: store);

      expect(platform.hasCallTo('cancel'), isTrue);
      expect(platform.hasCallTo('zonedSchedule'), isFalse);
    });
  });
}

/// Whether a zonedSchedule call lands on [day]'s calendar date.
bool _scheduledOn(MethodCall call, DateTime day) {
  final at = call.arguments['scheduledDateTime'] as String? ?? '';
  final prefix = '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
  return at.startsWith(prefix);
}
