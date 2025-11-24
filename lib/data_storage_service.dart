import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DataStorageService {
  static const String _monthlyWorkHoursKey = 'monthly_work_hours';
  static const String _weeklyWorkHoursKey = 'weekly_work_hours';
  static const String _statusPieChartDataKey = 'status_pie_chart_data';
  static const String _attendanceHistoryKey = 'attendance_history';
  static const String _lastSyncTimeKey = 'last_sync_time';

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
}