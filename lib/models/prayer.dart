import 'package:flutter/material.dart';

/// The five obligatory daily prayers, in order.
enum Prayer {
  fajr(id: 'fajr', arabicName: 'الفجر', icon: Icons.wb_twilight),
  dhuhr(id: 'dhuhr', arabicName: 'الظهر', icon: Icons.light_mode),
  asr(id: 'asr', arabicName: 'العصر', icon: Icons.wb_sunny_outlined),
  maghrib(id: 'maghrib', arabicName: 'المغرب', icon: Icons.brightness_4),
  isha(id: 'isha', arabicName: 'العشاء', icon: Icons.nightlight_round);

  const Prayer({required this.id, required this.arabicName, required this.icon});

  /// Stable key used for persistence — never change these strings.
  final String id;
  final String arabicName;
  final IconData icon;

  static Prayer? fromId(String id) {
    for (final prayer in Prayer.values) {
      if (prayer.id == id) return prayer;
    }
    return null;
  }
}
