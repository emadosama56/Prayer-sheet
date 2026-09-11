import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Schedules the recurring "did you log your prayer?" reminder.
///
/// The reminder repeats every [reminderInterval] using an inexact alarm, which
/// still fires in doze mode but needs no exact-alarm permission — a nudge does
/// not need to land on the second, and asking for that permission would be a
/// worse trade.
class ReminderService extends ChangeNotifier {
  ReminderService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const Duration reminderInterval = Duration(hours: 2);

  static const String reminderTitle = 'سجلت صلاتك؟ ممكن متنساش 🙏 ؟';
  static const String reminderBody = 'متخسرش عدد الايام و خليك مكمل 👏';

  static const int _notificationId = 1001;
  static const String _prefsKey = 'reminders_enabled_v1';
  static const String _soundPrefsKey = 'reminders_sound_v1';

  /// An Android channel's sound is fixed once the channel exists, so silencing
  /// the reminder means moving it to a second, soundless channel rather than
  /// editing the first.
  static const String _channelId = 'prayer_reminders_v1';
  static const String _silentChannelId = 'prayer_reminders_silent_v1';

  final FlutterLocalNotificationsPlugin _plugin;

  bool _isEnabled = false;
  bool _isSoundOn = true;
  bool _isSupported = false;

  bool get isEnabled => _isEnabled;

  /// Whether the reminder plays the app's chime or arrives silently.
  bool get isSoundOn => _isSoundOn;

  /// False on platforms with no local notification support (web, tests).
  bool get isSupported => _isSupported;

  static NotificationDetails _detailsWithSound(bool withSound) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          withSound ? _channelId : _silentChannelId,
          withSound ? 'تذكير الصلاة' : 'تذكير الصلاة (صامت)',
          channelDescription: 'تذكير بتسجيل الصلاة',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          // The app's own soft chime instead of the system notification tone.
          sound: withSound
              ? const RawResourceAndroidNotificationSound('soft_chime')
              : null,
          playSound: withSound,
          enableVibration: withSound,
        ),
        iOS: DarwinNotificationDetails(
          sound: withSound ? 'soft_chime.wav' : null,
          presentSound: withSound,
        ),
      );

  /// Loads the plugin and restores whether reminders were on.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_prefsKey) ?? false;
    _isSoundOn = prefs.getBool(_soundPrefsKey) ?? true;

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

    // A reinstall or an OS-level clear can drop the schedule while the stored
    // flag still says "on", so re-arm it on every start.
    if (_isSupported && _isEnabled) {
      await _schedule();
    }
    notifyListeners();
  }

  /// Turns reminders on (asking for permission first) or off.
  ///
  /// Returns whether reminders are on afterwards — false if the user denied
  /// the notification permission.
  Future<bool> setEnabled(bool enabled) async {
    if (!_isSupported) return false;

    if (enabled) {
      if (!await _requestPermission()) {
        _isEnabled = false;
        notifyListeners();
        return false;
      }
      await _schedule();
    } else {
      await _plugin.cancel(_notificationId);
    }

    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
    notifyListeners();
    return enabled;
  }

  /// Switches the reminder between the chime and arriving silently.
  Future<void> setSoundOn(bool withSound) async {
    if (_isSoundOn == withSound) return;
    _isSoundOn = withSound;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundPrefsKey, withSound);

    // The sound lives on the channel, so an armed reminder has to be re-armed
    // to move to the other one.
    if (_isSupported && _isEnabled) {
      await _schedule();
    }
    notifyListeners();
  }

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

  Future<void> _schedule() async {
    await _plugin.periodicallyShowWithDuration(
      _notificationId,
      reminderTitle,
      reminderBody,
      reminderInterval,
      _detailsWithSound(_isSoundOn),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
