import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the notification plugin's platform side.
///
/// Without it the plugin's channel calls never complete under `flutter test`,
/// which hangs any test that builds the app.
class FakeNotificationPlatform {
  final List<MethodCall> calls = <MethodCall>[];
  bool grantPermission = true;

  /// Icons this fake refuses, standing in for a drawable the build dropped.
  Set<String> unresolvableIcons = <String>{};

  /// What the device claims its timezone is called.
  String timeZoneName = 'UTC';

  /// Stands in for how long a real phone takes to hand the OS a schedule.
  Duration scheduleDelay = Duration.zero;

  static const MethodChannel _channel =
      MethodChannel('dexterous.com/flutter/local_notifications');

  /// Firebase is not configured under test. Refusing these keeps startup from
  /// hanging on channels nothing will ever answer, and lets the account
  /// service report itself unavailable, as it would on a build with no
  /// google-services.json. firebase_core talks over Pigeon, so the names are
  /// the generated ones rather than a plain plugin channel.
  static const List<String> _firebaseChannels = <String>[
    'dev.flutter.pigeon.firebase_core_platform_interface'
        '.FirebaseCoreHostApi.initializeCore',
    'dev.flutter.pigeon.firebase_core_platform_interface'
        '.FirebaseCoreHostApi.initializeApp',
    'dev.flutter.pigeon.firebase_core_platform_interface'
        '.FirebaseCoreHostApi.optionsFromResource',
  ];
  // The reminder service also asks these two for the device's timezone and
  // location, and they hang the same way if left unanswered.
  static const MethodChannel _timezoneChannel =
      MethodChannel('flutter_timezone');
  static const MethodChannel _geolocatorChannel =
      MethodChannel('flutter.baseflow.com/geolocator');

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    _installFirebaseRefusal();

    messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
      calls.add(call);
      // Rescheduling clears the old notifications before laying down the new
      // ones, so slowing the clears is enough to stand in for the wait a real
      // phone puts between the tap and the schedule being in place.
      if (scheduleDelay > Duration.zero && call.method == 'cancel') {
        await Future<void>.delayed(scheduleDelay);
      }
      switch (call.method) {
        case 'initialize':
          final icon = call.arguments['defaultIcon'];
          if (icon is String && unresolvableIcons.contains(icon)) {
            throw PlatformException(
              code: 'invalid_icon',
              message: 'The resource \$icon could not be found',
            );
          }
          return true;
        case 'requestNotificationsPermission':
          return grantPermission;
        default:
          return null;
      }
    });

    messenger.setMockMethodCallHandler(
      _timezoneChannel,
      (MethodCall call) async => timeZoneName,
    );
    // Reporting location services as off sends the service down its network
    // and default fallbacks, which need no plugin at all.
    messenger.setMockMethodCallHandler(
      _geolocatorChannel,
      (MethodCall call) async =>
          call.method == 'isLocationServiceEnabled' ? false : null,
    );
  }

  void _installFirebaseRefusal() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in _firebaseChannels) {
      messenger.setMockMessageHandler(name, (ByteData? message) async {
        // An empty reply is read as a channel error, which surfaces in Dart as
        // an exception rather than a wait that never ends.
        return null;
      });
    }
  }

  void remove() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, null);
    messenger.setMockMethodCallHandler(_timezoneChannel, null);
    messenger.setMockMethodCallHandler(_geolocatorChannel, null);
  }

  void reset() => calls.clear();

  MethodCall? callTo(String method) {
    for (final call in calls) {
      if (call.method == method) return call;
    }
    return null;
  }

  bool hasCallTo(String method) => callTo(method) != null;
}
