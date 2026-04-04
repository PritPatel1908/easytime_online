import 'dart:convert';

import 'package:easytime_online/api/today_punches_api.dart';
import 'package:http/http.dart' as http;

class TodayAllPunchesApi {
  static final TodayAllPunchesApi _instance = TodayAllPunchesApi._internal();
  factory TodayAllPunchesApi() => _instance;
  TodayAllPunchesApi._internal();

  bool _isTruthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value == null) return false;
    final normalized = value.toString().trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'ok' ||
        normalized == 'success';
  }

  Map<String, dynamic> _buildParsedResult({
    required dynamic decoded,
    required String cleanUrl,
    required int statusCode,
    required String requestType,
  }) {
    if (decoded is! Map) {
      return {
        'success': false,
        'message': 'Invalid response format',
        'punch_list': <Map<String, dynamic>>[],
        'raw_response': decoded,
        'status_code': statusCode,
        'request_type': requestType,
      };
    }

    final map = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded);

    dynamic rawList = map['punch_list'] ??
        map['data'] ??
        map['punches'] ??
        map['items'] ??
        map['records'];

    final List<Map<String, dynamic>> punchList = <Map<String, dynamic>>[];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          punchList.add(item);
        } else if (item is Map) {
          punchList.add(Map<String, dynamic>.from(item));
        }
      }
    }

    final bool success = _isTruthy(map['success']) ||
        _isTruthy(map['status']) ||
        (punchList.isNotEmpty &&
            map['success'] == null &&
            map['status'] == null);

    return {
      'success': success,
      'message': map['message']?.toString() ??
          (success ? '' : 'Failed to load punches'),
      'punch_list': punchList,
      'raw_response': map,
      'base_url': cleanUrl,
      'status_code': statusCode,
      'request_type': requestType,
    };
  }

  Future<Map<String, dynamic>> fetchTodayAllPunches({
    required String empKey,
    required String date,
  }) async {
    if (empKey.trim().isEmpty) {
      return {
        'success': false,
        'message': 'Employee key is required',
        'punch_list': <Map<String, dynamic>>[],
      };
    }

    if (date.trim().isEmpty) {
      return {
        'success': false,
        'message': 'Date is required',
        'punch_list': <Map<String, dynamic>>[],
      };
    }

    try {
      final baseUrl = await TodayPunchesApi.getBaseApiUrl();
      String cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      final apiUrl = '$cleanUrl/api/today_all_punches';
      final Map<String, String> queryParams = {'emp_key': empKey, 'date': date};
      Future<http.Response> requestFormPost() {
        return http
            .post(
              Uri.parse(apiUrl),
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Accept': 'application/json',
              },
              body: queryParams,
            )
            .timeout(const Duration(seconds: 20));
      }

      Future<http.Response> requestGet() {
        return http.get(
          Uri.parse(apiUrl).replace(queryParameters: queryParams),
          headers: {
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 20));
      }

      Future<http.Response> requestJsonPost() {
        return http
            .post(
              Uri.parse(apiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(queryParams),
            )
            .timeout(const Duration(seconds: 20));
      }

      final attempts = <MapEntry<String, Future<http.Response> Function()>>[
        MapEntry<String, Future<http.Response> Function()>(
            'form-post', requestFormPost),
        MapEntry<String, Future<http.Response> Function()>('get', requestGet),
        MapEntry<String, Future<http.Response> Function()>(
            'json-post', requestJsonPost),
      ];

      Map<String, dynamic>? firstParsed;
      final List<String> debugErrors = <String>[];

      for (final attempt in attempts) {
        try {
          final response = await attempt.value();
          if (response.statusCode < 200 || response.statusCode >= 300) {
            debugErrors.add('${attempt.key}: http ${response.statusCode}');
            continue;
          }

          dynamic decoded;
          try {
            decoded = jsonDecode(response.body);
          } catch (_) {
            debugErrors.add('${attempt.key}: invalid json body');
            continue;
          }

          final parsed = _buildParsedResult(
            decoded: decoded,
            cleanUrl: cleanUrl,
            statusCode: response.statusCode,
            requestType: attempt.key,
          );

          firstParsed ??= parsed;

          if (parsed['success'] == true) {
            return parsed;
          }

          debugErrors.add('${attempt.key}: ${parsed['message']}');
        } catch (e) {
          debugErrors.add('${attempt.key}: $e');
        }
      }

      return {
        'success': false,
        'message': firstParsed?['message']?.toString() ??
            'No valid response from server',
        'punch_list':
            firstParsed?['punch_list'] as List<Map<String, dynamic>>? ??
                <Map<String, dynamic>>[],
        'raw_response': firstParsed?['raw_response'],
        'base_url': cleanUrl,
        'debug_attempts': debugErrors,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
        'punch_list': <Map<String, dynamic>>[],
      };
    }
  }
}
