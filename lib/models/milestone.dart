import 'package:flutter/material.dart';

/// A one-off badge, earned once and kept.
class Milestone {
  const Milestone({
    required this.title,
    required this.detail,
    required this.icon,
    required this.isEarned,
    required this.progress,
  });

  final String title;
  final String detail;
  final IconData icon;
  final bool isEarned;

  /// 0..1 towards earning it, so an unearned badge still shows movement.
  final double progress;

  static List<Milestone> forStats({
    required int completeDays,
    required int totalPrayers,
    required int bestStreak,
    required int finishedMosaics,
  }) {
    Milestone at({
      required String title,
      required int value,
      required int target,
      required IconData icon,
      required String detail,
    }) =>
        Milestone(
          title: title,
          detail: detail,
          icon: icon,
          isEarned: value >= target,
          progress: target == 0 ? 1 : (value / target).clamp(0.0, 1.0),
        );

    return <Milestone>[
      at(
        title: 'أول يوم كامل',
        detail: 'تسجّل الخمس صلوات في يوم',
        value: completeDays,
        target: 1,
        icon: Icons.verified_outlined,
      ),
      at(
        title: 'أسبوع متواصل',
        detail: '٧ أيام كاملة ورا بعض',
        value: bestStreak,
        target: 7,
        icon: Icons.local_fire_department_outlined,
      ),
      at(
        title: 'أول شكل مكتمل',
        detail: 'تجمع ٩ قطع وتكمّل شكل',
        value: finishedMosaics,
        target: 1,
        icon: Icons.extension_outlined,
      ),
      at(
        title: 'مية صلاة',
        detail: '١٠٠ صلاة مسجّلة',
        value: totalPrayers,
        target: 100,
        icon: Icons.mosque_outlined,
      ),
      at(
        title: 'شهر كامل',
        detail: '٣٠ يوم كامل',
        value: completeDays,
        target: 30,
        icon: Icons.calendar_month_outlined,
      ),
      at(
        title: 'أربعين يوم',
        detail: '٤٠ يوم متواصل من غير ما تفوّت',
        value: bestStreak,
        target: 40,
        icon: Icons.emoji_events_outlined,
      ),
    ];
  }
}
