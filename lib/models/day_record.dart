import 'prayer.dart';

/// One calendar day's worth of prayer tracking.
///
/// A prayer is stored only once it has been marked, together with the moment
/// the user tapped it, so the history can show *when* each prayer was logged.
class DayRecord {
  DayRecord({required this.dateKey, Map<Prayer, DateTime>? markedAt})
      : markedAt = markedAt ?? <Prayer, DateTime>{};

  /// `yyyy-MM-dd` — the primary key of a day.
  final String dateKey;
  final Map<Prayer, DateTime> markedAt;

  DateTime get date => DateTime.parse(dateKey);

  bool isDone(Prayer prayer) => markedAt.containsKey(prayer);
  DateTime? timeOf(Prayer prayer) => markedAt[prayer];

  int get doneCount => markedAt.length;
  int get missedCount => Prayer.values.length - doneCount;
  bool get isComplete => doneCount == Prayer.values.length;
  bool get isEmpty => markedAt.isEmpty;

  List<Prayer> get missedPrayers =>
      Prayer.values.where((prayer) => !isDone(prayer)).toList();

  DayRecord copy() => DayRecord(dateKey: dateKey, markedAt: Map.of(markedAt));

  Map<String, dynamic> toJson() => <String, dynamic>{
        for (final entry in markedAt.entries)
          entry.key.id: entry.value.toIso8601String(),
      };

  factory DayRecord.fromJson(String dateKey, Map<String, dynamic> json) {
    final marked = <Prayer, DateTime>{};
    json.forEach((key, value) {
      final prayer = Prayer.fromId(key);
      if (prayer == null || value is! String) return;
      final time = DateTime.tryParse(value);
      if (time != null) marked[prayer] = time;
    });
    return DayRecord(dateKey: dateKey, markedAt: marked);
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
