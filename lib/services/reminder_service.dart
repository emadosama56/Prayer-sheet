import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/day_timings.dart';
import 'location_service.dart';
import 'prayer_store.dart';
import 'reminder_schedule.dart';

/// How the reminders decide when to fire.
enum ReminderMode {
  /// Around the actual prayer times, and only for what is still unlogged.
  smart,

  /// A plain repeating nudge, for anyone who would rather not bother with
  /// locations and prayer times.
  everyTwoHours,
}

/// Owns the reminder settings and keeps the scheduled notifications in step
/// with what has been logged.
class ReminderService extends ChangeNotifier {
  ReminderService({
    FlutterLocalNotificationsPlugin? plugin,
    LocationService location = const LocationService(),
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _location = location;

  static const Duration everyTwoHoursInterval = Duration(hours: 2);

  static const String fallbackTitle = 'سجلت صلاتك؟ ممكن متنساش 🙏 ؟';
  static const String fallbackBody = 'متخسرش عدد الايام و خليك مكمل 👏';

  static const int _periodicId = 1001;
  static const String _enabledKey = 'reminders_enabled_v1';
  static const String _soundKey = 'reminders_sound_v1';
  static const String _modeKey = 'reminders_mode_v1';
  static const String _quietKey = 'reminders_quiet_v1';

  /// An Android channel's sound is fixed once the channel exists, so silencing
  /// the reminder means moving it to a second, soundless channel rather than
  /// editing the first.
  static const String _channelId = 'prayer_reminders_v1';
  static const String _silentChannelId = 'prayer_reminders_silent_v1';

  final FlutterLocalNotificationsPlugin _plugin;
  final LocationService _location;

  bool _isEnabled = false;
  bool _isSoundOn = true;
  bool _quietHoursEnabled = true;
  ReminderMode _mode = ReminderMode.smart;
  bool _isSupported = false;
  ResolvedLocation? _place;

  bool get isEnabled => _isEnabled;
  bool get isSoundOn => _isSoundOn;
  bool get quietHoursEnabled => _quietHoursEnabled;
  ReminderMode get mode => _mode;

  /// False where local notifications are not available (web, tests).
  bool get isSupported => _isSupported;

  /// The place the prayer times are computed for, once known.
  ResolvedLocation? get place => _place;

  ReminderSchedule get _schedule =>
      ReminderSchedule(quietHoursEnabled: _quietHoursEnabled);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_enabledKey) ?? false;
    _isSoundOn = prefs.getBool(_soundKey) ?? true;
    _quietHoursEnabled = prefs.getBool(_quietKey) ?? true;
    _mode = (prefs.getString(_modeKey) == ReminderMode.everyTwoHours.name)
        ? ReminderMode.everyTwoHours
        : ReminderMode.smart;

    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(
        tz.getLocation(await FlutterTimezone.getLocalTimezone()),
      );
    } catch (_) {
      // Any failure here leaves tz on UTC, which only matters on a device,
      // where this call does work. Catching Error as well as Exception: an
      // absent plugin surfaces as a type error on the returned null.
    }

    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_reminder'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      );
      _isSupported = await _plugin.initialize(settings) ?? false;
    } on Exception {
      _isSupported = false;
    }

    _place = await _location.current();
    notifyListeners();
  }

  /// Turns reminders on — asking for permission first — or off.
  ///
  /// Returns whether they are on afterwards; false means the permission was
  /// refused.
  Future<bool> setEnabled(bool enabled, {PrayerStore? store}) async {
    if (!_isSupported) return false;

    if (enabled && !await _requestPermission()) {
      _isEnabled = false;
      notifyListeners();
      return false;
    }

    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);

    await reschedule(store);
    notifyListeners();
    return enabled;
  }

  Future<void> setSoundOn(bool withSound, {PrayerStore? store}) async {
    if (_isSoundOn == withSound) return;
    _isSoundOn = withSound;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, withSound);
    await reschedule(store);
    notifyListeners();
  }

  Future<void> setQuietHoursEnabled(bool enabled, {PrayerStore? store}) async {
    if (_quietHoursEnabled == enabled) return;
    _quietHoursEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_quietKey, enabled);
    await reschedule(store);
    notifyListeners();
  }

  Future<void> setMode(ReminderMode mode, {PrayerStore? store}) async {
    if (_mode == mode) return;
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
    await reschedule(store);
    notifyListeners();
  }

  /// Looks the user's location up again and reschedules around it.
  Future<ResolvedLocation> refreshLocation({PrayerStore? store}) async {
    _place = await _location.refresh();
    await reschedule(store);
    notifyListeners();
    return _place!;
  }

  /// Rebuilds every pending notification from the current settings and log.
  ///
  /// Called whenever anything they depend on changes — a prayer logged, a
  /// setting flipped, the app reopened — because a scheduled notification
  /// cannot make decisions of its own once it has been handed to the OS.
  Future<void> reschedule(PrayerStore? store) async {
    if (!_isSupported) return;

    await _cancelAll();
    if (!_isEnabled) return;

    if (_mode == ReminderMode.everyTwoHours || store == null) {
      await _plugin.periodicallyShowWithDuration(
        _periodicId,
        fallbackTitle,
        fallbackBody,
        everyTwoHoursInterval,
        _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return;
    }

    final place = _place ?? await _location.current();
    final reminders = _schedule.build(
      now: DateTime.now(),
      recordFor: store.recordFor,
      timingsFor: (DateTime day) => DayTimings.forDate(
        date: day,
        latitude: place.latitude,
        longitude: place.longitude,
      ),
    );

    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        reminder.id,
        reminder.title,
        reminder.body,
        tz.TZDateTime.from(reminder.at, tz.local),
        _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> _cancelAll() async {
    await _plugin.cancel(_periodicId);
    for (final id in ReminderSchedule.allIds()) {
      await _plugin.cancel(id);
    }
  }

  NotificationDetails _details() => NotificationDetails(
        android: AndroidNotificationDetails(
          _isSoundOn ? _channelId : _silentChannelId,
          _isSoundOn ? 'تذكير الصلاة' : 'تذكير الصلاة (صامت)',
          channelDescription: 'تذكير بتسجيل الصلاة',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          // The app's own soft chime instead of the system notification tone.
          sound: _isSoundOn
              ? const RawResourceAndroidNotificationSound('soft_chime')
              : null,
          playSound: _isSoundOn,
          enableVibration: _isSoundOn,
        ),
        iOS: DarwinNotificationDetails(
          sound: _isSoundOn ? 'soft_chime.wav' : null,
          presentSound: _isSoundOn,
        ),
      );

  Future<bool> _requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }

    return false;
  }
}
