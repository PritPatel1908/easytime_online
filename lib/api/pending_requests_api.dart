import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class PendingRequestsApi {
  static final PendingRequestsApi _instance = PendingRequestsApi._internal();
  factory PendingRequestsApi() => _instance;
  PendingRequestsApi._internal();

  static Future<String> _getBaseApiUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? baseUrl = prefs.getString('base_api_url');
    return baseUrl ?? 'http://att.easytimeonline.in:121';
  }

  Future<Map<String, dynamic>> fetchPendingRequests(
      {required String empKey, String entityName = ''}) async {
    try {
      final baseUrl = await _getBaseApiUrl();
      var cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }
      final apiUrl = '$cleanUrl/api/pending_requests';

      if (kDebugMode) {
        print(
            'Fetching pending requests: emp_key=$empKey entity_name=$entityName');
      }

      final bodyMap = {'emp_key': empKey, 'entity_name': entityName};

      // Try form POST
      try {
        final resp = await http
            .post(Uri.parse(apiUrl),
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: bodyMap.map((k, v) => MapEntry(k, v.toString())))
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
            '$apiUrl?emp_key=${Uri.encodeComponent(bodyMap['emp_key']!)}&entity_name=${Uri.encodeComponent(bodyMap['entity_name']!)}';
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
            .post(Uri.parse(apiUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json'
                },
                body: jsonEncode(bodyMap))
            .timeout(const Duration(seconds: 15));
        if (kDebugMode) print('JSON POST: ${resp.statusCode} ${resp.body}');
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          return {'success': true, 'data': data};
        }
      } catch (e) {
        if (kDebugMode) print('JSON POST error: $e');
      }

      return {'success': false, 'message': 'Failed to fetch pending requests'};
    } catch (e) {
      if (kDebugMode) print('fetchPendingRequests error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
