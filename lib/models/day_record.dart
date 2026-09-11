import 'prayer.dart';

/// One calendar day's worth of prayer tracking.
///
/// A prayer is stored only once it has been marked, together with the moment
/// the user tapped it, so the history can show *when* each prayer was logged.
class DayRecord {
  DayRecord({
    required this.dateKey,
    Map<Prayer, DateTime>? markedAt,
    this.excusedAt,
  }) : markedAt = markedAt ?? <Prayer, DateTime>{};

  /// `yyyy-MM-dd` — the primary key of a day.
  final String dateKey;
  final Map<Prayer, DateTime> markedAt;

  /// When the day was marked as one the user could not pray on.
  ///
  /// Such a day counts as kept — the streak and the mosaic treat it exactly
  /// like a full one — but it is shown differently, because it is not the
  /// same thing as having prayed five times.
  final DateTime? excusedAt;

  bool get isExcused => excusedAt != null;

  /// The key the excused flag is stored under. It is deliberately not a prayer
  /// id, so older versions reading this day simply skip it.
  static const String excusedKey = '__excused__';

  DateTime get date => DateTime.parse(dateKey);

  bool isDone(Prayer prayer) => markedAt.containsKey(prayer);
  DateTime? timeOf(Prayer prayer) => markedAt[prayer];

  int get doneCount =>
      isExcused ? Prayer.values.length : markedAt.length;
  int get missedCount => Prayer.values.length - doneCount;
  bool get isComplete => isExcused || markedAt.length == Prayer.values.length;
  bool get isEmpty => markedAt.isEmpty && !isExcused;

  List<Prayer> get missedPrayers => isExcused
      ? const <Prayer>[]
      : Prayer.values.where((prayer) => !isDone(prayer)).toList();

  DayRecord copy() => DayRecord(
        dateKey: dateKey,
        markedAt: Map.of(markedAt),
        excusedAt: excusedAt,
      );

  DayRecord withExcused(DateTime? at) =>
      DayRecord(dateKey: dateKey, markedAt: Map.of(markedAt), excusedAt: at);

  Map<String, dynamic> toJson() => <String, dynamic>{
        for (final entry in markedAt.entries)
          entry.key.id: entry.value.toIso8601String(),
        if (excusedAt != null) excusedKey: excusedAt!.toIso8601String(),
      };

  factory DayRecord.fromJson(String dateKey, Map<String, dynamic> json) {
    final marked = <Prayer, DateTime>{};
    DateTime? excused;
    json.forEach((key, value) {
      if (value is! String) return;
      final time = DateTime.tryParse(value);
      if (time == null) return;
      if (key == excusedKey) {
        excused = time;
        return;
      }
      final prayer = Prayer.fromId(key);
      if (prayer != null) marked[prayer] = time;
    });
    return DayRecord(dateKey: dateKey, markedAt: marked, excusedAt: excused);
  }
}

/// `yyyy-MM-dd` key for a date, ignoring its time component.
String dateKeyOf(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// Midnight of the given date, so day-to-day comparisons are time-agnostic.
DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Single-letter Arabic weekday label, e.g. الأحد -> "ح".
///
/// `DateFormat.E('ar')` returns full words like "الأربعاء", which are far too
/// wide for the seven-across week strip on a narrow phone.
String arabicWeekdayLetter(DateTime date) {
  const List<String> letters = <String>['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
  // DateTime.weekday is 1 (Monday) through 7 (Sunday).
  return letters[date.weekday - 1];
}
