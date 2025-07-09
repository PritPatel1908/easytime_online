import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MonthlyWorkHoursApi {
  // Singleton instance
  static final MonthlyWorkHoursApi _instance = MonthlyWorkHoursApi._internal();
  factory MonthlyWorkHoursApi() => _instance;
  MonthlyWorkHoursApi._internal();

  // Stream controller for work hours updates
  final StreamController<Map<String, dynamic>> _workHoursController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Expose stream for listeners
  Stream<Map<String, dynamic>> get workHoursStream =>
      _workHoursController.stream;

  // Timer for periodic updates
  Timer? _updateTimer;

  // Start periodic updates
  void startPeriodicUpdates(String empKey,
      {Duration interval = const Duration(minutes: 15)}) {
    // Cancel any existing timer
    stopPeriodicUpdates();

    // Fetch immediately
    fetchMonthlyWorkHours(empKey).then((result) {
      _workHoursController.add(result);
    });

    // Set up periodic fetching
    _updateTimer = Timer.periodic(interval, (_) {
      fetchMonthlyWorkHours(empKey).then((result) {
        _workHoursController.add(result);
      });
    });
  }

  // Stop periodic updates
  void stopPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  // Dispose resources
  void dispose() {
    stopPeriodicUpdates();
    _workHoursController.close();
  }

  // Get the stored base API URL
  static Future<String> getBaseApiUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? baseUrl = prefs.getString('base_api_url');
    return baseUrl ?? 'http://att.easytimeonline.in:121';
  }

  // Fetch monthly work hours data
  Future<Map<String, dynamic>> fetchMonthlyWorkHours(String empKey) async {
    try {
      final baseUrl = await getBaseApiUrl();

      // Clean URL by removing trailing slash if present
      String cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      // Create API endpoint URL
      final apiUrl = '$cleanUrl/api/monthly_work_hours';

      print('Fetching work hours from: $apiUrl with emp_key: $empKey');

      // Try form-encoded request first
      try {
        print('Trying form-encoded request with emp_key=$empKey');
        final formResponse = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'emp_key': empKey,
          },
        ).timeout(const Duration(seconds: 15));

        print('Form response status: ${formResponse.statusCode}');
        print('Form response body: ${formResponse.body}');

        if (formResponse.statusCode == 200) {
          try {
            final Map<String, dynamic> data = json.decode(formResponse.body);

            if (data.containsKey('status')) {
              final bool success = data['status'] == true ||
                  data['status'].toString().toLowerCase() == 'true' ||
                  data['status'].toString().toLowerCase() == 'success';

              if (success && data.containsKey('work_hours')) {
                var workHours = data['work_hours'];
                print(
                    'Work hours from form API: $workHours (${workHours.runtimeType})');

                return {
                  'success': true,
                  'work_hours': workHours,
                  'raw_response': data,
                };
              }
            }
          } catch (e) {
            print('Error parsing form response: $e');
          }
        }
      } catch (e) {
        print('Error with form request: $e');
      }

      // Try a different approach - direct URL with emp_key as query parameter
      try {
        final directUrl = '$apiUrl?emp_key=$empKey';
        print('Trying direct URL request: $directUrl');

        final directResponse = await http.get(
          Uri.parse(directUrl),
          headers: {
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

        print('Direct URL response status: ${directResponse.statusCode}');
        print('Direct URL response body: ${directResponse.body}');

        if (directResponse.statusCode == 200) {
          try {
            final Map<String, dynamic> data = json.decode(directResponse.body);

            if (data.containsKey('status')) {
              final bool success = data['status'] == true ||
                  data['status'].toString().toLowerCase() == 'true' ||
                  data['status'].toString().toLowerCase() == 'success';

              if (success && data.containsKey('work_hours')) {
                var workHours = data['work_hours'];
                print('Work hours from direct URL: $workHours');

                return {
                  'success': true,
                  'work_hours': workHours,
                  'raw_response': data,
                };
              }
            }
          } catch (e) {
            print('Error parsing direct URL response: $e');
          }
        }
      } catch (e) {
        print('Error with direct URL request: $e');
      }

      // If previous methods didn't work, try JSON
      try {
        print('Trying JSON request with emp_key=$empKey');
        final jsonResponse = await http
            .post(
              Uri.parse(apiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'emp_key': empKey,
              }),
            )
            .timeout(const Duration(seconds: 15));

        print('JSON response status: ${jsonResponse.statusCode}');
        print('JSON response body: ${jsonResponse.body}');

        if (jsonResponse.statusCode == 200) {
          try {
            final Map<String, dynamic> data = json.decode(jsonResponse.body);

            if (data.containsKey('status')) {
              final bool success = data['status'] == true ||
                  data['status'].toString().toLowerCase() == 'true' ||
                  data['status'].toString().toLowerCase() == 'success';

              if (success && data.containsKey('work_hours')) {
                var workHours = data['work_hours'];
                print(
                    'Work hours from JSON API: $workHours (${workHours.runtimeType})');

                return {
                  'success': true,
                  'work_hours': workHours,
                  'raw_response': data,
                };
              } else {
                print('API response missing work_hours: $data');
                return {
                  'success': false,
                  'message': data['message'] ?? 'No work hours data available',
                  'raw_response': data,
                };
              }
            }
          } catch (e) {
            print('Error parsing JSON response: $e');
          }
        }

        // If we got here, return the JSON response data
        try {
          final Map<String, dynamic> data = json.decode(jsonResponse.body);
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to get work hours',
            'raw_response': data,
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to parse server response',
            'raw_response': jsonResponse.body,
          };
        }
      } catch (e) {
        print('Error with JSON request: $e');
      }

      // If all attempts failed
      return {
        'success': false,
        'message': 'Failed to get work hours after multiple attempts',
      };
    } catch (e) {
      print('Error connecting to server: $e');
      return {
        'success': false,
        'message': 'Error connecting to server: ${e.toString()}',
      };
    }
  }
}
