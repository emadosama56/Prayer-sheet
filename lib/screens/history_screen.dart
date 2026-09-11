import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../main.dart';
import '../models/day_record.dart';
import '../models/prayer.dart';
import '../services/prayer_store.dart';
import '../widgets/day_dots.dart';
import '../widgets/day_editor_sheet.dart';
import '../theme.dart';

/// Every day that has at least one logged prayer, newest first.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = PrayerScope.of(context);
    final history = store.history();

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الأيام'),
        actions: <Widget>[
          if (history.isNotEmpty)
            IconButton(
              tooltip: 'مسح السجل',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmClearAll(context, store),
            ),
        ],
      ),
      body: history.isEmpty
          ? const _EmptyHistory()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: history.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) return _StatsRow(store: store);
                return _HistoryRow(record: history[index - 1]);
              },
            ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, PrayerStore store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('مسح السجل كله؟'),
        content: const Text('سيتم حذف كل الأيام المسجلة ولا يمكن التراجع.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await store.clearAll();
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.store});

  final PrayerStore store;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          _StatCard(
            label: 'أيام كاملة',
            value: '${store.completeDays}',
            icon: Icons.verified_outlined,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'إجمالي الصلوات',
            value: '${store.totalPrayers}',
            icon: Icons.mosque_outlined,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'السلسلة',
            value: '${store.currentStreak()}',
            icon: Icons.local_fire_department_outlined,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record});

  final DayRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = record.date;
    final total = Prayer.values.length;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => DayEditorSheet.show(context, date),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        DateFormat.EEEE('ar').format(date),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat.yMMMMd('ar').format(date),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      DayDots(record: record),
                      if (!record.isComplete) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'لم تُسجَّل: '
                          '${record.missedPrayers.map((Prayer p) => p.arabicName).join('، ')}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: record.isExcused
                        ? kExcusedColor.withOpacity(0.18)
                        : record.isComplete
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    record.isExcused ? 'عذر' : '${record.doneCount}/$total',
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: record.isExcused
                          ? kExcusedColor
                          : record.isComplete
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.event_note_outlined,
                size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'لا يوجد سجل بعد',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'ابدأ بتسجيل صلوات اليوم وسيظهر السجل هنا.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
