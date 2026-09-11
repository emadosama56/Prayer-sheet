import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_sheet/models/day_record.dart';
import 'package:prayer_sheet/models/prayer.dart';
import 'package:prayer_sheet/services/prayer_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PrayerStore> loadedStore() async {
  final store = PrayerStore();
  await store.load();
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('a fresh day has nothing marked', () async {
    final store = await loadedStore();
    final today = DateTime.now();

    expect(store.recordFor(today).doneCount, 0);
    expect(store.recordFor(today).isComplete, isFalse);
    expect(store.history(), isEmpty);
  });

  test('toggling a prayer marks it, toggling again clears it', () async {
    final store = await loadedStore();
    final today = DateTime.now();

    await store.toggle(today, Prayer.dhuhr);
    expect(store.isDone(today, Prayer.dhuhr), isTrue);
    expect(store.recordFor(today).timeOf(Prayer.dhuhr), isNotNull);
    expect(store.isDone(today, Prayer.asr), isFalse);

    await store.toggle(today, Prayer.dhuhr);
    expect(store.isDone(today, Prayer.dhuhr), isFalse);
    // An emptied day drops out of the history entirely.
    expect(store.history(), isEmpty);
  });

  test('markAll completes the day and keeps existing timestamps', () async {
    final store = await loadedStore();
    final today = DateTime.now();

    await store.toggle(today, Prayer.fajr);
    final fajrTime = store.recordFor(today).timeOf(Prayer.fajr);

    await store.markAll(today);
    final record = store.recordFor(today);
    expect(record.isComplete, isTrue);
    expect(record.doneCount, Prayer.values.length);
    expect(record.timeOf(Prayer.fajr), fajrTime);
  });

  test('records survive a reload from storage', () async {
    final today = DateTime.now();
    final store = await loadedStore();
    await store.toggle(today, Prayer.maghrib);
    await store.toggle(today, Prayer.isha);

    final reloaded = await loadedStore();
    expect(reloaded.recordFor(today).doneCount, 2);
    expect(reloaded.isDone(today, Prayer.maghrib), isTrue);
    expect(reloaded.isDone(today, Prayer.isha), isTrue);
    expect(reloaded.isDone(today, Prayer.fajr), isFalse);
  });

  test('history lists tracked days newest first', () async {
    final store = await loadedStore();
    final today = dayOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));

    await store.toggle(twoDaysAgo, Prayer.fajr);
    await store.toggle(today, Prayer.asr);
    await store.toggle(yesterday, Prayer.isha);

    expect(
      store.history().map((DayRecord r) => r.dateKey).toList(),
      <String>[
        dateKeyOf(today),
        dateKeyOf(yesterday),
        dateKeyOf(twoDaysAgo),
      ],
    );
  });

  test('streak counts complete days back from today', () async {
    final store = await loadedStore();
    final today = DateTime(2026, 3, 10);

    await store.markAll(today.subtract(const Duration(days: 2)));
    await store.markAll(today.subtract(const Duration(days: 1)));
    // Today is only partly done, which must not break the streak.
    await store.toggle(today, Prayer.fajr);

    expect(store.currentStreak(today: today), 2);

    await store.markAll(today);
    expect(store.currentStreak(today: today), 3);
  });

  test('a gap ends the streak', () async {
    final store = await loadedStore();
    final today = DateTime(2026, 3, 10);

    await store.markAll(today);
    await store.markAll(today.subtract(const Duration(days: 3)));

    expect(store.currentStreak(today: today), 1);
  });

  test('recentDays returns a fixed window, oldest first', () async {
    final store = await loadedStore();
    final today = DateTime(2026, 3, 10);
    await store.markAll(today.subtract(const Duration(days: 1)));

    final week = store.recentDays(7, today: today);
    expect(week.length, 7);
    expect(week.first.dateKey,
        dateKeyOf(today.subtract(const Duration(days: 6))));
    expect(week.last.dateKey, dateKeyOf(today));
    expect(week[5].isComplete, isTrue);
  });

  test('clearDay and clearAll remove records', () async {
    final store = await loadedStore();
    final today = dayOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    await store.markAll(today);
    await store.markAll(yesterday);

    await store.clearDay(yesterday);
    expect(store.history().length, 1);

    await store.clearAll();
    expect(store.history(), isEmpty);
    expect((await loadedStore()).history(), isEmpty);
  });

  test('totals aggregate across days', () async {
    final store = await loadedStore();
    final today = dayOnly(DateTime.now());

    await store.markAll(today);
    await store.toggle(today.subtract(const Duration(days: 1)), Prayer.asr);

    expect(store.trackedDays, 2);
    expect(store.completeDays, 1);
    expect(store.totalPrayers, Prayer.values.length + 1);
  });

  test('corrupt stored data does not crash the app', () async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{'prayer_records_v1': 'not json at all'},
    );

    final store = await loadedStore();
    expect(store.isLoaded, isTrue);
    expect(store.history(), isEmpty);
  });
}
