import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Where the user is, for the prayer time calculation.
///
/// Tries the device's own location first, falls back to a coarse lookup over
/// the network, then to whatever was found last time. Prayer times only shift
/// by a minute or two across a city, so a coarse fix is perfectly good — the
/// fallbacks exist so a refused permission never leaves the app with nothing.
class LocationService {
  static const String _latKey = 'location_lat_v1';
  static const String _lonKey = 'location_lon_v1';
  static const String _labelKey = 'location_label_v1';

  /// Used when nothing else is available, so the app always has some answer.
  static const double defaultLatitude = 30.0444;
  static const double defaultLongitude = 31.2357;
  static const String defaultLabel = 'القاهرة (افتراضي)';

  const LocationService();

  /// The stored location, or the default if none was ever resolved.
  Future<ResolvedLocation> current() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latKey);
    final lon = prefs.getDouble(_lonKey);
    if (lat == null || lon == null) {
      return const ResolvedLocation(
        latitude: defaultLatitude,
        longitude: defaultLongitude,
        label: defaultLabel,
        isDefault: true,
      );
    }
    return ResolvedLocation(
      latitude: lat,
      longitude: lon,
      label: prefs.getString(_labelKey) ?? 'موقعك',
    );
  }

  /// Resolves the location afresh and stores it. Returns the stored one
  /// unchanged if every source fails.
  Future<ResolvedLocation> refresh() async {
    final fromDevice = await _fromDevice();
    if (fromDevice != null) {
      await _store(fromDevice);
      return fromDevice;
    }

    final fromNetwork = await _fromNetwork();
    if (fromNetwork != null) {
      await _store(fromNetwork);
      return fromNetwork;
    }

    return current();
  }

  Future<ResolvedLocation?> _fromDevice() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return ResolvedLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        label: 'موقعك الحالي',
      );
    } on Exception {
      return null;
    }
  }

  Future<ResolvedLocation?> _fromNetwork() async {
    try {
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;

      final lat = (body['latitude'] as num?)?.toDouble();
      final lon = (body['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;

      final city = body['city'] as String?;
      return ResolvedLocation(
        latitude: lat,
        longitude: lon,
        label: city == null || city.isEmpty ? 'حسب الإنترنت' : city,
      );
    } on Exception {
      return null;
    }
  }

  Future<void> _store(ResolvedLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, location.latitude);
    await prefs.setDouble(_lonKey, location.longitude);
    await prefs.setString(_labelKey, location.label);
  }
}

class ResolvedLocation {
  const ResolvedLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
    this.isDefault = false,
  });

  final double latitude;
  final double longitude;

  /// Something to show the user, e.g. a city name.
  final String label;

  /// True when this is the built-in fallback rather than a real fix.
  final bool isDefault;
}
