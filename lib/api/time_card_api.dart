import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TimeCardApi {
  // Singleton instance
  static final TimeCardApi _instance = TimeCardApi._internal();
  factory TimeCardApi() => _instance;
  TimeCardApi._internal();

  // Stream controller for broadcasting time card data updates
  final _timeCardDataController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Public stream that UI can listen to
  Stream<Map<String, dynamic>> get timeCardDataStream =>
      _timeCardDataController.stream;

  // Timer for periodic updates
  Timer? _periodicTimer;

  // Cache for time card data
  final Map<String, dynamic> _cachedData = {};
  bool _hasCachedData = false;

  // Get the stored base API URL
  static Future<String> getBaseApiUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? baseUrl = prefs.getString('base_api_url');
    return baseUrl ?? 'http://192.168.1.52:9095';
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

  // Method to fetch time card data
  Future<void> fetchTimeCardData(String empKey,
      {String? month, String? year, bool forceRefresh = false}) async {
    // Validate empKey
    if (empKey.isEmpty) {
      _timeCardDataController.add({
        'success': false,
        'message': 'Employee key is required',
      });
      return;
    }

    // Check cache first if not forcing refresh
    final cacheKey = _getCacheKey(empKey, month: month, year: year);
    if (!forceRefresh && _cachedData.containsKey(cacheKey) && _hasCachedData) {
      // Use cached data
      _timeCardDataController.add(_cachedData[cacheKey]);
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

      // Make GET request with URL parameters
      final uri = Uri.parse(apiUrl).replace(queryParameters: queryParams);

      var response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      // If GET fails, try POST with JSON
      if (response.statusCode >= 400) {
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

      if (response.statusCode == 200) {
        final responseBody = response.body;

        try {
          final data = json.decode(responseBody);

          if (data['status'] == true && data.containsKey('attendance_data')) {
            final resultData = {
              'success': true,
              'attendance_data': data['attendance_data'],
              'raw_response': data,
            };

            // Cache the data
            _cachedData[cacheKey] = resultData;
            _hasCachedData = true;

            // Send data to stream
            _timeCardDataController.add(resultData);
          } else {
            final resultData = {
              'success': false,
              'message': data['message'] ?? 'Failed to load time card data',
              'raw_response': data,
            };

            // Send error to stream
            _timeCardDataController.add(resultData);
          }
        } catch (e) {
          _timeCardDataController.add({
            'success': false,
            'message':
                'Invalid response format from server. Please try again later.',
          });
        }
      } else {
        // HTTP error
        _timeCardDataController.add({
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        });
      }
    } catch (e) {
      // Network or other error
      _timeCardDataController.add({
        'success': false,
        'message': 'Network error: Unable to connect to server',
      });
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
    fetchTimeCardData(empKey, month: month, year: year);

    // Set up periodic updates
    _periodicTimer = Timer.periodic(interval, (_) {
      fetchTimeCardData(empKey, month: month, year: year);
    });
  }

  // Method to stop periodic updates
  void stopPeriodicUpdates() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  // Method to clear cache
  void clearCache() {
    _cachedData.clear();
    _hasCachedData = false;
  }

  // Clean up resources
  void dispose() {
    stopPeriodicUpdates();
    _timeCardDataController.close();
  }
}
