import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/day_record.dart';
import '../models/prayer.dart';

/// The card at the top of the home screen: today's date and progress.
class TodayHeader extends StatelessWidget {
  const TodayHeader({
    super.key,
    required this.today,
    required this.record,
    required this.streak,
  });

  final DateTime today;
  final DayRecord record;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = Prayer.values.length;
    final done = record.doneCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: <Color>[
            scheme.primary,
            Color.alphaBlend(Colors.black.withOpacity(0.25), scheme.primary),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      DateFormat.EEEE('ar').format(today),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.yMMMMd('ar').format(today),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onPrimary.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              _ProgressRing(done: done, total: total),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            record.isComplete
                ? 'ما شاء الله، اكتملت صلوات اليوم 🤍'
                : 'باقي ${record.missedCount} من ${Prayer.values.length} صلوات',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (streak > 0) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(Icons.local_fire_department,
                    size: 18, color: scheme.onPrimary.withOpacity(0.9)),
                const SizedBox(width: 6),
                Text(
                  'سلسلة أيام كاملة: $streak',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimary.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              tween: Tween<double>(begin: 0, end: done / total),
              builder: (BuildContext context, double value, _) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  backgroundColor: scheme.onPrimary.withOpacity(0.25),
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                );
              },
            ),
          ),
          Text(
            '$done/$total',
            textDirection: TextDirection.ltr,
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
