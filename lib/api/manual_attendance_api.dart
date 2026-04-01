import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ManualAttendanceApi {
  static final ManualAttendanceApi _instance = ManualAttendanceApi._internal();
  factory ManualAttendanceApi() => _instance;
  ManualAttendanceApi._internal();

  static Future<String> getBaseApiUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? baseUrl = prefs.getString('base_api_url');
    return baseUrl ?? 'http://att.easytimeonline.in:121';
  }

  Future<Map<String, dynamic>> fetchByEmpCodes(List<String> empCodes) async {
    try {
      final baseUrl = await getBaseApiUrl();
      var cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/'))
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      final apiUrl =
          '$cleanUrl/api/get_manual_attendance_applications_by_emp_keys';

      final joined = empCodes.join(',');
      final bodyMap = {'emp_key': joined, 'employee_keys': joined};

      // Try form POST
      try {
        final resp = await http
            .post(Uri.parse(apiUrl),
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: bodyMap.map((k, v) => MapEntry(k, v.toString())))
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          return {'success': true, 'data': data};
        }
      } catch (e) {}

      // GET fallback
      try {
        final uri =
            '$apiUrl?emp_key=${Uri.encodeComponent(bodyMap['emp_key']!)}';
        final resp = await http.get(Uri.parse(uri), headers: {
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          return {'success': true, 'data': data};
        }
      } catch (e) {}

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
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          return {'success': true, 'data': data};
        }
      } catch (e) {}

      return {'success': false, 'message': 'Failed to fetch manual attendance'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> submitManualAttendanceApplication(
      Map<String, dynamic> body) async {
    try {
      final baseUrl = await getBaseApiUrl();
      var cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/'))
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      final apiUrl =
          '$cleanUrl/api/validate_and_submit_manual_attendance_application';

      // Try form POST
      try {
        final resp = await http
            .post(Uri.parse(apiUrl),
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: body
                    .map((k, v) => MapEntry(k, v == null ? '' : v.toString())))
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          return {'success': true, 'data': data};
        }
      } catch (e) {}

      // JSON fallback
      try {
        final resp = await http
            .post(Uri.parse(apiUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json'
                },
                body: jsonEncode(body))
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          return {'success': true, 'data': data};
        }
      } catch (e) {}

      return {
        'success': false,
        'message': 'Failed to submit manual attendance'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
