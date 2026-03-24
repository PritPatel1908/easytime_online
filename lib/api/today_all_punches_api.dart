import 'dart:convert';

import 'package:easytime_online/api/today_punches_api.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TodayAllPunchesApi {
  Future<Map<String, dynamic>> fetchTodayAllPunches({
    required String empKey,
    required String date,
  }) async {
    if (empKey.trim().isEmpty) {
      return {'success': false, 'message': 'Employee key is required'};
    }

    if (date.trim().isEmpty) {
      return {'success': false, 'message': 'Date is required'};
    }

    try {
      final baseUrl = await TodayPunchesApi.getBaseApiUrl();
      String cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      final apiUrl = '$cleanUrl/api/today_all_punches';
      final queryParams = {'emp_key': empKey, 'date': date};

      if (kDebugMode) {
        print('Fetching today_all_punches from: $apiUrl');
        print('Query params: $queryParams');
      }

      http.Response response = await http.get(
          Uri.parse(apiUrl).replace(queryParameters: queryParams),
          headers: {
            'Accept': 'application/json',
          }).timeout(const Duration(seconds: 20));

      if (response.statusCode >= 400) {
        response = await http
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

      if (response.statusCode >= 400) {
        response = await http
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

      if (kDebugMode) {
        print('today_all_punches status: ${response.statusCode}');
        print('today_all_punches body: ${response.body}');
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
        };
      }

      final success = decoded['success'] == true || decoded['status'] == true;
      final rawList = decoded['punch_list'];
      final punchList = <Map<String, dynamic>>[];

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
      if (kDebugMode) {
        print('today_all_punches error: $e');
      }
      return {
        'success': false,
        'message': e.toString(),
        'punch_list': <Map<String, dynamic>>[],
      };
    }
  }
}
