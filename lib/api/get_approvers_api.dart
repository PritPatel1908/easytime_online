import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class GetApproversApi {
  static final GetApproversApi _instance = GetApproversApi._internal();
  factory GetApproversApi() => _instance;
  GetApproversApi._internal();

  static Future<String> _getBaseApiUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? baseUrl = prefs.getString('base_api_url');
    return baseUrl ?? 'http://att.easytimeonline.in:121';
  }

  Future<Map<String, dynamic>> fetchApprovers(String empKey) async {
    try {
      final baseUrl = await _getBaseApiUrl();
      String cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }
      final apiUrl = '$cleanUrl/api/get_approvers';

      if (kDebugMode) {
        print('Fetching approvers: $apiUrl with emp_key=$empKey');
      }

      // Try form-encoded POST
      try {
        final resp = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'emp_key': empKey},
        ).timeout(const Duration(seconds: 15));

        if (kDebugMode) {
          print('Form response: ${resp.statusCode} ${resp.body}');
        }

        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          return {'success': true, 'data': data};
        }
      } catch (e) {
        if (kDebugMode) print('Form request error: $e');
      }

      // Try GET with query param as fallback
      try {
        final directUrl = '$apiUrl?emp_key=$empKey';
        final resp = await http.get(Uri.parse(directUrl), headers: {
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 15));
        if (kDebugMode) print('Direct GET: ${resp.statusCode} ${resp.body}');
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          return {'success': true, 'data': data};
        }
      } catch (e) {
        if (kDebugMode) print('Direct GET error: $e');
      }

      // Try JSON POST
      try {
        final resp = await http
            .post(
              Uri.parse(apiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
              },
              body: jsonEncode({'emp_key': empKey}),
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

      return {'success': false, 'message': 'Failed to fetch approvers'};
    } catch (e) {
      if (kDebugMode) print('fetchApprovers error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
