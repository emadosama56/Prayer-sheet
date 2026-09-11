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

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
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
  }

  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
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
