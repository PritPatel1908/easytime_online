import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManualPunchApi {
  static final ManualPunchApi _instance = ManualPunchApi._internal();
  factory ManualPunchApi() => _instance;
  ManualPunchApi._internal();

  static Future<String> _getBaseApiUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? baseUrl = prefs.getString('base_api_url');
    return baseUrl ?? 'http://att.easytimeonline.in:121';
  }

  Future<Map<String, dynamic>> fetchByEmpCodes(List<String> empCodes) async {
    try {
      final baseUrl = await _getBaseApiUrl();
      var cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/'))
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      final apiUrl = '$cleanUrl/api/get_manual_punch_applications_by_emp_keys';

      if (kDebugMode)
        print(
            'Fetching manual punches for emp_codes=${empCodes.join(',')} (sending as emp_key)');

      final joined = empCodes.join(',');
      // API expects `emp_key` parameter (other APIs use this name).
      // Include `emp_code` as well for compatibility.
      final bodyMap = {'emp_key': joined, 'emp_code': joined};

      // Try form POST
      try {
        final resp = await http
            .post(
              Uri.parse(apiUrl),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: bodyMap.map((k, v) => MapEntry(k, v.toString())),
            )
            .timeout(const Duration(seconds: 15));
        if (kDebugMode) print('Form response: ${resp.statusCode} ${resp.body}');
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          return {'success': true, 'data': data};
        }
      } catch (e) {
        if (kDebugMode) print('Form POST error: $e');
      }

      // GET fallback
      try {
        final uri =
            '$apiUrl?emp_key=${Uri.encodeComponent(bodyMap['emp_key']!)}';
        final resp = await http.get(Uri.parse(uri), headers: {
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 15));
        if (kDebugMode) print('GET response: ${resp.statusCode} ${resp.body}');
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          return {'success': true, 'data': data};
        }
      } catch (e) {
        if (kDebugMode) print('GET error: $e');
      }

      // JSON POST
      try {
        final resp = await http
            .post(
              Uri.parse(apiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
              },
              body: jsonEncode(bodyMap),
            )
            .timeout(const Duration(seconds: 15));
        if (kDebugMode) print('JSON POST: ${resp.statusCode} ${resp.body}');
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          return {'success': true, 'data': data};
        }
      } catch (e) {
        if (kDebugMode) print('JSON POST error: $e');
      }

      return {'success': false, 'message': 'Failed to fetch manual punches'};
    } catch (e) {
      if (kDebugMode) print('fetchByEmpCodes error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> submitManualPunchApplication(
      Map<String, dynamic> body) async {
    try {
      final baseUrl = await _getBaseApiUrl();
      var cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/'))
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      final apiUrl =
          '$cleanUrl/api/validate_and_submit_manual_punch_application';

      if (kDebugMode) print('Submitting manual punch: $body');

      // Try form POST first
      try {
        final resp = await http
            .post(
              Uri.parse(apiUrl),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: body
                  .map((k, v) => MapEntry(k, v == null ? '' : v.toString())),
            )
            .timeout(const Duration(seconds: 15));
        if (kDebugMode) print('Form POST: ${resp.statusCode} ${resp.body}');
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          return {'success': true, 'data': data};
        }
      } catch (e) {
        if (kDebugMode) print('Form POST error: $e');
      }

      // JSON POST fallback
      try {
        final resp = await http
            .post(
              Uri.parse(apiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 15));
        if (kDebugMode) print('JSON POST: ${resp.statusCode} ${resp.body}');
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          return {'success': true, 'data': data};
        }
      } catch (e) {
        if (kDebugMode) print('JSON POST error: $e');
      }

      return {'success': false, 'message': 'Failed to submit manual punch'};
    } catch (e) {
      if (kDebugMode) print('submitManualPunchApplication error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
