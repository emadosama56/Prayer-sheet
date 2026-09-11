import 'package:flutter/material.dart';

import '../models/day_record.dart';
import '../models/prayer.dart';
import '../theme.dart';

/// Five small dots summarising which prayers of a day were logged.
class DayDots extends StatelessWidget {
  const DayDots({super.key, required this.record, this.size = 10});

  final DayRecord record;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final prayer in Prayer.values)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 5),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: record.isExcused
                    ? kExcusedColor
                    : record.isDone(prayer)
                        ? scheme.primary
                        : scheme.outlineVariant,
              ),
            ),
          ),
      ],
    );
  }
}
