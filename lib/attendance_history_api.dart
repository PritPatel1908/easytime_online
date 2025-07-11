import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceHistoryApi {
  // Singleton instance
  static final AttendanceHistoryApi _instance =
      AttendanceHistoryApi._internal();
  factory AttendanceHistoryApi() => _instance;
  AttendanceHistoryApi._internal();

  // Stream controller for broadcasting attendance data updates
  final _attendanceDataController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Public stream that UI can listen to
  Stream<Map<String, dynamic>> get attendanceDataStream =>
      _attendanceDataController.stream;

  // Timer for periodic updates
  Timer? _periodicTimer;

  // Cache for attendance data
  Map<String, dynamic> _cachedData = {};
  bool _hasCachedData = false;

  // Get the stored base API URL
  static Future<String> getBaseApiUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? baseUrl = prefs.getString('base_api_url');
    return baseUrl ?? 'http://att.easytimeonline.in:121';
  }

  // Check if cached data exists for given parameters
  bool hasCachedData(String empKey, {String? month, String? year}) {
    final cacheKey = _getCacheKey(empKey, month: month, year: year);
    return _cachedData.containsKey(cacheKey) && _hasCachedData;
  }

  // Get cache key based on parameters
  String _getCacheKey(String empKey, {String? month, String? year}) {
    return '${empKey}_${month ?? ""}_${year ?? ""}';
  }

  // Get cached data if available
  Map<String, dynamic>? getCachedData(String empKey,
      {String? month, String? year}) {
    final cacheKey = _getCacheKey(empKey, month: month, year: year);
    return _cachedData[cacheKey];
  }

  // Method to fetch attendance history data
  Future<void> fetchAttendanceHistory(String empKey,
      {String? month, String? year, bool forceRefresh = false}) async {
    if (kDebugMode) {
      print('--------------------------------------------');
      print('ATTENDANCE HISTORY API CALL STARTED');
      print(
          'Fetching attendance history for empKey: "$empKey", month: $month, year: $year');
    }

    // Validate empKey
    if (empKey.isEmpty) {
      if (kDebugMode) {
        print('Warning: Empty employee key provided to fetchAttendanceHistory');
        _provideMockDataForTesting();
        return;
      } else {
        _attendanceDataController.add({
          'success': false,
          'message': 'Employee key is required',
        });
        return;
      }
    }

    // Check cache first if not forcing refresh
    final cacheKey = _getCacheKey(empKey, month: month, year: year);
    if (!forceRefresh && _cachedData.containsKey(cacheKey) && _hasCachedData) {
      if (kDebugMode) {
        print('Using cached attendance history data');
      }

      // Use cached data
      _attendanceDataController.add(_cachedData[cacheKey]);
      return;
    }

    try {
      // Get base URL
      final baseUrl = await getBaseApiUrl();

      // Clean URL by removing trailing slash if present
      String cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      // Full API endpoint URL
      final apiUrl = '$cleanUrl/api/get_attendance_data';

      // Prepare query parameters
      final Map<String, String> queryParams = {
        'emp_key': empKey,
      };

      // Add month and year if provided
      if (month != null && month.isNotEmpty) {
        queryParams['month'] = month;
      }

      if (year != null && year.isNotEmpty) {
        queryParams['year'] = year;
      }

      // Log the request details
      if (kDebugMode) {
        print('Fetching attendance data from: $apiUrl');
        print('Request parameters: $queryParams');
      }

      // Make GET request with URL parameters
      final uri = Uri.parse(apiUrl).replace(queryParameters: queryParams);
      if (kDebugMode) {
        print('Making GET request to: $uri');
      }

      var response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      // If GET fails, try POST with JSON
      if (response.statusCode >= 400) {
        if (kDebugMode) {
          print(
              'GET request failed with status ${response.statusCode}, trying POST with JSON');
        }

        response = await http
            .post(
              Uri.parse(apiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: json.encode(queryParams),
            )
            .timeout(const Duration(seconds: 15));
      }

      // If JSON POST fails, try form-encoded POST
      if (response.statusCode >= 400) {
        if (kDebugMode) {
          print(
              'JSON POST failed with status ${response.statusCode}, trying form-encoded');
        }

        response = await http
            .post(
              Uri.parse(apiUrl),
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Accept': 'application/json',
              },
              body: queryParams,
            )
            .timeout(const Duration(seconds: 15));
      }

      if (kDebugMode) {
        print('API response status code: ${response.statusCode}');
        print('API response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseBody = response.body;

        try {
          final data = json.decode(responseBody);

          if (kDebugMode) {
            print('Parsed JSON data: $data');
          }

          if (data['status'] == true && data.containsKey('attendance_data')) {
            // Successfully fetched data
            if (kDebugMode) {
              print(
                  'Successfully fetched attendance data: ${data['attendance_data']}');
            }

            final resultData = {
              'success': true,
              'attendance_data': data['attendance_data'],
              'raw_response': data,
            };

            // Cache the data
            _cachedData[cacheKey] = resultData;
            _hasCachedData = true;

            // Send data to stream
            _attendanceDataController.add(resultData);
          } else {
            // API returned an error
            if (kDebugMode) {
              print(
                  'API returned error: ${data['message'] ?? 'Unknown error'}');
            }

            final resultData = {
              'success': false,
              'message': data['message'] ?? 'Failed to load attendance data',
              'raw_response': data,
            };

            // Send error to stream
            _attendanceDataController.add(resultData);
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing JSON response: $e');
            print('Response body: $responseBody');
          }

          _attendanceDataController.add({
            'success': false,
            'message':
                'Invalid response format from server. Please try again later.',
          });
        }
      } else {
        if (kDebugMode) {
          print(
              'Failed to load attendance data. Status code: ${response.statusCode}');
          print('Response body: ${response.body}');

          // For development only: Return mock data if the API fails
          _provideMockDataForTesting();
          return;
        }

        // HTTP error (only in production)
        _attendanceDataController.add({
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        });
      }

      if (kDebugMode) {
        print('ATTENDANCE HISTORY API CALL COMPLETED');
        print('--------------------------------------------');
      }
    } catch (e) {
      // Network or other error
      if (kDebugMode) {
        print('Error connecting to server for attendance history: $e');
        _provideMockDataForTesting();
      } else {
        _attendanceDataController.add({
          'success': false,
          'message': 'Network error: Unable to connect to server',
        });
      }
    }
  }

  // Method to start periodic updates
  void startPeriodicUpdates(String empKey,
      {String? month,
      String? year,
      Duration interval = const Duration(minutes: 15)}) {
    // Cancel any existing timer
    _periodicTimer?.cancel();

    // Make an immediate call
    fetchAttendanceHistory(empKey, month: month, year: year);

    // Set up periodic updates
    _periodicTimer = Timer.periodic(interval, (_) {
      fetchAttendanceHistory(empKey, month: month, year: year);
    });

    if (kDebugMode) {
      print(
          'Started periodic updates for attendance history with interval: $interval');
    }
  }

  // Method to stop periodic updates
  void stopPeriodicUpdates() {
    _periodicTimer?.cancel();
    _periodicTimer = null;

    if (kDebugMode) {
      print('Stopped periodic updates for attendance history');
    }
  }

  // Method to clear cache
  void clearCache() {
    _cachedData.clear();
    _hasCachedData = false;
    if (kDebugMode) {
      print('Attendance history cache cleared');
    }
  }

  // Method to provide mock data for testing
  void _provideMockDataForTesting() {
    if (!kDebugMode) return;

    if (kDebugMode) {
      print('Providing mock attendance data for testing');
    }

    // Get current month and year
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    // Create mock attendance data for the current month
    final mockData = {
      'attendance_data': {
        'month': currentMonth.toString().padLeft(2, '0'),
        'year': currentYear.toString(),
        'days': List.generate(30, (index) {
          final day = index + 1;
          final status = _getRandomStatus();
          return {
            'date':
                '$currentYear-${currentMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
            'day': day.toString(),
            'status': status,
            'status_name': _getStatusName(status),
            'check_in': status == 'PP' ? '09:00' : null,
            'check_out': status == 'PP' ? '18:00' : null,
            'work_hours': status == 'PP' ? '09:00' : '00:00',
          };
        }),
      }
    };

    _attendanceDataController.add({
      'success': true,
      'attendance_data': mockData['attendance_data'],
      'raw_response': mockData,
    });
  }

  // Helper method to get random status for mock data
  String _getRandomStatus() {
    final statuses = ['PP', 'AA', 'WO', 'HO', 'LE'];
    return statuses[DateTime.now().millisecond % statuses.length];
  }

  // Helper method to get status name
  String _getStatusName(String code) {
    switch (code) {
      case 'PP':
        return 'Present';
      case 'AA':
        return 'Absent';
      case 'WO':
        return 'Week Off';
      case 'HO':
        return 'Holiday';
      case 'LE':
        return 'Leave';
      default:
        return code;
    }
  }

  // Clean up resources
  void dispose() {
    stopPeriodicUpdates();
    _attendanceDataController.close();
  }
}
