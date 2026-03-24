import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class TodayPunchesApi {
  static final TodayPunchesApi _instance = TodayPunchesApi._internal();
  factory TodayPunchesApi() => _instance;
  TodayPunchesApi._internal();

  final StreamController<Map<String, dynamic>> _punchController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get punchStream => _punchController.stream;

  Timer? _updateTimer;

  void startPeriodicUpdates(String empKey,
      {Duration interval = const Duration(minutes: 5)}) {
    stopPeriodicUpdates();

    // immediate fetch
    fetchTodayPunches(empKey).then((result) {
      _punchController.add(result);
    });

    _updateTimer = Timer.periodic(interval, (_) async {
      final res = await fetchTodayPunches(empKey);
      _punchController.add(res);
    });
  }

  void stopPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  void dispose() {
    stopPeriodicUpdates();
    _punchController.close();
  }

  static Future<String> getBaseApiUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? baseUrl = prefs.getString('base_api_url');

    // Fallback candidate list
    const String localDefault = 'http://192.168.1.52:9095';
    final List<String> candidates = [];

    if (baseUrl != null && baseUrl.trim().isNotEmpty) {
      // Ensure scheme
      if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
        candidates.add('http://$baseUrl');
        candidates.add('https://$baseUrl');
      } else {
        candidates.add(baseUrl);
        // add alternate scheme
        if (baseUrl.startsWith('http://')) {
          candidates.add(baseUrl.replaceFirst('http://', 'https://'));
        } else if (baseUrl.startsWith('https://')) {
          candidates.add(baseUrl.replaceFirst('https://', 'http://'));
        }
      }
    }

    // Add known defaults
    candidates.add(localDefault);

    // Try each candidate and return the first reachable one
    for (var candidate in candidates) {
      try {
        var clean = candidate;
        if (clean.endsWith('/')) clean = clean.substring(0, clean.length - 1);
        final probeUrl = '$clean/';
        if (kDebugMode) print('Probing base API URL: $probeUrl');
        final resp = await http
            .get(Uri.parse(probeUrl))
            .timeout(const Duration(seconds: 3));
        if (kDebugMode) {
          print('Probe status for $candidate: ${resp.statusCode}');
        }
        // Accept any response (200-499) as indication host resolved; prefer 200
        if (resp.statusCode >= 200 && resp.statusCode < 500) {
          // Save working URL (without trailing slash)
          final saveUrl = clean;
          await prefs.setString('base_api_url', saveUrl);
          return saveUrl;
        }
      } catch (e) {
        if (kDebugMode) print('Probe failed for $candidate: $e');
        // continue to next candidate
      }
    }

    // If none reachable, return original or local default
    if (baseUrl != null && baseUrl.trim().isNotEmpty) return baseUrl;
    return localDefault;
  }

  Future<Map<String, dynamic>> fetchTodayPunches(String empKey) async {
    try {
      final baseUrl = await getBaseApiUrl();
      String cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      final apiUrl = '$cleanUrl/api/today_punches';

      if (kDebugMode) {
        print('Fetching today punches from: $apiUrl with emp_key: $empKey');
      }

      // Try form-encoded request first
      try {
        if (kDebugMode) {
          print('Trying form-encoded request with emp_key=$empKey');
        }
        final formResponse = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'emp_key': empKey,
          },
        ).timeout(const Duration(seconds: 15));

        if (kDebugMode) {
          print('Form response status: ${formResponse.statusCode}');
          print('Form response body: ${formResponse.body}');
        }

        if (formResponse.statusCode == 200) {
          try {
            final Map<String, dynamic> data = json.decode(formResponse.body);
            final bool success = data['status'] == true ||
                data['status']?.toString().toLowerCase() == 'true';
            if (success) {
              return {
                'success': true,
                'in_punch': data['in_punch']?.toString() ?? '',
                'out_punch': data['out_punch']?.toString() ?? '',
                'att_date': data['att_date']?.toString() ?? '',
                'raw_response': data,
              };
            }
          } catch (e) {
            if (kDebugMode) print('Error parsing form response: $e');
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error with form request: $e');
      }

      // Try direct GET with emp_key as query parameter
      try {
        final directUrl = '$apiUrl?emp_key=$empKey';
        if (kDebugMode) print('Trying direct URL request: $directUrl');

        final directResponse = await http.get(
          Uri.parse(directUrl),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 15));

        if (kDebugMode) {
          print('Direct response status: ${directResponse.statusCode}');
          print('Direct response body: ${directResponse.body}');
        }

        if (directResponse.statusCode == 200) {
          try {
            final Map<String, dynamic> data = json.decode(directResponse.body);
            final bool success = data['status'] == true ||
                data['status']?.toString().toLowerCase() == 'true';
            if (success) {
              return {
                'success': true,
                'in_punch': data['in_punch']?.toString() ?? '',
                'out_punch': data['out_punch']?.toString() ?? '',
                'att_date': data['att_date']?.toString() ?? '',
                'raw_response': data,
              };
            }
          } catch (e) {
            if (kDebugMode) print('Error parsing direct response: $e');
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error with direct URL request: $e');
      }

      // Try JSON POST
      try {
        if (kDebugMode) print('Trying JSON POST with emp_key=$empKey');
        final jsonResponse = await http
            .post(
              Uri.parse(apiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
              },
              body: jsonEncode({'emp_key': empKey}),
            )
            .timeout(const Duration(seconds: 15));

        if (kDebugMode) {
          print('JSON response status: ${jsonResponse.statusCode}');
          print('JSON response body: ${jsonResponse.body}');
        }

        if (jsonResponse.statusCode == 200) {
          try {
            final Map<String, dynamic> data = json.decode(jsonResponse.body);
            final bool success = data['status'] == true ||
                data['status']?.toString().toLowerCase() == 'true';
            if (success) {
              return {
                'success': true,
                'in_punch': data['in_punch']?.toString() ?? '',
                'out_punch': data['out_punch']?.toString() ?? '',
                'att_date': data['att_date']?.toString() ?? '',
                'raw_response': data,
              };
            }
            return {
              'success': false,
              'message': data['message'] ?? 'No data',
              'raw_response': data
            };
          } catch (e) {
            if (kDebugMode) print('Error parsing JSON response: $e');
            return {
              'success': false,
              'message': 'Parse error',
              'raw_response': jsonResponse.body
            };
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error with JSON request: $e');
      }

      return {
        'success': false,
        'message': 'Failed to fetch today punches after attempts'
      };
    } catch (e) {
      if (kDebugMode) print('Error connecting to server: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Fetch once and print the raw response to debug console.
  Future<void> fetchAndLog(String empKey) async {
    try {
      final res = await fetchTodayPunches(empKey);
      if (kDebugMode) {
        print('=== TODAY_PUNCHES DEBUG START ===');
        print('EMP_KEY: $empKey');
        print('RESULT: $res');
        if (res.containsKey('raw_response')) {
          print('RAW_RESPONSE: ${res['raw_response']}');
        }
        print('=== TODAY_PUNCHES DEBUG END ===');
      }
    } catch (e) {
      if (kDebugMode) print('Error in fetchAndLog: $e');
    }
  }
}
