import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_sheet/models/prayer.dart';
import 'package:prayer_sheet/services/prayer_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The home screen widget logs prayers in its own isolate, with its own copy
/// of the log. Two stores over the same storage stand in for that here: the
/// running app, and the widget's short-lived one.
Future<PrayerStore> openStore() async {
  final store = PrayerStore();
  await store.load();
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  final day = DateTime(2026, 3, 10);

  test('a prayer logged on the widget survives the next tap in the app',
      () async {
    final app = await openStore();
    final widget = await openStore();

    await widget.toggle(day, Prayer.fajr);
    // The app has not seen that, and its own write rewrites the whole log.
    await app.toggle(day, Prayer.asr);

    final stored = await openStore();
    expect(stored.isDone(day, Prayer.fajr), isTrue,
        reason: 'the widget\'s prayer was overwritten by the app');
    expect(stored.isDone(day, Prayer.asr), isTrue);
  });

  test('and the other way round', () async {
    final app = await openStore();
    final widget = await openStore();

    await app.toggle(day, Prayer.dhuhr);
    await widget.toggle(day, Prayer.maghrib);

    final stored = await openStore();
    expect(stored.isDone(day, Prayer.dhuhr), isTrue);
    expect(stored.isDone(day, Prayer.maghrib), isTrue);
  });

  test('marking the whole day keeps what the widget logged', () async {
    final app = await openStore();
    final widget = await openStore();

    await widget.toggle(day, Prayer.fajr);
    await app.markAll(day);

    expect((await openStore()).recordFor(day).isComplete, isTrue);
  });

  test('refresh brings the widget\'s work into a running app', () async {
    final app = await openStore();
    final widget = await openStore();

    await widget.toggle(day, Prayer.isha);
    expect(app.isDone(day, Prayer.isha), isFalse, reason: 'not seen yet');

    await app.refresh();
    expect(app.isDone(day, Prayer.isha), isTrue);
  });

  test('refresh drops a day that was cleared elsewhere', () async {
    final app = await openStore();
    await app.markAll(day);

    final widget = await openStore();
    await widget.clearDay(day);

    await app.refresh();
    expect(app.recordFor(day).isEmpty, isTrue);
  });

  test('an excused day set on one side is not lost by the other', () async {
    final app = await openStore();
    final widget = await openStore();

    await widget.setExcused(day, true);
    await app.toggle(day.add(const Duration(days: 1)), Prayer.fajr);

    expect((await openStore()).recordFor(day).isExcused, isTrue);
  });
}
