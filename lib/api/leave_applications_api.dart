import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeaveApplicationsApi {
  static final LeaveApplicationsApi _instance =
      LeaveApplicationsApi._internal();
  factory LeaveApplicationsApi() => _instance;
  LeaveApplicationsApi._internal();

  static Future<String> _getBaseApiUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? baseUrl = prefs.getString('base_api_url');
    return baseUrl ?? 'http://att.easytimeonline.in:121';
  }

  Future<Map<String, dynamic>> fetchByEmpKeys(List<dynamic> empKeys) async {
    try {
      final baseUrl = await _getBaseApiUrl();
      var cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/'))
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      final apiUrl = '$cleanUrl/api/leave_applications_by_emp_keys';

      if (kDebugMode)
        print('Fetching leave applications for emp_keys=${empKeys.join(',')}');

      final bodyMap = {'emp_key': empKeys.map((e) => e.toString()).join(',')};

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

      return {
        'success': false,
        'message': 'Failed to fetch leave applications'
      };
    } catch (e) {
      if (kDebugMode) print('fetchByEmpKeys error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> validateSubmit({
    required List<String> empKeys,
    required String leaveTypeKey,
    required bool onlyHalfDay,
    required bool isThisSecondHalf,
    DateTime? fromDate,
    required bool isFromHalfDay,
    DateTime? toDate,
    required bool isToHalfDay,
    required String reason,
    String? creatorOwner,
  }) async {
    try {
      final baseUrl = await _getBaseApiUrl();
      var cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/'))
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      final apiUrl = '$cleanUrl/api/validate_submit';

      if (kDebugMode)
        print(
            'Calling validate_submit: emp_keys=${empKeys.join(',')} creator_owner=${creatorOwner ?? ''}');

      final bodyMap = {
        'emp_key': empKeys.join(','),
        'leave_type': leaveTypeKey,
        'only_half_day': onlyHalfDay.toString(),
        'is_this_second_half': isThisSecondHalf.toString(),
        'from_date': fromDate != null ? fromDate.toIso8601String() : '',
        'is_from_half_day': isFromHalfDay.toString(),
        'to_date': toDate != null ? toDate.toIso8601String() : '',
        'is_to_half_day': isToHalfDay.toString(),
        'reason': reason,
        'creator_owner': creatorOwner ?? '',
      };

      final List<String> attemptErrors = [];
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
          try {
            final Map<String, dynamic> data = json.decode(resp.body);
            return {'success': true, 'data': data};
          } catch (e) {
            attemptErrors
                .add('Form POST decode error: $e | body: ${resp.body}');
          }
        } else {
          attemptErrors
              .add('Form POST non-200 ${resp.statusCode}: ${resp.body}');
        }
      } catch (e) {
        attemptErrors.add('Form POST error: $e');
        if (kDebugMode) print('Form POST error: $e');
      }

      // GET fallback
      try {
        final uri = apiUrl +
            '?emp_key=${Uri.encodeComponent(bodyMap['emp_key']!)}&leave_type=${Uri.encodeComponent(bodyMap['leave_type']!)}&creator_owner=${Uri.encodeComponent(bodyMap['creator_owner']!)}';
        final resp = await http.get(Uri.parse(uri), headers: {
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 15));
        if (kDebugMode) print('GET response: ${resp.statusCode} ${resp.body}');
        if (resp.statusCode == 200) {
          try {
            final Map<String, dynamic> data = json.decode(resp.body);
            return {'success': true, 'data': data};
          } catch (e) {
            attemptErrors.add('GET decode error: $e | body: ${resp.body}');
          }
        } else {
          attemptErrors.add('GET non-200 ${resp.statusCode}: ${resp.body}');
        }
      } catch (e) {
        attemptErrors.add('GET error: $e');
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
          try {
            final Map<String, dynamic> data = json.decode(resp.body);
            return {'success': true, 'data': data};
          } catch (e) {
            attemptErrors
                .add('JSON POST decode error: $e | body: ${resp.body}');
          }
        } else {
          attemptErrors
              .add('JSON POST non-200 ${resp.statusCode}: ${resp.body}');
        }
      } catch (e) {
        attemptErrors.add('JSON POST error: $e');
        if (kDebugMode) print('JSON POST error: $e');
      }

      final message = attemptErrors.isNotEmpty
          ? 'Failed to validate submit: ${attemptErrors.join(' | ')}'
          : 'Failed to validate submit';
      return {'success': false, 'message': message};
    } catch (e) {
      if (kDebugMode) print('validateSubmit error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> fetchLeaveTypesByEmpKeys(
      List<dynamic> empKeys) async {
    try {
      final baseUrl = await _getBaseApiUrl();
      var cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/'))
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      final apiUrl = '$cleanUrl/api/get_leave_types_by_emp_keys';

      if (kDebugMode)
        print('Fetching leave types for emp_keys=${empKeys.join(',')}');

      final bodyMap = {'emp_key': empKeys.map((e) => e.toString()).join(',')};

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

      return {'success': false, 'message': 'Failed to fetch leave types'};
    } catch (e) {
      if (kDebugMode) print('fetchLeaveTypesByEmpKeys error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
