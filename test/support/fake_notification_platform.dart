import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the notification plugin's platform side.
///
/// Without it the plugin's channel calls never complete under `flutter test`,
/// which hangs any test that builds the app.
class FakeNotificationPlatform {
  final List<MethodCall> calls = <MethodCall>[];
  bool grantPermission = true;

  static const MethodChannel _channel =
      MethodChannel('dexterous.com/flutter/local_notifications');
  // The reminder service also asks these two for the device's timezone and
  // location, and they hang the same way if left unanswered.
  static const MethodChannel _timezoneChannel =
      MethodChannel('flutter_timezone');
  static const MethodChannel _geolocatorChannel =
      MethodChannel('flutter.baseflow.com/geolocator');

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'requestNotificationsPermission':
          return grantPermission;
        default:
          return null;
      }
    });

    messenger.setMockMethodCallHandler(
      _timezoneChannel,
      (MethodCall call) async => 'UTC',
    );
    // Reporting location services as off sends the service down its network
    // and default fallbacks, which need no plugin at all.
    messenger.setMockMethodCallHandler(
      _geolocatorChannel,
      (MethodCall call) async =>
          call.method == 'isLocationServiceEnabled' ? false : null,
    );
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
