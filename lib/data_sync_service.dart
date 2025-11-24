import 'dart:async';
import 'package:easytime_online/data_storage_service.dart';
import 'package:easytime_online/monthly_work_hours_api.dart';
import 'package:easytime_online/weekly_work_hours_api.dart';
import 'package:easytime_online/status_pie_chart_api.dart';
import 'package:easytime_online/attendance_history_api.dart';
import 'package:flutter/foundation.dart';

class DataSyncService {
  final MonthlyWorkHoursApi _monthlyWorkHoursApi = MonthlyWorkHoursApi();
  final WeeklyWorkHoursApi _weeklyWorkHoursApi = WeeklyWorkHoursApi();
  final StatusPieChartApi _statusPieChartApi = StatusPieChartApi();
  final AttendanceHistoryApi _attendanceHistoryApi = AttendanceHistoryApi();

  StreamSubscription? _monthlyWorkHoursSubscription;
  StreamSubscription? _weeklyWorkHoursSubscription;
  StreamSubscription? _statusPieChartSubscription;
  StreamSubscription? _attendanceHistorySubscription;

  // Singleton pattern
  static final DataSyncService _instance = DataSyncService._internal();
  factory DataSyncService() => _instance;
  DataSyncService._internal();

  // Initialize data from local storage and then sync with API
  Future<void> initialize(String empKey) async {
    await _loadDataFromLocalStorage();
    await syncAllData(empKey);
  }

  // Load data from local storage
  Future<void> _loadDataFromLocalStorage() async {
    try {
      if (kDebugMode) {
        print('Loading data from local storage');
      }
      // Load all data types from local storage
      // This will be used to display data immediately while API calls are in progress
    } catch (e) {
      if (kDebugMode) {
        print('Error loading data from local storage: $e');
      }
    }
  }

  // Sync all data with API
  Future<void> syncAllData(String empKey) async {
    await _syncMonthlyWorkHours(empKey);
    await _syncWeeklyWorkHours(empKey);
    await _syncStatusPieChartData(empKey);
    await _syncAttendanceHistory(empKey);
    await DataStorageService.saveLastSyncTime();
  }

  // Sync monthly work hours
  Future<String> _syncMonthlyWorkHours(String empKey) async {
    try {
      // First try to get from local storage
      String? cachedHours = await DataStorageService.getMonthlyWorkHours();
      
      // Set up subscription to API
      _monthlyWorkHoursSubscription?.cancel();
      _monthlyWorkHoursApi.fetchMonthlyWorkHours(empKey);
      _monthlyWorkHoursSubscription = _monthlyWorkHoursApi.workHoursStream.listen((result) async {
        // Extract work hours from result map
        if (result['success'] == true && result.containsKey('work_hours')) {
          String hours = result['work_hours'].toString();
          // Save to local storage
          await DataStorageService.saveMonthlyWorkHours(hours);
          if (kDebugMode) {
            print('Monthly work hours updated: $hours');
          }
        }
      }, onError: (error) {
        if (kDebugMode) {
          print('Error fetching monthly work hours: $error');
        }
      });
      
      return cachedHours ?? "00:00";
    } catch (e) {
      if (kDebugMode) {
        print('Error in monthly work hours sync: $e');
      }
      return "00:00";
    }
  }

  // Sync weekly work hours
  Future<String> _syncWeeklyWorkHours(String empKey) async {
    try {
      // First try to get from local storage
      String? cachedHours = await DataStorageService.getWeeklyWorkHours();
      
      // Set up subscription to API
      _weeklyWorkHoursSubscription?.cancel();
      _weeklyWorkHoursApi.fetchWeeklyWorkHours(empKey);
      _weeklyWorkHoursSubscription = _weeklyWorkHoursApi.workHoursStream.listen((result) async {
        // Extract work hours from result map
        if (result['success'] == true && result.containsKey('work_hours')) {
          String hours = result['work_hours'].toString();
          // Save to local storage
          await DataStorageService.saveWeeklyWorkHours(hours);
          if (kDebugMode) {
            print('Weekly work hours updated: $hours');
          }
        }
      }, onError: (error) {
        if (kDebugMode) {
          print('Error fetching weekly work hours: $error');
        }
      });
      
      return cachedHours ?? "00:00";
    } catch (e) {
      if (kDebugMode) {
        print('Error in weekly work hours sync: $e');
      }
      return "00:00";
    }
  }

  // Sync status pie chart data
  Future<Map<String, dynamic>?> _syncStatusPieChartData(String empKey) async {
    try {
      // First try to get from local storage
      Map<String, dynamic>? cachedData = await DataStorageService.getStatusPieChartData();
      
      // Set up subscription to API
      _statusPieChartSubscription?.cancel();
      _statusPieChartApi.fetchStatusPieChart(empKey);
      _statusPieChartSubscription = _statusPieChartApi.statusDataStream.listen((data) async {
        // Save to local storage
        await DataStorageService.saveStatusPieChartData(data);
        if (kDebugMode) {
          print('Status pie chart data updated');
        }
      }, onError: (error) {
        if (kDebugMode) {
          print('Error fetching status pie chart data: $error');
        }
      });
      
      return cachedData;
    } catch (e) {
      if (kDebugMode) {
        print('Error in status pie chart data sync: $e');
      }
      return null;
    }
  }

  // Sync attendance history
  Future<List<dynamic>?> _syncAttendanceHistory(String empKey) async {
    try {
      // First try to get from local storage
      List<dynamic>? cachedData = await DataStorageService.getAttendanceHistory();
      
      // Set up subscription to API
      _attendanceHistorySubscription?.cancel();
      _attendanceHistoryApi.fetchAttendanceHistory(empKey);
      _attendanceHistorySubscription = _attendanceHistoryApi.attendanceDataStream.listen((data) async {
        // Extract attendance list from the response map and save to local storage
        if (data['success'] == true && data.containsKey('attendance')) {
          List<dynamic> attendanceList = data['attendance'];
          await DataStorageService.saveAttendanceHistory(attendanceList);
          if (kDebugMode) {
            print('Attendance history updated');
          }
        }
      }, onError: (error) {
        if (kDebugMode) {
          print('Error fetching attendance history: $error');
        }
      });
      
      return cachedData;
    } catch (e) {
      if (kDebugMode) {
        print('Error in attendance history sync: $e');
      }
      return null;
    }
  }

  // Dispose all subscriptions
  void dispose() {
    _monthlyWorkHoursSubscription?.cancel();
    _weeklyWorkHoursSubscription?.cancel();
    _statusPieChartSubscription?.cancel();
    _attendanceHistorySubscription?.cancel();
  }
}