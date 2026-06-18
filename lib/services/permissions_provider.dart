import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionsProvider extends ChangeNotifier {
  Map<String, dynamic> _rights = {};

  Map<String, dynamic> get rights => _rights;

  bool get hasAnyRights => _rights.isNotEmpty;

  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('user_rights_json') ??
          prefs.getString('user_rights') ??
          '';
      if (s.isNotEmpty) {
        final decoded = json.decode(s);
        if (decoded is Map<String, dynamic>) {
          _rights = decoded;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> setRights(Map<String, dynamic> rights) async {
    _rights = Map<String, dynamic>.from(rights);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_rights_json', json.encode(_rights));
    } catch (_) {}
  }

  bool _coerceToBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) {
      final low = v.toLowerCase();
      return low == '1' || low == 'true' || low == 'yes';
    }
    return false;
  }

  // Normalize keys to a comparable form (remove non-alphanum and lowercase)
  String _clean(String s) =>
      s.replaceAll(RegExp(r'[^a-z0-9]'), '').toLowerCase();

  // Find the best-matching right key for a requested entity
  String? _resolveKey(String entity) {
    if (_rights.isEmpty) return null;
    final want = _clean(entity);
    // Direct match
    for (final k in _rights.keys) {
      if (_clean(k.toString()) == want) return k.toString();
    }
    // Common aliases
    final aliases = {
      'manualpunch': ['misspunch', 'miss_punch', 'manual_punch'],
      'manualattendance': ['manual_att', 'manual_attendance', 'manualatt'],
      'pendingrequest': [
        'pending_request',
        'pendingrequests',
        'pending_requests'
      ],
      'leaveapplication': ['leave_application', 'leaveapplication', 'leave'],
    };
    for (final entry in aliases.entries) {
      if (entry.key == want) {
        for (final a in entry.value) {
          for (final k in _rights.keys) {
            if (_clean(k.toString()) == _clean(a)) return k.toString();
          }
        }
      }
    }
    // Try fuzzy match: any rights key that contains the wanted substring
    for (final k in _rights.keys) {
      final kk = _clean(k.toString());
      if (kk.contains(want) || want.contains(kk)) return k.toString();
    }
    return null;
  }

  bool _getPermission(String entity, String action) {
    try {
      final k = _resolveKey(entity);
      if (k == null) return false;
      final val = _rights[k];
      if (val is Map && val.containsKey(action)) {
        return _coerceToBool(val[action]);
      }
    } catch (_) {}
    return false;
  }

  bool canRead(String entity) => _getPermission(entity, 'read');
  bool canCreate(String entity) => _getPermission(entity, 'create');
  bool canApprove(String entity) => _getPermission(entity, 'approve');
}
