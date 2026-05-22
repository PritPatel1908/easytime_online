import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class PendingMobilePunchesApi {
  static final PendingMobilePunchesApi _instance =
      PendingMobilePunchesApi._internal();
  factory PendingMobilePunchesApi() => _instance;
  PendingMobilePunchesApi._internal();

  static Future<String> _getBaseApiUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? baseUrl = prefs.getString('base_api_url');
    return baseUrl ?? 'http://att.easytimeonline.in:121';
  }

  Future<Map<String, dynamic>> fetchPendingMobilePunches(
      {required String approverKey}) async {
    try {
      final baseUrl = await _getBaseApiUrl();
      var cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }
      final apiUrl = '$cleanUrl/api/pending_mobile_punches';

      final bodyMap = {'approver_key': approverKey};

      // Try form POST
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

      // GET fallback
      try {
        final uri =
            '$apiUrl?approver_key=${Uri.encodeComponent(bodyMap['approver_key']!)}';
        final resp = await http.get(Uri.parse(uri), headers: {
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          return {'success': true, 'data': data};
        }
      } catch (e) {}

      // JSON POST fallback
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
        'message': 'Failed to fetch pending mobile punches'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> performApproveMobilePunch({
    required List<String> keys,
    required bool approve,
    String? note,
    required String approverKey,
  }) async {
    try {
      final baseUrl = await _getBaseApiUrl();
      var cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/'))
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      final apiUrl = '$cleanUrl/api/approve_mobile_punch';

      final inOutPunchKey = keys.join(',');
      final bodyMap = {
        'in_out_punch_key': inOutPunchKey,
        // use 'true'/'false' strings for form POST to match server expectations
        'approve': approve ? 'true' : 'false',
        'note': note ?? '',
        'approver_key': approverKey,
      };

      // Try form POST
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

      // JSON POST fallback
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
        'message': 'Failed to call approve_mobile_punch'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Approve or reject mobile punch(es).
  ///
  /// Parameters:
  /// - [approverKey]: emp_key of the approver
  /// - [inOutPunchKeys]: list of in_out_punch_key values (one or many)
  /// - [approve]: true to approve, false to reject
  /// - [note]: optional note/reason
  Future<Map<String, dynamic>> approveMobilePunch({
    required String approverKey,
    required List<String> inOutPunchKeys,
    required bool approve,
    String? note,
  }) async {
    try {
      final baseUrl = await _getBaseApiUrl();
      var cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }
      final apiUrl = '$cleanUrl/api/approve_mobile_punch';

      // Build form body (strings) — server often expects numeric approve flag for form posts
      final bodyMap = <String, String>{
        'approver_key': approverKey,
        // use 'true'/'false' strings for form POST
        'approve': approve ? 'true' : 'false',
        'note': note ?? '',
      };
      if (inOutPunchKeys.isNotEmpty) {
        bodyMap['in_out_punch_key'] = inOutPunchKeys.length == 1
            ? inOutPunchKeys.first
            : inOutPunchKeys.join(',');
      }

      // Debug payload
      try {
        debugPrint('approveMobilePunch FORM POST -> $apiUrl');
        debugPrint('body: $bodyMap');
      } catch (_) {}

      // Try form POST first — build explicit URL-encoded body to guarantee note is included
      try {
        final sb = StringBuffer();
        void addParam(String k, String v) {
          if (sb.isNotEmpty) sb.write('&');
          sb.write(
              '${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(v)}');
        }

        addParam('approver_key', approverKey);
        addParam('approve', approve ? 'true' : 'false');
        addParam('note', note ?? '');

        // include both comma-separated and repeated array params to maximize server compatibility
        if (inOutPunchKeys.isNotEmpty) {
          final joined = inOutPunchKeys.join(',');
          addParam('in_out_punch_key', joined);
          if (inOutPunchKeys.length > 1) {
            for (final k in inOutPunchKeys) {
              sb.write(
                  '&${Uri.encodeQueryComponent('in_out_punch_key[]')}=${Uri.encodeQueryComponent(k)}');
            }
          }
        }

        final formBody = sb.toString();
        try {
          debugPrint('approveMobilePunch FORM POST body: $formBody');
        } catch (_) {}

        final resp = await http
            .post(Uri.parse(apiUrl),
                headers: {
                  'Content-Type':
                      'application/x-www-form-urlencoded; charset=UTF-8'
                },
                body: formBody)
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          final bool ok = (data['status'] == true) || (data['success'] == true);
          return {
            'success': ok,
            'data': data,
            'message': data['message'] ?? ''
          };
        }
      } catch (e) {
        debugPrint('approveMobilePunch form post failed: $e');
      }

      // JSON POST fallback (send keys as array when multi)
      try {
        final jsonBody = <String, dynamic>{
          'approver_key': approverKey,
          'approve': approve,
          'note': note,
          'in_out_punch_key': inOutPunchKeys.length == 1
              ? inOutPunchKeys.first
              : inOutPunchKeys,
        };
        try {
          debugPrint('approveMobilePunch JSON POST -> $apiUrl');
          debugPrint('jsonBody: $jsonBody');
        } catch (_) {}
        final resp = await http
            .post(Uri.parse(apiUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json'
                },
                body: jsonEncode(jsonBody))
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(resp.body);
          final bool ok = (data['status'] == true) || (data['success'] == true);
          return {
            'success': ok,
            'data': data,
            'message': data['message'] ?? ''
          };
        }
      } catch (e) {
        debugPrint('approveMobilePunch json post failed: $e');
      }

      // GET fallback (only for single key) — include note if present
      if (inOutPunchKeys.length == 1) {
        try {
          final q = StringBuffer();
          q.write(
              'in_out_punch_key=${Uri.encodeComponent(inOutPunchKeys.first)}');
          q.write('&approve=${approve ? 'true' : 'false'}');
          q.write('&approver_key=${Uri.encodeComponent(approverKey)}');
          if ((note ?? '').isNotEmpty) {
            q.write('&note=${Uri.encodeComponent(note!)}');
          }
          final uri = '$apiUrl?$q';
          debugPrint('approveMobilePunch GET -> $uri');
          final resp = await http.get(Uri.parse(uri), headers: {
            'Accept': 'application/json'
          }).timeout(const Duration(seconds: 15));
          if (resp.statusCode == 200) {
            final Map<String, dynamic> data = json.decode(resp.body);
            final bool ok =
                (data['status'] == true) || (data['success'] == true);
            return {
              'success': ok,
              'data': data,
              'message': data['message'] ?? ''
            };
          }
        } catch (e) {
          debugPrint('approveMobilePunch get failed: $e');
        }
      }

      return {
        'success': false,
        'message': 'Failed to call approve_mobile_punch'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
