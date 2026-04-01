import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PendingRequestsApi {
  static final PendingRequestsApi _instance = PendingRequestsApi._internal();
  factory PendingRequestsApi() => _instance;
  PendingRequestsApi._internal();

  static Future<String> _getBaseApiUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? baseUrl = prefs.getString('base_api_url');
    return baseUrl ?? 'http://att.easytimeonline.in:121';
  }

  Future<Map<String, dynamic>> fetchPendingRequests(
      {required String empKey, String entityName = ''}) async {
    try {
      final baseUrl = await _getBaseApiUrl();
      var cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }
      final apiUrl = '$cleanUrl/api/pending_requests';

      final bodyMap = {'emp_key': empKey, 'entity_name': entityName};

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
            '$apiUrl?emp_key=${Uri.encodeComponent(bodyMap['emp_key']!)}&entity_name=${Uri.encodeComponent(bodyMap['entity_name']!)}';
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

      return {'success': false, 'message': 'Failed to fetch pending requests'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Perform approve/reject action for pending requests.
  ///
  /// Parameters:
  /// - [creatorOwner]: emp_key of the user performing the action
  /// - [action]: either 'approve_selected' or 'reject_selected'
  /// - [entityName]: entity name/type for the record(s)
  /// - [selectedIds]: comma-separated request_details_key(s) or a single id
  /// - [reason]: optional rejection reason (required when action is 'reject_selected')
  Future<Map<String, dynamic>> performPendingRequestAction({
    required String creatorOwner,
    required String action,
    required String entityName,
    required String selectedIds,
    String? reason,
  }) async {
    try {
      final baseUrl = await _getBaseApiUrl();
      var cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }
      final apiUrl = '$cleanUrl/api/do_pending_request_action';

      final bodyMap = <String, String>{
        'action': action,
        'entity_name': entityName,
        'selected_ids': selectedIds,
        'creator_owner': creatorOwner,
      };
      if (reason != null) bodyMap['reason'] = reason;

      // Try form POST first
      try {
        final resp = await http
            .post(Uri.parse(apiUrl),
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: bodyMap)
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
      } catch (e) {}

      // JSON POST fallback
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
          final bool ok = (data['status'] == true) || (data['success'] == true);
          return {
            'success': ok,
            'data': data,
            'message': data['message'] ?? ''
          };
        }
      } catch (e) {}

      return {
        'success': false,
        'message': 'Failed to perform pending request action'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Perform batch actions using the `requests` array supported by the server.
  /// Each entry should be a map with keys: `entity_name`, `action`, `selected_ids` (array or string), and optional `reason`.
  Future<Map<String, dynamic>> performBatchPendingRequestAction({
    required String creatorOwner,
    required List<Map<String, dynamic>> requests,
  }) async {
    try {
      final baseUrl = await _getBaseApiUrl();
      var cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }
      final apiUrl = '$cleanUrl/api/do_pending_request_action';

      // Try form POST first. Build a urlencoded body that encodes the
      // `requests` array using nested parameter names so PHP/CI will parse
      // it as an array (requests[0][entity_name], requests[0][selected_ids][]).
      try {
        final sb = StringBuffer();
        sb.write('creator_owner=${Uri.encodeQueryComponent(creatorOwner)}');
        for (int i = 0; i < requests.length; i++) {
          final req = requests[i];
          // entity_name, action, reason -> scalar
          req.forEach((k, v) {
            if (k == 'selected_ids') return; // handle below
            if (v == null) return;
            sb.write(
                '&requests[${i}][${Uri.encodeQueryComponent(k)}]=${Uri.encodeQueryComponent(v.toString())}');
          });
          // selected_ids may be List or single value
          final sel = req['selected_ids'];
          if (sel is List) {
            for (final id in sel) {
              sb.write(
                  '&requests[${i}][selected_ids][]=${Uri.encodeQueryComponent(id.toString())}');
            }
          } else if (sel != null) {
            sb.write(
                '&requests[${i}][selected_ids][]=${Uri.encodeQueryComponent(sel.toString())}');
          }
        }

        final resp = await http
            .post(Uri.parse(apiUrl),
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: sb.toString())
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
      } catch (e) {}

      // JSON POST fallback (requests as proper JSON array)
      try {
        final body = {'creator_owner': creatorOwner, 'requests': requests};
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
          final bool ok = (data['status'] == true) || (data['success'] == true);
          return {
            'success': ok,
            'data': data,
            'message': data['message'] ?? ''
          };
        }
      } catch (e) {}

      return {
        'success': false,
        'message': 'Failed to perform batch pending request action'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
