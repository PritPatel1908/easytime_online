import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LeaveTransactionsApi {
  static final LeaveTransactionsApi _instance =
      LeaveTransactionsApi._internal();
  factory LeaveTransactionsApi() => _instance;
  LeaveTransactionsApi._internal();

  static Future<String> _getBaseApiUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? baseUrl = prefs.getString('base_api_url');
    return baseUrl ?? 'http://att.easytimeonline.in:121';
  }

  Future<Map<String, dynamic>> fetchLeaveTransactions(
      {required String empKey,
      required dynamic financialYearKey,
      required dynamic leaveTypeKey}) async {
    try {
      final baseUrl = await _getBaseApiUrl();
      var cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }
      final apiUrl = '$cleanUrl/api/leave_transactions';

      // Production: no debug-only behavior

      final bodyMap = {
        'emp_key': empKey,
        'financial_year_key': financialYearKey,
        'leave_type_key': leaveTypeKey,
      };

      // Try form-encoded POST
      try {
        final resp = await http
            .post(
              Uri.parse(apiUrl),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: bodyMap.map((k, v) => MapEntry(k, v.toString())),
            )
            .timeout(const Duration(seconds: 15));

        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          return {'success': true, 'data': data};
        }
      } catch (e) {}

      // Fallback GET
      try {
        final directUrl =
            '$apiUrl?emp_key=$empKey&financial_year_key=$financialYearKey&leave_type_key=$leaveTypeKey';
        final resp = await http.get(Uri.parse(directUrl), headers: {
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
            .post(
              Uri.parse(apiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
              },
              body: jsonEncode(bodyMap),
            )
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          return {'success': true, 'data': data};
        }
      } catch (e) {}

      return {
        'success': false,
        'message': 'Failed to fetch leave transactions'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
