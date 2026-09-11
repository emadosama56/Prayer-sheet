import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_sheet/services/reminder_service.dart';
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
    return service;
  }

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
    expect(args['title'], 'سجلت صلاتك؟ ممكن متنساش 🙏 ؟');
    expect(args['body'], 'متخسرش عدد الايام و خليك مكمل 👏');
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
    // Re-armed on start, in case the OS dropped the schedule meanwhile.
    expect(platform.hasCallTo('periodicallyShowWithDuration'), isTrue);
  });
}
