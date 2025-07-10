import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatusPieChartApi {
  // Singleton instance for consistency with other API classes
  static final StatusPieChartApi _instance = StatusPieChartApi._internal();
  factory StatusPieChartApi() => _instance;
  StatusPieChartApi._internal();

  // Stream controller for broadcasting status data updates
  final _statusDataController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Public stream that UI can listen to
  Stream<Map<String, dynamic>> get statusDataStream =>
      _statusDataController.stream;

  // Timer for periodic updates
  Timer? _periodicTimer;

  // Get the stored base API URL
  static Future<String> getBaseApiUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? baseUrl = prefs.getString('base_api_url');
    return baseUrl ?? 'http://att.easytimeonline.in:121';
  }

  // Method to fetch status pie chart data
  Future<void> fetchStatusPieChart(String? empKey) async {
    // Validate empKey with more detailed debugging
    if (kDebugMode) {
      print('--------------------------------------------');
      print('STATUS PIE CHART API CALL STARTED');
      print(
          'Status pie chart fetchStatusPieChart called with empKey: "$empKey"');
      if (empKey != null) {
        print('empKey type: ${empKey.runtimeType}, length: ${empKey.length}');
        if (empKey.isEmpty) {
          print('WARNING: empKey is empty string');
        } else if (empKey.trim().isEmpty) {
          print('WARNING: empKey contains only whitespace');
        }
      } else {
        print('WARNING: empKey is null');
      }
    }

    // Validate empKey
    if (empKey == null || empKey.isEmpty) {
      if (kDebugMode) {
        print('Warning: Empty employee key provided to fetchStatusPieChart');
        print('Debug info - empKey value: "$empKey"');

        // In debug mode, provide mock data instead of failing
        _provideMockDataForTesting();
        return;
      } else {
        _statusDataController.add({
          'success': false,
          'message': 'Employee key is required',
        });
        return;
      }
    }

    // Make sure to trim the empKey to remove any whitespace
    String cleanEmpKey = empKey.trim();

    // Re-validate after trimming
    if (cleanEmpKey.isEmpty) {
      if (kDebugMode) {
        print('Warning: Employee key is just whitespace');
        _provideMockDataForTesting();
        return;
      } else {
        _statusDataController.add({
          'success': false,
          'message': 'Employee key is empty',
        });
        return;
      }
    }

    // Log successful empKey
    if (kDebugMode) {
      print('Status pie chart using clean empKey: "$cleanEmpKey"');
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
      final apiUrl = '$cleanUrl/api/get_status_pie_chart';

      // Log the request details
      if (kDebugMode) {
        print('Fetching status pie chart data from: $apiUrl');
        print('Request payload: ${json.encode({'emp_key': cleanEmpKey})}');
      }

      // SIMPLIFIED API CALL APPROACH - Try direct GET with URL params first
      // This is often the most reliable and simplest approach
      final directUrl = '$apiUrl?emp_key=$cleanEmpKey';
      if (kDebugMode) {
        print('Making GET request to: $directUrl');
      }

      var response = await http.get(
        Uri.parse(directUrl),
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
              body: json.encode({'emp_key': cleanEmpKey}),
            )
            .timeout(const Duration(seconds: 15));
      }

      // If JSON POST fails, try form-encoded POST
      if (response.statusCode >= 400) {
        if (kDebugMode) {
          print(
              'JSON POST failed with status ${response.statusCode}, trying form-encoded');
        }

        response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
          },
          body: {
            'emp_key': cleanEmpKey,
          },
        ).timeout(const Duration(seconds: 15));
      }

      if (kDebugMode) {
        print('API response status code: ${response.statusCode}');
        print('API response headers: ${response.headers}');
        print('API response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseBody = response.body;

        try {
          final data = json.decode(responseBody);

          if (kDebugMode) {
            print('Parsed JSON data: $data');
          }

          if (data['status'] == true && data.containsKey('status_data')) {
            // Successfully fetched data
            if (kDebugMode) {
              print('Successfully fetched status data: ${data['status_data']}');
            }

            _statusDataController.add({
              'success': true,
              'status_data': data['status_data'],
              'raw_response': data,
            });
          } else {
            // API returned an error
            if (kDebugMode) {
              print(
                  'API returned error: ${data['message'] ?? 'Unknown error'}');
            }

            _statusDataController.add({
              'success': false,
              'message': data['message'] ?? 'Failed to load status data',
              'raw_response': data,
            });
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing JSON response: $e');
            print('Response body: $responseBody');
          }

          _statusDataController.add({
            'success': false,
            'message':
                'Invalid response format from server. Please try again later.',
          });
        }
      } else {
        if (kDebugMode) {
          print(
              'Failed to load status data. Status code: ${response.statusCode}');
          print('Response body: ${response.body}');

          // For development only: Return mock data if the API fails
          print('Returning mock data for testing');
          _statusDataController.add({
            'success': true,
            'status_data': {
              'PP': 6,
              'WO': 1,
              'AA': 3,
            },
          });
          return;
        }

        // HTTP error (only in production)
        _statusDataController.add({
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        });
      }

      if (kDebugMode) {
        print('STATUS PIE CHART API CALL COMPLETED');
        print('--------------------------------------------');
      }
    } catch (e) {
      // Network or other error
      if (kDebugMode) {
        print('Error connecting to server for status pie chart: $e');

        // For development only: Return mock data if there's a network error
        print('Returning mock data due to network error');
        _statusDataController.add({
          'success': true,
          'status_data': {
            'PP': 6,
            'WO': 1,
            'AA': 3,
          },
        });
        print('STATUS PIE CHART API CALL FAILED WITH ERROR');
        print('--------------------------------------------');
        return;
      }

      // Only in production
      _statusDataController.add({
        'success': false,
        'message': 'Error connecting to server: ${e.toString()}',
      });
    }
  }

  // Method to directly call the API with a specific URL (for testing)
  Future<void> callApiDirectly(String empKey, String baseUrl) async {
    if (kDebugMode) {
      print('====== DIRECT API CALL ======');
      print('Directly calling status pie chart API');
      print('Base URL: $baseUrl');
      print('Emp Key: $empKey');
    }

    try {
      // Clean URL by removing trailing slash if present
      String cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      // Direct GET URL
      final directUrl = '$cleanUrl/api/get_status_pie_chart?emp_key=$empKey';

      if (kDebugMode) {
        print('Making direct GET request to: $directUrl');
      }

      final response = await http.get(
        Uri.parse(directUrl),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('Direct API response status code: ${response.statusCode}');
        print('Direct API response headers: ${response.headers}');
        print('Direct API response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (kDebugMode) {
            print('Successfully parsed direct API response: $data');
          }

          if (data['status'] == true && data.containsKey('status_data')) {
            if (kDebugMode) {
              print('Status data found: ${data['status_data']}');
            }

            // Send to stream
            _statusDataController.add({
              'success': true,
              'status_data': data['status_data'],
              'raw_response': data,
            });
          } else {
            if (kDebugMode) {
              print('API returned error or no status_data: $data');
            }

            _statusDataController.add({
              'success': false,
              'message': data['message'] ?? 'Failed to load status data',
              'raw_response': data,
            });
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing direct API response: $e');
          }
        }
      } else {
        if (kDebugMode) {
          print(
              'Direct API call failed with status code: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error making direct API call: $e');
      }
    } finally {
      if (kDebugMode) {
        print('====== DIRECT API CALL COMPLETED ======');
      }
    }
  }

  // Start periodic updates
  void startPeriodicUpdates(String? empKey,
      {Duration interval = const Duration(minutes: 15)}) {
    // Log the incoming value
    if (kDebugMode) {
      print(
          'StatusPieChartApi.startPeriodicUpdates called with empKey: "$empKey"');
    }

    // Ensure the empKey is properly trimmed to avoid whitespace issues
    String? cleanEmpKey = empKey?.trim();

    // Validate empKey and use fallback if needed
    if (cleanEmpKey == null || cleanEmpKey.isEmpty) {
      if (kDebugMode) {
        print('Warning: Empty employee key provided to status pie chart API');
        print('Current emp_key value: "$empKey"');

        // Use a fallback key for development/testing only
        cleanEmpKey = "1234"; // Default test emp_key
        print('Using fallback emp_key for testing: "$cleanEmpKey"');

        // In debug mode, also provide mock data for testing
        _provideMockDataForTesting();
      } else {
        // In production, send error through the stream
        _statusDataController.add({
          'success': false,
          'message': 'Employee key is required',
        });
        return;
      }
    }

    // Cancel any existing timer
    stopPeriodicUpdates();

    // Fetch immediately once with debugging
    if (kDebugMode) {
      print(
          'Making immediate call to fetchStatusPieChart with emp_key: "$cleanEmpKey"');
    }
    fetchStatusPieChart(cleanEmpKey);

    // Set up periodic fetching
    _periodicTimer = Timer.periodic(interval, (_) {
      if (kDebugMode) {
        print('Periodic timer triggered: fetching status pie chart data');
      }
      fetchStatusPieChart(cleanEmpKey);
    });

    if (kDebugMode) {
      print(
          'Periodic updates started with interval: ${interval.inMinutes} minutes');
    }
  }

  // Stop periodic updates
  void stopPeriodicUpdates() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  // Dispose method to clean up resources
  void dispose() {
    stopPeriodicUpdates();
    _statusDataController.close();
  }

  // Provide mock data for testing in debug mode
  void _provideMockDataForTesting() {
    if (kDebugMode) {
      print('Providing mock status pie chart data for testing');

      // Create mock status data
      final mockStatusData = {
        'PP': 12, // Present
        'WO': 4, // Work Off
        'AA': 2, // Absent
      };

      // Send mock data through the stream
      _statusDataController.add({
        'success': true,
        'message': 'Mock data loaded successfully',
        'status_data': mockStatusData,
      });

      print('Mock status data sent: $mockStatusData');
    }
  }
}
