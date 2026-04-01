import 'dart:convert';

import 'package:easytime_online/api/today_punches_api.dart';
import 'package:http/http.dart' as http;

class TodayAllPunchesApi {
  static final TodayAllPunchesApi _instance = TodayAllPunchesApi._internal();
  factory TodayAllPunchesApi() => _instance;
  TodayAllPunchesApi._internal();

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
      if (cleanUrl.endsWith('/'))
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);

      final apiUrl = '$cleanUrl/api/today_all_punches';
      final Map<String, String> queryParams = {'emp_key': empKey, 'date': date};

      http.Response? response;

      // Try GET with query parameters
      try {
        response = await http.get(
            Uri.parse(apiUrl).replace(queryParameters: queryParams),
            headers: {
              'Accept': 'application/json',
            }).timeout(const Duration(seconds: 20));
      } catch (_) {
        response = null;
      }

      // Try JSON POST if GET failed
      if (response == null || response.statusCode >= 400) {
        try {
          response = await http
              .post(Uri.parse(apiUrl),
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                  },
                  body: jsonEncode(queryParams))
              .timeout(const Duration(seconds: 20));
        } catch (_) {
          response = response; // keep existing null or previous value
        }
      }

      // Try form-encoded POST as a final fallback
      if (response == null || response.statusCode >= 400) {
        try {
          response = await http
              .post(Uri.parse(apiUrl),
                  headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                    'Accept': 'application/json',
                  },
                  body: queryParams)
              .timeout(const Duration(seconds: 20));
        } catch (_) {
          response = response;
        }
      }

      if (response == null) {
        return {
          'success': false,
          'message': 'No response from server',
          'punch_list': <Map<String, dynamic>>[],
        };
      }

      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
          'punch_list': <Map<String, dynamic>>[],
        };
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return {
          'success': false,
          'message': 'Invalid response format',
          'punch_list': <Map<String, dynamic>>[],
          'raw_response': decoded,
        };
      }

      final bool success =
          decoded['success'] == true || decoded['status'] == true;

      // Common keys where servers may return list data
      dynamic rawList = decoded['punch_list'] ??
          decoded['data'] ??
          decoded['punches'] ??
          decoded['items'];

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

      if (!success) {
        return {
          'success': false,
          'message': decoded['message']?.toString() ?? 'Failed to load punches',
          'punch_list': punchList,
          'raw_response': decoded,
        };
      }

      return {
        'success': true,
        'message': decoded['message']?.toString() ?? '',
        'punch_list': punchList,
        'raw_response': decoded,
        'base_url': cleanUrl,
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
