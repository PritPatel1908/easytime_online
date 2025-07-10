import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonthlyWorkHoursDetailApi {
  // API endpoint for monthly work hours details
  static const String endpoint = '/api/show_monthly_work_hours_detail';

  // Static cache to store API response
  static Map<String, dynamic>? _cachedData;
  static String? _cachedEmpKey;
  static DateTime? _lastFetchTime;

  // Check if cache is valid
  static bool isCacheValid(String empKey) {
    if (_cachedData == null || _cachedEmpKey != empKey) {
      return false;
    }

    // Check if cache is less than 30 minutes old
    if (_lastFetchTime != null) {
      final difference = DateTime.now().difference(_lastFetchTime!);
      return difference.inMinutes < 30;
    }

    return false;
  }

  // Get cached data
  static Map<String, dynamic>? getCachedData(String empKey) {
    if (isCacheValid(empKey)) {
      return _cachedData;
    }
    return null;
  }

  // Update cache
  static void updateCache(String empKey, Map<String, dynamic> data) {
    _cachedData = data;
    _cachedEmpKey = empKey;
    _lastFetchTime = DateTime.now();
  }

  // Clear cache
  static void clearCache() {
    _cachedData = null;
    _cachedEmpKey = null;
    _lastFetchTime = null;
  }

  // Get the stored base API URL
  static Future<String> getBaseApiUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? baseUrl = prefs.getString('base_api_url');
    return baseUrl ?? 'http://att.easytimeonline.in:121';
  }

  // Stream controller for work hours data
  final _workHoursDetailController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream getter
  Stream<Map<String, dynamic>> get workHoursDetailStream =>
      _workHoursDetailController.stream;

  // Timer for periodic updates
  Timer? _periodicTimer;

  // Check if response is HTML (error page) instead of JSON
  bool _isHtmlResponse(String body) {
    final trimmedBody = body.trim().toLowerCase();
    return trimmedBody.startsWith('<!doctype html>') ||
        trimmedBody.startsWith('<html') ||
        trimmedBody.contains('</html>');
  }

  // Extract error message from HTML response
  String _extractErrorFromHtml(String htmlBody) {
    if (htmlBody.contains('Database Error')) {
      return 'Database error occurred. Please try again later.';
    } else if (htmlBody.contains('404')) {
      return 'API endpoint not found. Please check server configuration.';
    } else if (htmlBody.contains('500')) {
      return 'Server error occurred. Please try again later.';
    }
    return 'Server returned HTML instead of data. Please contact support.';
  }

  // Fetch monthly work hours detail
  Future<void> fetchMonthlyWorkHoursDetail(String empKey,
      {bool useCache = true}) async {
    // Check for cached data first
    if (useCache && isCacheValid(empKey)) {
      _workHoursDetailController.add(_cachedData!);
      if (kDebugMode) {
        print('Using cached monthly work hours detail data');
      }
    }

    try {
      // Get base URL
      final baseUrl = await getBaseApiUrl();

      // Clean URL by removing trailing slash if present
      String cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      // Create full API URL
      final apiUrl = '$cleanUrl$endpoint';

      if (kDebugMode) {
        print(
            'Fetching monthly work hours detail from: $apiUrl with emp_key: $empKey');
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        body: {'emp_key': empKey},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
              'Connection timed out. Please check your internet connection.');
        },
      );

      if (response.statusCode == 200) {
        final responseBody = response.body;

        // Check if response is HTML instead of JSON
        if (_isHtmlResponse(responseBody)) {
          final errorMessage = _extractErrorFromHtml(responseBody);
          if (kDebugMode) {
            print('Received HTML response instead of JSON: $errorMessage');
          }

          _workHoursDetailController.add({
            'success': false,
            'message': errorMessage,
          });
          return;
        }

        try {
          final data = json.decode(responseBody);
          if (kDebugMode) {
            print('Monthly work hours detail response: $data');
          }

          final resultData = {
            'success': true,
            'daily_data': data['daily_data'],
            'total_work_hours': data['total_work_hours'],
          };

          // Update cache with new data
          updateCache(empKey, resultData);

          _workHoursDetailController.add(resultData);
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing JSON response: $e');
            print('Response body: $responseBody');
          }

          _workHoursDetailController.add({
            'success': false,
            'message':
                'Invalid response format from server. Please try again later.',
          });
        }
      } else {
        if (kDebugMode) {
          print(
              'Failed to load monthly work hours detail. Status code: ${response.statusCode}');
          print('Response body: ${response.body}');
        }

        // Check if error response is HTML
        if (_isHtmlResponse(response.body)) {
          final errorMessage = _extractErrorFromHtml(response.body);
          _workHoursDetailController.add({
            'success': false,
            'message': errorMessage,
          });
        } else {
          _workHoursDetailController.add({
            'success': false,
            'message':
                'Failed to load data. Status code: ${response.statusCode}',
          });
        }
      }
    } on TimeoutException catch (_) {
      if (kDebugMode) {
        print('Connection timed out while fetching monthly work hours detail');
      }
      _workHoursDetailController.add({
        'success': false,
        'message':
            'Connection timed out. Please check your internet connection.',
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching monthly work hours detail: $e');
      }
      _workHoursDetailController.add({
        'success': false,
        'message': 'Error: ${e.toString()}',
      });
    }
  }

  // Start periodic updates
  void startPeriodicUpdates(String empKey,
      {Duration interval = const Duration(minutes: 5)}) {
    // Cancel any existing timer
    stopPeriodicUpdates();

    // Fetch data immediately
    fetchMonthlyWorkHoursDetail(empKey);

    // Set up periodic fetching
    _periodicTimer = Timer.periodic(interval, (_) {
      fetchMonthlyWorkHoursDetail(empKey);
    });
  }

  // Stop periodic updates
  void stopPeriodicUpdates() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  // Dispose resources
  void dispose() {
    stopPeriodicUpdates();
    _workHoursDetailController.close();
  }
}
