// adhan exports its own Prayer enum, which would clash with this app's.
import 'package:adhan/adhan.dart' hide Prayer;

import 'prayer.dart';

/// The five prayer times for one day at one place.
///
/// Computed on the device rather than fetched: the arithmetic is the same
/// everywhere, and it keeps the reminders working with no network, no server
/// to be down, and no round trip before the app can schedule anything.
class DayTimings {
  const DayTimings(this._times);

  final Map<Prayer, DateTime> _times;

  DateTime operator [](Prayer prayer) => _times[prayer]!;

  Map<Prayer, DateTime> get all => Map<Prayer, DateTime>.unmodifiable(_times);

  /// Times for [date] at [latitude]/[longitude], in the device's local zone.
  factory DayTimings.forDate({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) {
    final params = CalculationMethod.egyptian.getParameters()
      ..madhab = Madhab.shafi;
    final times = PrayerTimes(
      Coordinates(latitude, longitude),
      DateComponents(date.year, date.month, date.day),
      params,
    );

    return DayTimings(<Prayer, DateTime>{
      Prayer.fajr: times.fajr,
      Prayer.dhuhr: times.dhuhr,
      Prayer.asr: times.asr,
      Prayer.maghrib: times.maghrib,
      Prayer.isha: times.isha,
    });
  }
}
