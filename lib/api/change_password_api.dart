import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:easytime_online/api/client_codes_fetch_api.dart';

class ChangePasswordApi {
  static const int _timeoutSeconds = 10;

  // Build URL candidates (https then http) from stored base URL
  static List<String> _buildCandidates(String baseUrl) {
    String clean = baseUrl;
    if (clean.endsWith('/')) clean = clean.substring(0, clean.length - 1);

    try {
      final uri = Uri.parse(clean);
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        final https = uri.replace(scheme: 'https').toString();
        final httpUrl = uri.replace(scheme: 'http').toString();
        return [https, httpUrl];
      }
    } catch (e) {}

    return ['https://$clean', 'http://$clean'];
  }

  static Future<Map<String, dynamic>> _postToUrl(
      String url, Map<String, dynamic> jsonBody) async {
    try {
      // Primary: send as form-encoded POST (CodeIgniter's get_post reads $_POST)
      final formResponse = await http
          .post(Uri.parse(url),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: jsonBody.entries
                  .map((e) =>
                      '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
                  .join('&'))
          .timeout(const Duration(seconds: _timeoutSeconds));

      if (formResponse.statusCode == 200) {
        try {
          return json.decode(formResponse.body) as Map<String, dynamic>;
        } catch (e) {
          return {
            'success': false,
            'message': 'Invalid JSON response',
            'response_body': formResponse.body
          };
        }
      }

      // Fallback: try GET with query params
      final queryUrl = Uri.parse(url).replace(
          queryParameters: jsonBody.map(
        (k, v) => MapEntry(k, v.toString()),
      ));

      final getResponse = await http.post(queryUrl, headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: _timeoutSeconds));

      if (getResponse.statusCode == 200) {
        try {
          return json.decode(getResponse.body) as Map<String, dynamic>;
        } catch (e) {
          return {
            'success': false,
            'message': 'Invalid JSON response',
            'response_body': getResponse.body
          };
        }
      }

      // Last resort: try JSON body
      final jsonResponse = await http
          .post(Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(jsonBody))
          .timeout(const Duration(seconds: _timeoutSeconds));

      if (jsonResponse.statusCode == 200) {
        try {
          return json.decode(jsonResponse.body) as Map<String, dynamic>;
        } catch (e) {
          return {
            'success': false,
            'message': 'Invalid JSON response',
            'response_body': jsonResponse.body
          };
        }
      }

      return {
        'success': false,
        'message': 'Server returned ${formResponse.statusCode}'
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> verifyOldPassword(
      String empKey, String oldPassword) async {
    try {
      final base = await ApiService.getClientApiUrl();
      final candidates = _buildCandidates(base);

      for (final candidate in candidates) {
        final url = '$candidate/api/change_password';
        final res = await _postToUrl(url, {
          'emp_key': empKey,
          'old_password': oldPassword,
        });

        if (res.containsKey('success')) return res;
      }

      return {'success': false, 'message': 'Could not reach server'};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> changePassword(String empKey,
      String oldPassword, String newPassword, String confirm) async {
    try {
      final base = await ApiService.getClientApiUrl();
      final candidates = _buildCandidates(base);

      for (final candidate in candidates) {
        final url = '$candidate/api/change_password';
        final res = await _postToUrl(url, {
          'emp_key': empKey,
          'old_password': oldPassword,
          'new_password': newPassword,
          'confirm_password': confirm,
        });

        if (res.containsKey('success')) return res;
      }

      return {'success': false, 'message': 'Could not reach server'};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }
}
