import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/prayer.dart';

/// A single prayer row: tap anywhere on it to mark it as prayed.
class PrayerTile extends StatelessWidget {
  const PrayerTile({
    super.key,
    required this.prayer,
    required this.isDone,
    required this.onTap,
    this.markedAt,
  });

  final Prayer prayer;
  final bool isDone;
  final DateTime? markedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final background = isDone ? scheme.primaryContainer : scheme.surface;
    final foreground = isDone ? scheme.onPrimaryContainer : scheme.onSurface;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDone ? Colors.transparent : scheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? scheme.primary.withOpacity(0.18)
                        : scheme.surfaceContainerHighest,
                  ),
                  child: Icon(prayer.icon, size: 22, color: foreground),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        prayer.arabicName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isDone && markedAt != null
                            ? 'تم التسجيل ${DateFormat.jm('ar').format(markedAt!)}'
                            : 'اضغط للتسجيل',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: foreground.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? scheme.primary : Colors.transparent,
                    border: Border.all(
                      color: isDone ? scheme.primary : scheme.outline,
                      width: 2,
                    ),
                  ),
                  child: isDone
                      ? Icon(Icons.check, size: 18, color: scheme.onPrimary)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
