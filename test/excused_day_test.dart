import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_sheet/models/day_record.dart';
import 'package:prayer_sheet/models/prayer.dart';
import 'package:prayer_sheet/models/profile.dart';
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

  group('gender', () {
    test('defaults to male, which changes nothing', () async {
      final store = await loadedStore();

      expect(store.gender, Gender.male);
      expect(store.gender.canExcuseDays, isFalse);
    });

    test('only a woman gets the excuse option', () {
      expect(Gender.female.canExcuseDays, isTrue);
      expect(Gender.male.canExcuseDays, isFalse);
    });

    test('the choice survives a restart', () async {
      await (await loadedStore()).setGender(Gender.female);

      expect((await loadedStore()).gender, Gender.female);
    });
  });

  group('an excused day', () {
    test('counts as kept without any prayer being logged', () async {
      final store = await loadedStore();
      final day = DateTime(2026, 3, 10);

      await store.setExcused(day, true);

      final record = store.recordFor(day);
      expect(record.isExcused, isTrue);
      expect(record.isComplete, isTrue);
      expect(record.doneCount, Prayer.values.length);
      expect(record.missedPrayers, isEmpty);
    });

    test('is not the same as having prayed, and says so', () async {
      final store = await loadedStore();
      final excused = DateTime(2026, 3, 10);
      final prayed = DateTime(2026, 3, 11);

      await store.setExcused(excused, true);
      await store.markAll(prayed);

      expect(store.recordFor(excused).isExcused, isTrue);
      expect(store.recordFor(prayed).isExcused, isFalse);
      // Both complete, so the UI needs the flag to tell them apart.
      expect(store.recordFor(excused).isComplete, isTrue);
      expect(store.recordFor(prayed).isComplete, isTrue);
    });

    test('keeps a streak running through it', () async {
      final store = await loadedStore();
      final base = DateTime(2026, 3, 10);

      await store.markAll(base);
      await store.setExcused(base.add(const Duration(days: 1)), true);
      await store.markAll(base.add(const Duration(days: 2)));

      expect(
        store.currentStreak(today: base.add(const Duration(days: 2))),
        3,
      );
      expect(store.bestStreak, 3);
    });

    test('earns a mosaic piece like any other kept day', () async {
      final store = await loadedStore();
      await store.setExcused(DateTime(2026, 3, 10), true);

      expect(store.completeDays, 1);
    });

    test('can be taken back, leaving the day as it was', () async {
      final store = await loadedStore();
      final day = DateTime(2026, 3, 10);
      await store.toggle(day, Prayer.fajr);
      await store.setExcused(day, true);

      await store.setExcused(day, false);

      final record = store.recordFor(day);
      expect(record.isExcused, isFalse);
      expect(record.isDone(Prayer.fajr), isTrue);
      expect(record.isComplete, isFalse);
    });

    test('an excused day with nothing else drops out when cleared', () async {
      final store = await loadedStore();
      final day = DateTime(2026, 3, 10);
      await store.setExcused(day, true);
      expect(store.history().length, 1);

      await store.setExcused(day, false);
      expect(store.history(), isEmpty);
    });

    test('survives a restart', () async {
      final day = DateTime(2026, 3, 10);
      await (await loadedStore()).setExcused(day, true);

      expect((await loadedStore()).recordFor(day).isExcused, isTrue);
    });

    test('rides along with a sync', () async {
      final store = await loadedStore();
      final day = DateTime(2026, 3, 10);
      await store.setExcused(day, true);

      final other = await loadedStore();
      await other.mergeRecords(store.exportRecords());

      expect(other.recordFor(day).isExcused, isTrue);
    });

    test('an older version reading the day just skips the flag', () {
      // The flag is not a prayer id on purpose.
      expect(Prayer.fromId(DayRecord.excusedKey), isNull);
    });
  });
}
