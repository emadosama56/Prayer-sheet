import '../models/day_record.dart';
import '../models/day_timings.dart';
import '../models/prayer.dart';

/// Why a reminder is being sent.
enum ReminderKind {
  /// Shortly before a prayer, because the one before it is still unlogged.
  beforePrayer,

  /// Shortly after a prayer's time, to log that prayer.
  afterPrayer,
}

/// One reminder to hand to the notification plugin.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;

  @override
  String toString() => 'ScheduledReminder($id, $at, $title)';
}

/// Works out which reminders should exist, given the prayer times and what has
/// already been logged.
///
/// Kept free of plugins and I/O so the rules — and they are the whole feature —
/// can be tested directly.
class ReminderSchedule {
  const ReminderSchedule({
    this.leadTime = const Duration(minutes: 30),
    this.followUpDelay = const Duration(minutes: 30),
    this.daysAhead = 3,
    this.quietFrom = 23,
    this.quietUntil = 6,
    this.quietHoursEnabled = true,
  });

  /// How long before a prayer to warn about the previous one.
  final Duration leadTime;

  /// How long after a prayer's time to ask for it to be logged.
  final Duration followUpDelay;

  /// How many days to schedule in advance, so reminders keep coming even if
  /// the app is not opened.
  final int daysAhead;

  /// Hour the quiet window opens, and the hour it closes the next morning.
  final int quietFrom;
  final int quietUntil;
  final bool quietHoursEnabled;

  /// Every reminder that should be pending right now.
  ///
  /// [recordFor] and [timingsFor] are asked for each day in range; only days
  /// in the past are never consulted.
  List<ScheduledReminder> build({
    required DateTime now,
    required DayRecord Function(DateTime day) recordFor,
    required DayTimings Function(DateTime day) timingsFor,
  }) {
    final reminders = <ScheduledReminder>[];
    final today = dayOnly(now);

    for (var offset = 0; offset < daysAhead; offset++) {
      final day = today.add(Duration(days: offset));
      final record = recordFor(day);

      // Once the whole day is logged there is nothing left to nag about, so
      // the day goes quiet until tomorrow.
      if (record.isComplete) continue;

      final timings = timingsFor(day);
      final previousRecord = recordFor(day.subtract(const Duration(days: 1)));

      for (var index = 0; index < Prayer.values.length; index++) {
        final prayer = Prayer.values[index];
        final prayerTime = timings[prayer];

        if (!record.isDone(prayer)) {
          _add(
            reminders,
            now: now,
            id: _idFor(offset, index, ReminderKind.afterPrayer),
            at: prayerTime.add(followUpDelay),
            title: 'دخل وقت ${prayer.arabicName}',
            body: 'متنساش تسجلها في التطبيق 🙏',
          );
        }

        // The prayer before this one — yesterday's Isha for Fajr.
        final Prayer previousPrayer =
            index == 0 ? Prayer.isha : Prayer.values[index - 1];
        final bool previousDone = index == 0
            ? previousRecord.isDone(Prayer.isha)
            : record.isDone(previousPrayer);

        if (!previousDone) {
          _add(
            reminders,
            now: now,
            id: _idFor(offset, index, ReminderKind.beforePrayer),
            at: prayerTime.subtract(leadTime),
            title: 'لسه ما سجلتش ${previousPrayer.arabicName}',
            body:
                '${prayer.arabicName} قرب يدخل — متخسرش عدد الايام و خليك مكمل 👏',
          );
        }
      }
    }

    reminders.sort((a, b) => a.at.compareTo(b.at));
    return reminders;
  }

  void _add(
    List<ScheduledReminder> into, {
    required DateTime now,
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) {
    if (!at.isAfter(now)) return;
    if (isQuiet(at)) return;
    into.add(ScheduledReminder(id: id, at: at, title: title, body: body));
  }

  /// Whether [moment] falls in the do-not-disturb window.
  bool isQuiet(DateTime moment) {
    if (!quietHoursEnabled) return false;
    final hour = moment.hour;
    // The window wraps past midnight, so it is two ranges, not one.
    if (quietFrom <= quietUntil) return hour >= quietFrom && hour < quietUntil;
    return hour >= quietFrom || hour < quietUntil;
  }

  /// Ids are derived, not sequential, so a reschedule replaces the previous
  /// run's notifications instead of stacking new ones beside them.
  static int _idFor(int dayOffset, int prayerIndex, ReminderKind kind) =>
      2000 + dayOffset * 100 + prayerIndex * 10 + kind.index;

  /// Every id this schedule could ever use, for cancelling old runs.
  static List<int> allIds({int daysAhead = 7}) => <int>[
        for (var day = 0; day < daysAhead; day++)
          for (var prayer = 0; prayer < Prayer.values.length; prayer++)
            for (final kind in ReminderKind.values)
              _idFor(day, prayer, kind),
      ];
}
