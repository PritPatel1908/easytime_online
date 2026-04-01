import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StatusPieChartApi {
  static final StatusPieChartApi _instance = StatusPieChartApi._internal();
  factory StatusPieChartApi() => _instance;
  StatusPieChartApi._internal();

  StreamController<Map<String, dynamic>>? _statusDataController;

  void _ensureController() {
    if (_statusDataController == null || _statusDataController!.isClosed) {
      _statusDataController =
          StreamController<Map<String, dynamic>>.broadcast();
    }
  }

  Stream<Map<String, dynamic>> get statusDataStream {
    _ensureController();
    return _statusDataController!.stream;
  }

  void _safeAdd(Map<String, dynamic> event) {
    try {
      _ensureController();
      if (!_statusDataController!.isClosed) {
        _statusDataController!.add(event);
      }
    } catch (_) {
      // swallow add errors in production
    }
  }

  Timer? _periodicTimer;

  static Future<String> getBaseApiUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? baseUrl = prefs.getString('base_api_url');
    return baseUrl ?? 'http://192.168.1.52:9095';
  }

  Future<void> fetchStatusPieChart(String? empKey) async {
    if (empKey == null || empKey.isEmpty) {
      _safeAdd({
        'success': false,
        'message': 'Employee key is required',
      });
      return;
    }

    String cleanEmpKey = empKey.trim();
    if (cleanEmpKey.isEmpty) {
      _safeAdd({
        'success': false,
        'message': 'Employee key is empty',
      });
      return;
    }

    try {
      final baseUrl = await getBaseApiUrl();

      String cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      final apiUrl = '$cleanUrl/api/get_status_pie_chart';
      final directUrl = '$apiUrl?emp_key=$cleanEmpKey';

      var response = await http.get(
        Uri.parse(directUrl),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode >= 400) {
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

      if (response.statusCode >= 400) {
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

      if (response.statusCode == 200) {
        final responseBody = response.body;
        try {
          final data = json.decode(responseBody);

          if (data['status'] == true && data.containsKey('status_data')) {
            _safeAdd({
              'success': true,
              'status_data': data['status_data'],
              'raw_response': data,
            });
          } else {
            _safeAdd({
              'success': false,
              'message': data['message'] ?? 'Failed to load status data',
              'raw_response': data,
            });
          }
        } catch (e) {
          _safeAdd({
            'success': false,
            'message':
                'Invalid response format from server. Please try again later.',
          });
        }
      } else {
        _safeAdd({
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        });
      }
    } catch (e) {
      _safeAdd({
        'success': false,
        'message': 'Error connecting to server: ${e.toString()}',
      });
    }
  }

  Future<void> callApiDirectly(String empKey, String baseUrl) async {
    try {
      String cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      final directUrl = '$cleanUrl/api/get_status_pie_chart?emp_key=$empKey';

      final response = await http.get(
        Uri.parse(directUrl),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['status'] == true && data.containsKey('status_data')) {
            _safeAdd({
              'success': true,
              'status_data': data['status_data'],
              'raw_response': data,
            });
          } else {
            _safeAdd({
              'success': false,
              'message': data['message'] ?? 'Failed to load status data',
              'raw_response': data,
            });
          }
        } catch (e) {
          // parsing error, ignore here
        }
      }
    } catch (e) {
      // network error, ignore here
    }
  }

  void startPeriodicUpdates(String? empKey,
      {Duration interval = const Duration(minutes: 15)}) {
    String? cleanEmpKey = empKey?.trim();

    if (cleanEmpKey == null || cleanEmpKey.isEmpty) {
      _safeAdd({
        'success': false,
        'message': 'Employee key is required',
      });
      return;
    }

    stopPeriodicUpdates();

    fetchStatusPieChart(cleanEmpKey);

    _periodicTimer = Timer.periodic(interval, (_) {
      fetchStatusPieChart(cleanEmpKey);
    });
  }

  void stopPeriodicUpdates() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  void dispose() {
    stopPeriodicUpdates();
    // Intentionally do not close the controller here to allow reuse
  }
}
