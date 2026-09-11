import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/day_record.dart';
import '../models/prayer.dart';
import 'prayer_tile.dart';

/// Bottom sheet for reviewing — and fixing — any day, past or present.
class DayEditorSheet extends StatelessWidget {
  const DayEditorSheet({super.key, required this.date});

  final DateTime date;

  static Future<void> show(BuildContext context, DateTime date) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => DayEditorSheet(date: date),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = PrayerScope.of(context);
    final record = store.recordFor(date);
    final isToday = dateKeyOf(date) == dateKeyOf(DateTime.now());

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              isToday ? 'اليوم' : DateFormat.EEEE('ar').format(date),
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat.yMMMMd('ar').format(date),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            for (final prayer in Prayer.values) ...<Widget>[
              PrayerTile(
                prayer: prayer,
                isDone: record.isDone(prayer),
                markedAt: record.timeOf(prayer),
                onTap: () => store.toggle(date, prayer),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        record.isEmpty ? null : () => store.clearDay(date),
                    icon: const Icon(Icons.restart_alt, size: 20),
                    label: const Text('تفريغ اليوم'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        record.isComplete ? null : () => store.markAll(date),
                    icon: const Icon(Icons.done_all, size: 20),
                    label: const Text('تسجيل الكل'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
