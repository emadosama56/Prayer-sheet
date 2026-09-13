import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/day_record.dart';
import '../models/day_timings.dart';
import '../models/prayer.dart';
import 'prayer_store.dart';

/// Keeps the home screen widget in step with the log.
///
/// The widget is a native view that cannot read the app's memory, so every
/// value it draws is written here first and read back on the other side.
class PrayerWidget {
  static const String _androidName = 'PrayerWidgetProvider';

  /// Pushes the current state out to the widget.
  static Future<void> update(
    PrayerStore store, {
    DateTime? now,
    double? latitude,
    double? longitude,
  }) async {
    if (kIsWeb) return;

    final today = now ?? DateTime.now();
    final record = store.recordFor(today);

    try {
      await HomeWidget.saveWidgetData<String>(
        'date',
        DateFormat.MMMMd('ar').format(today),
      );
      await HomeWidget.saveWidgetData<String>(
        'count',
        '${record.doneCount}/${Prayer.values.length}',
      );
      await HomeWidget.saveWidgetData<bool>('excused', record.isExcused);
      await HomeWidget.saveWidgetData<String>(
        'streak',
        streakLabel(store.currentStreak(today: today)),
      );

      for (final prayer in Prayer.values) {
        await HomeWidget.saveWidgetData<String>(
          'name_${prayer.id}',
          prayer.arabicName,
        );
        await HomeWidget.saveWidgetData<bool>(
          'done_${prayer.id}',
          record.isExcused || record.isDone(prayer),
        );
      }

      // Highlighting the prayer whose time it is turns "log something" into
      // "log this", which is the whole point of a one-tap widget.
      final current = currentPrayer(
        now: today,
        latitude: latitude,
        longitude: longitude,
      );
      await HomeWidget.saveWidgetData<String>('current', current.id);

      await HomeWidget.updateWidget(androidName: _androidName);
    } catch (error) {
      // A missing widget, or a launcher that does not support them, must not
      // break logging a prayer.
      debugPrint('widget update failed: $error');
    }
  }

  /// The streak as it reads on the widget, or empty when there is none.
  ///
  /// Arabic counts nouns by how many there are, so a single form would read
  /// as broken text for most values.
  static String streakLabel(int days) {
    if (days <= 0) return '';
    if (days == 1) return '🔥 يوم';
    if (days == 2) return '🔥 يومان';
    if (days <= 10) return '🔥 $days أيام';
    return '🔥 $days يومًا';
  }

  /// The prayer the current moment belongs to.
  ///
  /// Before dawn the day still belongs to the night before, so the answer is
  /// Isha rather than the first prayer of a day that has not started.
  static Prayer currentPrayer({
    required DateTime now,
    double? latitude,
    double? longitude,
  }) {
    if (latitude == null || longitude == null) return _byClock(now);

    try {
      final timings = DayTimings.forDate(
        date: dayOnly(now),
        latitude: latitude,
        longitude: longitude,
      );
      Prayer current = Prayer.isha;
      for (final prayer in Prayer.values) {
        if (!now.isBefore(timings[prayer])) current = prayer;
      }
      return current;
    } catch (_) {
      return _byClock(now);
    }
  }

  /// A rough fallback for when there is no location to compute times from.
  static Prayer _byClock(DateTime now) {
    final hour = now.hour;
    if (hour < 5) return Prayer.isha;
    if (hour < 12) return Prayer.fajr;
    if (hour < 15) return Prayer.dhuhr;
    if (hour < 18) return Prayer.asr;
    if (hour < 20) return Prayer.maghrib;
    return Prayer.isha;
  }
}

/// Runs when a prayer is tapped on the home screen, with the app closed.
///
/// Top-level and marked as an entry point so the compiler keeps it: the
/// background isolate looks it up by name.
@pragma('vm:entry-point')
Future<void> onWidgetTapped(Uri? uri) async {
  if (uri == null) return;

  final prayer = Prayer.fromId(uri.queryParameters['prayer'] ?? '');
  if (prayer == null) return;

  // A fresh store: this isolate does not share the running app's memory, and
  // both read the same stored log.
  final store = PrayerStore();
  await store.load();
  await store.toggle(DateTime.now(), prayer);
  await PrayerWidget.update(store);
}
