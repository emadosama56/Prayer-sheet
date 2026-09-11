import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_sheet/models/milestone.dart';
import 'package:prayer_sheet/models/mosaic.dart';

void main() {
  group('mosaic progress', () {
    test('a fresh collection has nothing placed', () {
      const progress = MosaicProgress(completeDays: 0);

      expect(progress.finishedCount, 0);
      expect(progress.piecesInCurrent, 0);
      expect(progress.piecesLeft, Mosaic.pieces);
      expect(progress.finished, isEmpty);
      expect(progress.justFinished, isFalse);
    });

    test('one complete day places one piece', () {
      const progress = MosaicProgress(completeDays: 1);

      expect(progress.piecesInCurrent, 1);
      expect(progress.piecesLeft, Mosaic.pieces - 1);
      expect(progress.finishedCount, 0);
    });

    test('nine complete days finish the first mosaic', () {
      const progress = MosaicProgress(completeDays: Mosaic.pieces);

      expect(progress.finishedCount, 1);
      expect(progress.piecesInCurrent, 0);
      expect(progress.justFinished, isTrue);
      expect(progress.finished, <Mosaic>[Mosaic.byIndex(0)]);
    });

    test('the next mosaic is a different one', () {
      const first = MosaicProgress(completeDays: 1);
      const second = MosaicProgress(completeDays: Mosaic.pieces + 1);

      expect(second.current, isNot(first.current));
      expect(second.piecesInCurrent, 1);
      expect(second.finishedCount, 1);
    });

    test('the collection keeps every finished mosaic in order', () {
      const progress = MosaicProgress(completeDays: Mosaic.pieces * 3 + 4);

      expect(progress.finishedCount, 3);
      expect(progress.piecesInCurrent, 4);
      expect(
        progress.finished,
        <Mosaic>[Mosaic.byIndex(0), Mosaic.byIndex(1), Mosaic.byIndex(2)],
      );
    });

    test('mosaics repeat once the set is exhausted, never running out', () {
      final beyond = MosaicProgress(
        completeDays: Mosaic.pieces * Mosaic.all.length + 1,
      );

      expect(beyond.current, Mosaic.byIndex(0));
      expect(beyond.finishedCount, Mosaic.all.length);
    });
  });

  group('milestones', () {
    List<Milestone> forStats({
      int completeDays = 0,
      int totalPrayers = 0,
      int bestStreak = 0,
      int finishedMosaics = 0,
    }) =>
        Milestone.forStats(
          completeDays: completeDays,
          totalPrayers: totalPrayers,
          bestStreak: bestStreak,
          finishedMosaics: finishedMosaics,
        );

    test('nothing is earned on an empty log', () {
      expect(forStats().where((m) => m.isEarned), isEmpty);
    });

    test('the first complete day earns exactly one badge', () {
      final earned = forStats(completeDays: 1, totalPrayers: 5)
          .where((m) => m.isEarned)
          .map((m) => m.title);

      expect(earned, <String>['أول يوم كامل']);
    });

    test('a seven day run earns the week badge', () {
      final earned = forStats(completeDays: 7, bestStreak: 7)
          .where((m) => m.isEarned)
          .map((m) => m.title);

      expect(earned, contains('أسبوع متواصل'));
    });

    test('progress towards an unearned badge is shown, not hidden', () {
      final week = forStats(bestStreak: 3)
          .firstWhere((m) => m.title == 'أسبوع متواصل');

      expect(week.isEarned, isFalse);
      expect(week.progress, closeTo(3 / 7, 0.001));
    });

    test('progress never runs past full', () {
      final first = forStats(completeDays: 50)
          .firstWhere((m) => m.title == 'أول يوم كامل');

      expect(first.progress, 1.0);
    });
  });
}
