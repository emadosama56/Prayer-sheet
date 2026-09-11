import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_sheet/models/day_record.dart';
import 'package:prayer_sheet/models/day_timings.dart';
import 'package:prayer_sheet/models/prayer.dart';
import 'package:prayer_sheet/services/reminder_schedule.dart';

/// Fixed, realistic Cairo times so the expectations read as wall clock.
DayTimings timingsOn(DateTime day) => DayTimings(<Prayer, DateTime>{
      Prayer.fajr: DateTime(day.year, day.month, day.day, 4, 9),
      Prayer.dhuhr: DateTime(day.year, day.month, day.day, 11, 53),
      Prayer.asr: DateTime(day.year, day.month, day.day, 15, 22),
      Prayer.maghrib: DateTime(day.year, day.month, day.day, 18, 6),
      Prayer.isha: DateTime(day.year, day.month, day.day, 19, 24),
    });

/// A record store backed by a plain map of day key -> logged prayers.
DayRecord Function(DateTime) recordsFrom(Map<DateTime, Set<Prayer>> logged) {
  return (DateTime day) {
    final key = dateKeyOf(day);
    final marked = <Prayer, DateTime>{};
    logged.forEach((DateTime loggedDay, Set<Prayer> prayers) {
      if (dateKeyOf(loggedDay) != key) return;
      for (final prayer in prayers) {
        marked[prayer] = DateTime(day.year, day.month, day.day, 12);
      }
    });
    return DayRecord(dateKey: key, markedAt: marked);
  };
}

void main() {
  final today = DateTime(2026, 9, 11);
  final yesterday = today.subtract(const Duration(days: 1));

  List<ScheduledReminder> build({
    required DateTime now,
    Map<DateTime, Set<Prayer>> logged = const <DateTime, Set<Prayer>>{},
    ReminderSchedule schedule = const ReminderSchedule(daysAhead: 1),
  }) =>
      schedule.build(
        now: now,
        recordFor: recordsFrom(logged),
        timingsFor: timingsOn,
      );

  test('nothing is scheduled for a moment already past', () {
    // Late evening, after Isha's follow-up has come and gone.
    final reminders = build(now: DateTime(2026, 9, 11, 22, 0));
    expect(reminders, isEmpty);
  });

  test('an unlogged prayer gets a follow-up half an hour after its time', () {
    final reminders = build(now: DateTime(2026, 9, 11, 10, 0));

    final dhuhr = reminders.firstWhere((r) => r.title.contains('الظهر'));
    expect(dhuhr.at, DateTime(2026, 9, 11, 12, 23)); // 11:53 + 30m
    expect(dhuhr.body, contains('متنساش تسجلها'));
  });

  test('a prayer warns half an hour ahead when the previous is unlogged', () {
    final reminders = build(now: DateTime(2026, 9, 11, 12, 30));

    // Asr is 15:22, so the warning lands at 14:52 and names Dhuhr.
    final warning = reminders.firstWhere(
      (r) => r.at == DateTime(2026, 9, 11, 14, 52),
    );
    expect(warning.title, 'لسه ما سجلتش الظهر');
    expect(warning.body, contains('العصر'));
    expect(warning.body, contains('متخسرش عدد الايام'));
  });

  test('logging a prayer drops its warning from the next one', () {
    final now = DateTime(2026, 9, 11, 12, 30);

    final before = build(now: now);
    expect(before.any((r) => r.title == 'لسه ما سجلتش الظهر'), isTrue);

    final after = build(
      now: now,
      logged: <DateTime, Set<Prayer>>{
        today: <Prayer>{Prayer.dhuhr},
      },
    );
    expect(after.any((r) => r.title == 'لسه ما سجلتش الظهر'), isFalse);
    // Its own follow-up is gone too, since it is logged.
    expect(after.any((r) => r.title == 'دخل وقت الظهر'), isFalse);
  });

  test('a complete day is silent until tomorrow', () {
    final reminders = build(
      now: DateTime(2026, 9, 11, 6, 0),
      logged: <DateTime, Set<Prayer>>{today: Prayer.values.toSet()},
    );
    expect(reminders, isEmpty);
  });

  test('a complete day does not silence the days after it', () {
    final reminders = build(
      now: DateTime(2026, 9, 11, 6, 0),
      logged: <DateTime, Set<Prayer>>{today: Prayer.values.toSet()},
      schedule: const ReminderSchedule(daysAhead: 2),
    );
    expect(reminders, isNotEmpty);
    expect(
      reminders.every((r) => r.at.day == 12),
      isTrue,
      reason: 'only tomorrow should be scheduled',
    );
  });

  test("Fajr's warning looks at yesterday's Isha", () {
    // Late on the 10th, looking ahead to Fajr on the 11th at 04:09.
    const schedule = ReminderSchedule(daysAhead: 1, quietHoursEnabled: false);
    final withIshaLogged = schedule.build(
      now: DateTime(2026, 9, 11, 0, 30),
      recordFor: recordsFrom(<DateTime, Set<Prayer>>{
        yesterday: <Prayer>{Prayer.isha},
      }),
      timingsFor: timingsOn,
    );
    expect(
      withIshaLogged.any((r) => r.title == 'لسه ما سجلتش العشاء'),
      isFalse,
    );

    final withoutIsha = schedule.build(
      now: DateTime(2026, 9, 11, 0, 30),
      recordFor: recordsFrom(const <DateTime, Set<Prayer>>{}),
      timingsFor: timingsOn,
    );
    final warning = withoutIsha.firstWhere(
      (r) => r.title == 'لسه ما سجلتش العشاء',
    );
    expect(warning.at, DateTime(2026, 9, 11, 3, 39)); // 04:09 - 30m
  });

  test('quiet hours keep the small hours free', () {
    const schedule = ReminderSchedule(daysAhead: 1);
    final reminders = schedule.build(
      now: DateTime(2026, 9, 11, 0, 30),
      recordFor: recordsFrom(const <DateTime, Set<Prayer>>{}),
      timingsFor: timingsOn,
    );

    // 03:39 and 04:39 both fall inside 23:00-06:00 and must not be scheduled.
    expect(reminders.any((r) => r.at.hour < 6), isFalse);
    // The day is not silenced though — Dhuhr onwards still gets reminders.
    expect(reminders, isNotEmpty);
  });

  test('quiet hours can be switched off', () {
    const schedule =
        ReminderSchedule(daysAhead: 1, quietHoursEnabled: false);
    final reminders = schedule.build(
      now: DateTime(2026, 9, 11, 0, 30),
      recordFor: recordsFrom(const <DateTime, Set<Prayer>>{}),
      timingsFor: timingsOn,
    );
    expect(reminders.any((r) => r.at.hour < 6), isTrue);
  });

  test('reminders come back in time order with unique ids', () {
    final reminders = build(
      now: DateTime(2026, 9, 11, 0, 30),
      schedule: const ReminderSchedule(daysAhead: 3),
    );

    expect(reminders, isNotEmpty);
    for (var i = 1; i < reminders.length; i++) {
      expect(
        reminders[i].at.isBefore(reminders[i - 1].at),
        isFalse,
        reason: 'reminders must be sorted by time',
      );
    }
    final ids = reminders.map((r) => r.id).toSet();
    expect(ids.length, reminders.length, reason: 'ids must be unique');
    expect(ReminderSchedule.allIds(), containsAll(ids));
  });

  test('scheduling covers the days ahead it is asked for', () {
    final days = build(
      now: DateTime(2026, 9, 11, 12, 0),
      schedule: const ReminderSchedule(daysAhead: 3),
    ).map((r) => r.at.day).toSet();

    expect(days, <int>{11, 12, 13});
  });
}
