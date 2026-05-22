import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/manual_attendance.dart';

class ManualAttendanceService {
  final String baseUrl;

  ManualAttendanceService({required this.baseUrl});

  Future<List<ManualAttendanceApplication>> getByEmpKeys(
      List<String> empKeys) async {
    final url = Uri.parse(
        '$baseUrl/api/get_manual_attendance_applications_by_emp_keys');
    final joined = empKeys.join(',');

    // Try form-encoded POST first (server generally expects form data)
    try {
      final resp = await http.post(url,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'emp_key': joined, 'employee_keys': joined}).timeout(
        const Duration(seconds: 15),
      );
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        List<dynamic> listData = [];
        if (decoded is List) {
          listData = decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          listData = decoded['data'] as List<dynamic>;
        }
        return listData
            .map((e) => ManualAttendanceApplication.fromJson(
                Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}

    // JSON fallback
    try {
      final resp = await http
          .post(url,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
              },
              body: jsonEncode({'employee_keys': empKeys}))
          .timeout(
            const Duration(seconds: 15),
          );
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        List<dynamic> listData = [];
        if (decoded is List) {
          listData = decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          listData = decoded['data'] as List<dynamic>;
        }
        return listData
            .map((e) => ManualAttendanceApplication.fromJson(
                Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}

    throw Exception(
        'Failed to fetch manual attendance applications: ${url.toString()}');
  }

  Future<bool> validateAndSubmit(ManualAttendanceApplication app) async {
    return validateAndSubmitWithCreator(app, creatorOwner: null);
  }

  Future<bool> validateAndSubmitWithCreator(ManualAttendanceApplication app,
      {String? creatorOwner}) async {
    final url = Uri.parse(
        '$baseUrl/api/validate_and_submit_manual_attendance_application');
    final joined = app.employeeKeys.join(',');

    final bodyMap = {
      'emp_key': joined,
      'employee_keys': joined,
      'in_datetime': app.inDatetime.toIso8601String(),
      'out_datetime': app.outDatetime.toIso8601String(),
      'reason': app.reason,
      'creator_owner': creatorOwner ?? ''
    };

    // Try form-encoded POST first
    try {
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: bodyMap.map((k, v) => MapEntry(k, v.toString())),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return true;
    } catch (_) {}

    // JSON fallback
    try {
      final resp = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: jsonEncode(bodyMap),
          )
          .timeout(const Duration(seconds: 15));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
