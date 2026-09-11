import 'package:flutter/material.dart';

import '../main.dart';
import '../models/day_record.dart';
import '../models/prayer.dart';
import '../widgets/day_editor_sheet.dart';
import '../widgets/prayer_tile.dart';
import '../widgets/today_header.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime _today = dayOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reopening the app after midnight must roll the sheet over to the new day.
    if (state != AppLifecycleState.resumed) return;
    final now = dayOnly(DateTime.now());
    if (now != _today) setState(() => _today = now);
  }

  @override
  Widget build(BuildContext context) {
    final store = PrayerScope.of(context);
    final record = store.recordFor(_today);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الصلاة'),
        actions: <Widget>[
          IconButton(
            tooltip: 'سجل الأيام',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const HistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          TodayHeader(
            today: _today,
            record: record,
            streak: store.currentStreak(today: _today),
          ),
          const SizedBox(height: 16),
          _WeekStrip(
            today: _today,
            days: store.recentDays(7, today: _today),
            onDayTap: (DateTime date) => DayEditorSheet.show(context, date),
          ),
          const SizedBox(height: 20),
          for (final prayer in Prayer.values) ...<Widget>[
            PrayerTile(
              prayer: prayer,
              isDone: record.isDone(prayer),
              markedAt: record.timeOf(prayer),
              onTap: () => store.toggle(_today, prayer),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          if (!record.isComplete)
            FilledButton.icon(
              onPressed: () => store.markAll(_today),
              icon: const Icon(Icons.done_all),
              label: const Text('تسجيل كل صلوات اليوم'),
            ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const HistoryScreen(),
              ),
            ),
            icon: const Icon(Icons.calendar_month),
            label: const Text('عرض سجل الأيام السابقة'),
          ),
          const SizedBox(height: 24),
          const _Dedication(),
        ],
      ),
    );
  }
}

/// A small dua at the foot of the home screen.
class _Dedication extends StatelessWidget {
  const _Dedication();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: <Widget>[
        Divider(color: scheme.outlineVariant, height: 1),
        const SizedBox(height: 18),
        Icon(Icons.favorite, size: 16, color: scheme.primary.withOpacity(0.7)),
        const SizedBox(height: 10),
        Text(
          'تقبل الله من عمداوى و جانجوناااا',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.primary,
            height: 1.6,
          ),
        ),
        Text(
          'و جمعهم دايما مع بعض فى كل حاجة حلوة',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

/// The last seven days as tappable chips, oldest first.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.today,
    required this.days,
    required this.onDayTap,
  });

  final DateTime today;
  final List<DayRecord> days;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        // Expanded keeps all seven days inside the row on any screen width.
        for (final record in days)
          Expanded(
            child: _DayChip(
              record: record,
              isToday: dateKeyOf(record.date) == dateKeyOf(today),
              onTap: () => onDayTap(record.date),
            ),
          ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.record,
    required this.isToday,
    required this.onTap,
  });

  final DayRecord record;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ratio = record.doneCount / Prayer.values.length;

    final Color fill;
    if (record.isComplete) {
      fill = scheme.primary;
    } else if (record.doneCount == 0) {
      fill = scheme.surfaceContainerHighest;
    } else {
      fill = Color.lerp(scheme.surfaceContainerHighest, scheme.primary, ratio)!;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Column(
          children: <Widget>[
            Text(
              arabicWeekdayLetter(record.date),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                border:
                    isToday ? Border.all(color: scheme.primary, width: 2) : null,
              ),
              child: Text(
                '${record.doneCount}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ratio > 0.5
                      ? scheme.onPrimary
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
