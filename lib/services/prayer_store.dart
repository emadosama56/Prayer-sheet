import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/day_record.dart';
import '../models/prayer.dart';

/// Holds every tracked day and persists it to the device.
///
/// Everything lives in a single JSON blob under [_storageKey]; a year of
/// tracking is only a few kilobytes, so there is no need for a database.
class PrayerStore extends ChangeNotifier {
  static const String _storageKey = 'prayer_records_v1';

  final Map<String, DayRecord> _records = <String, DayRecord>{};
  SharedPreferences? _prefs;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((dateKey, value) {
          if (value is! Map<String, dynamic>) return;
          final record = DayRecord.fromJson(dateKey, value);
          if (!record.isEmpty) _records[dateKey] = record;
        });
      } on FormatException {
        // Unreadable data: start over rather than block the whole app.
        _records.clear();
      }
    }
    _isLoaded = true;
    notifyListeners();
  }

  /// The record for [date] — an empty one if the day was never touched.
  DayRecord recordFor(DateTime date) {
    final key = dateKeyOf(date);
    return _records[key] ?? DayRecord(dateKey: key);
  }

  bool isDone(DateTime date, Prayer prayer) => recordFor(date).isDone(prayer);

  /// Marks [prayer] on [date] as prayed, or clears it if it already was.
  Future<void> toggle(DateTime date, Prayer prayer) async {
    final key = dateKeyOf(date);
    final record = (_records[key] ?? DayRecord(dateKey: key)).copy();

    if (record.isDone(prayer)) {
      record.markedAt.remove(prayer);
    } else {
      record.markedAt[prayer] = DateTime.now();
    }

    if (record.isEmpty) {
      _records.remove(key);
    } else {
      _records[key] = record;
    }

    notifyListeners();
    await _persist();
  }

  /// Marks every remaining prayer of [date] as prayed.
  Future<void> markAll(DateTime date) async {
    final key = dateKeyOf(date);
    final record = (_records[key] ?? DayRecord(dateKey: key)).copy();
    final now = DateTime.now();
    for (final prayer in Prayer.values) {
      record.markedAt.putIfAbsent(prayer, () => now);
    }
    _records[key] = record;
    notifyListeners();
    await _persist();
  }

  Future<void> clearDay(DateTime date) async {
    if (_records.remove(dateKeyOf(date)) == null) return;
    notifyListeners();
    await _persist();
  }

  Future<void> clearAll() async {
    if (_records.isEmpty) return;
    _records.clear();
    notifyListeners();
    await _persist();
  }

  /// Every tracked day, newest first.
  List<DayRecord> history() {
    final records = _records.values.toList()
      ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return records;
  }

  /// The last [days] days ending today, oldest first — including untouched
  /// days, so the weekly strip always has a fixed width.
  List<DayRecord> recentDays(int days, {DateTime? today}) {
    final end = dayOnly(today ?? DateTime.now());
    return <DayRecord>[
      for (var offset = days - 1; offset >= 0; offset--)
        recordFor(end.subtract(Duration(days: offset))),
    ];
  }

  int get trackedDays => _records.length;

  int get completeDays =>
      _records.values.where((record) => record.isComplete).length;

  int get totalPrayers =>
      _records.values.fold(0, (sum, record) => sum + record.doneCount);

  /// Consecutive complete days counting back from today. Today being
  /// unfinished does not break the streak — the day is not over yet.
  /// The longest run of consecutive complete days ever recorded.
  ///
  /// Kept separate from [currentStreak] so a badge already earned is not taken
  /// back the first time a day is missed.
  int get bestStreak {
    final days = _records.values
        .where((record) => record.isComplete)
        .map((record) => dayOnly(record.date))
        .toList()
      ..sort();
    if (days.isEmpty) return 0;

    var best = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      final isNextDay =
          days[i].difference(days[i - 1]) == const Duration(days: 1);
      run = isNextDay ? run + 1 : 1;
      if (run > best) best = run;
    }
    return best;
  }

  int currentStreak({DateTime? today}) {
    var cursor = dayOnly(today ?? DateTime.now());
    if (!recordFor(cursor).isComplete) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (recordFor(cursor).isComplete) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// The whole log as plain JSON, for backup or upload.
  Map<String, dynamic> exportRecords() => <String, dynamic>{
        for (final entry in _records.entries) entry.key: entry.value.toJson(),
      };

  /// Folds another device's log into this one.
  ///
  /// Days and prayers are unioned rather than overwritten, and the earlier
  /// timestamp wins for a prayer both sides logged. Two phones can then be
  /// merged in either direction without either losing a day.
  Future<void> mergeRecords(Map<String, dynamic> incoming) async {
    var changed = false;

    incoming.forEach((dateKey, value) {
      if (value is! Map) return;
      final remote = DayRecord.fromJson(
        dateKey,
        value.map((key, v) => MapEntry(key.toString(), v)),
      );
      if (remote.isEmpty) return;

      final local = _records[dateKey];
      if (local == null) {
        _records[dateKey] = remote;
        changed = true;
        return;
      }

      remote.markedAt.forEach((prayer, at) {
        final mine = local.markedAt[prayer];
        if (mine == null || at.isBefore(mine)) {
          local.markedAt[prayer] = at;
          changed = true;
        }
      });
    });

    if (!changed) return;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final payload = <String, dynamic>{
      for (final entry in _records.entries) entry.key: entry.value.toJson(),
    };
    await prefs.setString(_storageKey, jsonEncode(payload));
  }
}
