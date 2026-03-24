import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  // Default Google API key used for reverse-geocoding. Replace with
  // your key. In production, inject this at runtime or via secure storage.
  static const String defaultApiKey = 'AIzaSyDnckhyWWrpb84dt2xvGemPlunwAEcogmA';

  /// Returns a map with keys:
  /// - lat, lng, accuracy, address, distanceKm, isWithinOffice, error
  static Future<Map<String, dynamic>> getLocationDetails({
    String? apiKey,
    double officeLat = 23.0225,
    double officeLng = 72.5714,
    double maxDistanceKm = 0.2,
  }) async {
    final key = apiKey ?? defaultApiKey;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {'error': 'Location permission denied'};
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return {
          'error':
              'Location permission permanently denied. Please enable it in settings.'
        };
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15));

      final lat = pos.latitude;
      final lng = pos.longitude;
      final accuracy = pos.accuracy;

      // Reverse geocode via Google Geocoding API
      String address = '';
      try {
        final url = Uri.parse(
            'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$key');
        final resp = await http.get(url).timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body);
          if (body is Map &&
              body['results'] != null &&
              body['results'].isNotEmpty) {
            address = body['results'][0]['formatted_address'] ?? '';
          }
        }
      } catch (_) {}

      final distanceKm = _haversine(lat, lng, officeLat, officeLng);
      final isWithinOffice = distanceKm <= maxDistanceKm;

      return {
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'address': address,
        'distanceKm': distanceKm,
        'isWithinOffice': isWithinOffice,
        'error': null,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Returns distance in kilometers
  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double deg) => deg * pi / 180.0;
}
