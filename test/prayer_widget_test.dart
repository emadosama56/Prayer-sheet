import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_sheet/models/prayer.dart';
import 'package:prayer_sheet/services/prayer_widget.dart';

void main() {
  group('which prayer the widget highlights', () {
    Prayer at(int hour, [int minute = 0]) => PrayerWidget.currentPrayer(
          now: DateTime(2026, 3, 10, hour, minute),
        );

    test('the small hours still belong to the night before', () {
      // Before dawn, Isha is the prayer that is open — not Fajr, whose day
      // has not started yet.
      expect(at(0), Prayer.isha);
      expect(at(3), Prayer.isha);
    });

    test('the clock walks through the day in order', () {
      expect(at(6), Prayer.fajr);
      expect(at(13), Prayer.dhuhr);
      expect(at(16), Prayer.asr);
      expect(at(19), Prayer.maghrib);
      expect(at(22), Prayer.isha);
    });

    test('every hour of the day lands on some prayer', () {
      for (var hour = 0; hour < 24; hour++) {
        expect(at(hour), isA<Prayer>());
      }
    });

    test('real prayer times are used when the location is known', () {
      // Cairo. Just after noon is Dhuhr by the sun, whatever the wall clock
      // rounding would have said.
      final prayer = PrayerWidget.currentPrayer(
        now: DateTime(2026, 3, 10, 12, 30),
        latitude: 30.0444,
        longitude: 31.2357,
      );
      expect(prayer, Prayer.dhuhr);
    });

    test('a nonsense location falls back instead of throwing', () {
      final prayer = PrayerWidget.currentPrayer(
        now: DateTime(2026, 3, 10, 13),
        latitude: 999,
        longitude: 999,
      );
      expect(prayer, isA<Prayer>());
    });
  });
}
