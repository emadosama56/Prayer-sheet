import 'package:flutter/material.dart';

import '../main.dart';
import '../models/milestone.dart';
import '../models/mosaic.dart';
import '../widgets/mosaic_grid.dart';

/// What the log has added up to: the mosaic being built, the ones finished,
/// and the badges earned along the way.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = PrayerScope.of(context);
    final progress = MosaicProgress(completeDays: store.completeDays);
    final milestones = Milestone.forStats(
      completeDays: store.completeDays,
      totalPrayers: store.totalPrayers,
      bestStreak: store.bestStreak,
      finishedMosaics: progress.finishedCount,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('إنجازاتك')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _CurrentMosaic(progress: progress),
          const SizedBox(height: 24),
          _Heading('الأشكال المكتملة (${progress.finishedCount})'),
          const SizedBox(height: 10),
          _FinishedMosaics(progress: progress),
          const SizedBox(height: 24),
          const _Heading('أوسمة'),
          const SizedBox(height: 10),
          for (final milestone in milestones) ...<Widget>[
            _MilestoneTile(milestone: milestone),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Text(
            'كل يوم كامل يمنحك قطعة',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CurrentMosaic extends StatelessWidget {
  const _CurrentMosaic({required this.progress});

  final MosaicProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mosaic = progress.current;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Text(
            mosaic.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: mosaic.colour,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${progress.piecesInCurrent} من ${Mosaic.pieces} قطع',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          MosaicGrid(mosaic: mosaic, earned: progress.piecesInCurrent),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.piecesInCurrent / Mosaic.pieces,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(mosaic.colour),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            progress.piecesInCurrent == 0
                ? 'سجّل صلوات اليوم لتنال أول قطعة'
                : 'بقيت ${progress.piecesLeft} أيام كاملة لإتمام الشكل',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishedMosaics extends StatelessWidget {
  const _FinishedMosaics({required this.progress});

  final MosaicProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (progress.finishedCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Text(
          'لا يوجد شكل مكتمل بعد — الأول على بُعد '
          '${progress.piecesLeft} أيام',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        for (final mosaic in progress.finished)
          Column(
            children: <Widget>[
              MosaicGrid(mosaic: mosaic, earned: Mosaic.pieces, size: 92),
              const SizedBox(height: 6),
              SizedBox(
                width: 92,
                child: Text(
                  mosaic.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({required this.milestone});

  final Milestone milestone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final earned = milestone.isEarned;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: earned ? scheme.primaryContainer : scheme.surface,
        border: Border.all(
          color: earned ? Colors.transparent : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: earned
                  ? scheme.primary.withOpacity(0.2)
                  : scheme.surfaceContainerHighest,
            ),
            child: Icon(
              milestone.icon,
              size: 20,
              color: earned ? scheme.onPrimaryContainer : scheme.outline,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  milestone.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: earned ? scheme.onPrimaryContainer : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  milestone.detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: earned
                        ? scheme.onPrimaryContainer.withOpacity(0.8)
                        : scheme.onSurfaceVariant,
                  ),
                ),
                if (!earned) ...<Widget>[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: milestone.progress,
                      minHeight: 5,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (earned)
            Icon(Icons.check_circle, color: scheme.primary, size: 22),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
