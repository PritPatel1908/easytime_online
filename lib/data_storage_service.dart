import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DataStorageService {
  static const String _monthlyWorkHoursKey = 'monthly_work_hours';
  static const String _weeklyWorkHoursKey = 'weekly_work_hours';
  static const String _statusPieChartDataKey = 'status_pie_chart_data';
  static const String _attendanceHistoryKey = 'attendance_history';
  static const String _lastSyncTimeKey = 'last_sync_time';
  static const String _userRightsKey = 'user_rights_json';

  // Save monthly work hours to local storage
  static Future<void> saveMonthlyWorkHours(String hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_monthlyWorkHoursKey, hours);
  }

  // Get monthly work hours from local storage
  static Future<String?> getMonthlyWorkHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_monthlyWorkHoursKey);
  }

  // Save weekly work hours to local storage
  static Future<void> saveWeeklyWorkHours(String hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_weeklyWorkHoursKey, hours);
  }

  // Get weekly work hours from local storage
  static Future<String?> getWeeklyWorkHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_weeklyWorkHoursKey);
  }

  // Save status pie chart data to local storage
  static Future<void> saveStatusPieChartData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statusPieChartDataKey, jsonEncode(data));
  }

  // Get status pie chart data from local storage
  static Future<Map<String, dynamic>?> getStatusPieChartData() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString(_statusPieChartDataKey);
    if (dataString != null) {
      return jsonDecode(dataString) as Map<String, dynamic>;
    }
    return null;
  }

  // Save attendance history to local storage
  static Future<void> saveAttendanceHistory(List<dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_attendanceHistoryKey, jsonEncode(data));
  }

  // Get attendance history from local storage
  static Future<List<dynamic>?> getAttendanceHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString(_attendanceHistoryKey);
    if (dataString != null) {
      return jsonDecode(dataString) as List<dynamic>;
    }
    return null;
  }

  // Save last sync time
  static Future<void> saveLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncTimeKey, DateTime.now().toIso8601String());
  }

  // Get last sync time
  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString(_lastSyncTimeKey);
    if (timeString != null) {
      return DateTime.parse(timeString);
    }
    return null;
  }

  // Clear all stored data
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ╔════════════════════════════════════════════════════════════════════╗
  // ║                  USER RIGHTS & PERMISSIONS                         ║
  // ╚════════════════════════════════════════════════════════════════════╝

  /// Save complete user_rights object from login response
  /// Stores both the full structure and individual read permission flags
  static Future<void> saveUserRights(Map<String, dynamic> userRights) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userRightsKey, jsonEncode(userRights));
    } catch (e) {
      print('Error saving user rights: $e');
    }
  }

  /// Retrieve complete user_rights object from local storage
  static Future<Map<String, dynamic>?> getUserRights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataString = prefs.getString(_userRightsKey);
      if (dataString != null && dataString.isNotEmpty) {
        return jsonDecode(dataString) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error retrieving user rights: $e');
    }
    return null;
  }

  /// Check read permission for a specific module
  /// Returns true if read permission exists and is true, false otherwise
  static Future<bool> canReadModule(String moduleName) async {
    try {
      final rights = await getUserRights();
      if (rights != null && rights.containsKey(moduleName)) {
        final moduleRights = rights[moduleName];
        if (moduleRights is Map && moduleRights.containsKey('read')) {
          return _coerceToBool(moduleRights['read']);
        }
      }
    } catch (e) {
      print('Error checking read permission for $moduleName: $e');
    }
    // If rights data is absent or key missing, default to DENY for safety.
    // Returning false prevents access when permissions haven't been loaded yet.
    print(
        'DataStorageService: permission missing for $moduleName — defaulting to false');
    return false;
  }

  /// Check create permission for a specific module
  static Future<bool> canCreateInModule(String moduleName) async {
    try {
      final rights = await getUserRights();
      if (rights != null && rights.containsKey(moduleName)) {
        final moduleRights = rights[moduleName];
        if (moduleRights is Map && moduleRights.containsKey('create')) {
          return _coerceToBool(moduleRights['create']);
        }
      }
    } catch (e) {
      print('Error checking create permission for $moduleName: $e');
    }
    print(
        'DataStorageService: create permission missing for $moduleName — defaulting to false');
    return false;
  }

  /// Check approve permission for a specific module
  static Future<bool> canApproveInModule(String moduleName) async {
    try {
      final rights = await getUserRights();
      if (rights != null && rights.containsKey(moduleName)) {
        final moduleRights = rights[moduleName];
        if (moduleRights is Map && moduleRights.containsKey('approve')) {
          return _coerceToBool(moduleRights['approve']);
        }
      }
    } catch (e) {
      print('Error checking approve permission for $moduleName: $e');
    }
    print(
        'DataStorageService: approve permission missing for $moduleName — defaulting to false');
    return false;
  }

  /// Helper: coerce dynamic value to boolean
  static bool _coerceToBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) {
      final low = v.toLowerCase();
      return low == '1' || low == 'true' || low == 'yes';
    }
    return false;
  }

  /// Clear user rights on logout
  static Future<void> clearUserRights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userRightsKey);
    } catch (e) {
      print('Error clearing user rights: $e');
    }
  }
}
