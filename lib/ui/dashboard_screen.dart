import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:easytime_online/api/monthly_work_hours_api.dart';
import 'package:easytime_online/api/today_punches_api.dart';
import 'package:easytime_online/ui/monthly_work_hours_detail_screen.dart';
import 'package:easytime_online/ui/approver_screen.dart';
import 'package:easytime_online/ui/team_screen.dart';
import 'package:easytime_online/ui/my_leave_balance_screen.dart';
import 'package:easytime_online/ui/leave_application_screen.dart';
import 'package:easytime_online/ui/manual_punch_list_screen.dart';
import 'package:easytime_online/ui/pending_request_screen.dart';
import 'package:easytime_online/ui/check_in_out_screen.dart';
import 'package:easytime_online/ui/manual_attendance_list_screen.dart';
import 'package:easytime_online/api/status_pie_chart_api.dart';
import 'package:easytime_online/ui/change_password_screen.dart';
import 'package:easytime_online/ui/attendance_history_screen.dart';
import 'package:easytime_online/ui/time_card_screen.dart';
import 'package:easytime_online/ui/my_punches_screen.dart';
import 'package:easytime_online/api/attendance_history_api.dart';
import 'package:easytime_online/data_sync_service.dart';
import 'package:easytime_online/data_storage_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easytime_online/main/main.dart';
import 'package:easytime_online/api/client_codes_fetch_api.dart';

// Production: treat debug-mode checks as disabled (remove debug-only branches)
const bool kDebugMode = false;

class DashboardScreen extends StatefulWidget {
  final String? userName;
  final String? emp_code;
  final Map<String, dynamic>? userData;
  final String empKey;

  const DashboardScreen(
      {super.key,
      this.userName,
      this.emp_code,
      this.userData,
      required this.empKey});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _mainScrollController = ScrollController();
  late TabController _tabController;
  int _currentIndex = 0;
  bool _allowMobilePunch = false;

  // Add state variables for work hours
  String _monthlyWorkHours = "0.0";
  bool _isLoadingMonthlyWorkHours = false;
  String _monthlyWorkHoursError = "";

  // Add state variables for today's punches
  // Today's punch values (in/out)
  String _inPunch = "";
  String _outPunch = "";
  bool _isLoadingTodayPunches = false;
  String _todayPunchesError = "";

  // Data sync service
  final DataSyncService _dataSyncService = DataSyncService();

  // API instances
  final MonthlyWorkHoursApi _monthlyWorkHoursApi = MonthlyWorkHoursApi();
  final TodayPunchesApi _todayPunchesApi = TodayPunchesApi();
  final StatusPieChartApi _statusPieChartApi = StatusPieChartApi();
  final AttendanceHistoryApi _attendanceHistoryApi = AttendanceHistoryApi();

  // Stream subscriptions
  StreamSubscription? _monthlyWorkHoursSubscription;
  StreamSubscription? _todayPunchesSubscription;
  StreamSubscription? _statusPieChartSubscription;

  // Status Pie Chart Data
  Map<String, dynamic>? _statusPieChartData;
  bool _isLoadingStatusPieChart = false;
  String _statusPieChartError = "";
  bool _isInitialLoad = true;

  // Reorderable stats state
  List<String> _statOrder = ['Monthly', 'Today'];
  bool _isReorderMode = false; // when true, scrolling disabled
  String? _activeDragItem; // item allowed to be dragged after long hold
  Timer? _longPressTimer;
  bool _isHolding = false; // true while finger is down during long-hold

  @override
  void initState() {
    super.initState();

    // Ensure system UI settings are maintained
    SystemUIUtil.hideSystemNavigationBar();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));

    _tabController = TabController(length: 2, vsync: this);

    try {
      // Try to log full userData structure for debugging
      if (widget.userData != null) {
        if (kDebugMode) {}
      }
    } catch (e) {
      if (kDebugMode) {}
    }

    // Start background service for work hours
    _setupWorkHoursServices();

    // Initialize permission flags from login response
    _allowMobilePunch = _extractAllowMobilePunch(widget.userData);

    // Load saved stat order
    _loadStatOrder();

    // Prefetch attendance history data in background
    _prefetchAttendanceHistory();
  }

  Future<void> _loadStatOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('dashboard_stat_order');
      if (list != null && list.isNotEmpty) {
        setState(() {
          _statOrder = list;
        });
      }
    } catch (e) {}
  }

  Future<void> _saveStatOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('dashboard_stat_order', _statOrder);
    } catch (e) {}
  }

  void _startLongHold(String id) {
    _longPressTimer?.cancel();
    setState(() {
      _isHolding = true;
    });
    _longPressTimer = Timer(const Duration(seconds: 10), () {
      setState(() {
        _isReorderMode = true;
        _activeDragItem = id;
        _isHolding = false; // reorder mode now controls scrolling
        // Provide haptic feedback to indicate reorder mode is active
        try {
          HapticFeedback.vibrate();
        } catch (_) {}
      });
    });
  }

  void _cancelLongHold() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    if (_isHolding) {
      setState(() {
        _isHolding = false;
      });
    }
  }

  // Prefetch attendance history data in background
  void _prefetchAttendanceHistory() {
    String? empKey = _findEmployeeKey();
    if (empKey != null) {
      if (kDebugMode) {}

      // Get current month and year
      final now = DateTime.now();
      final currentMonth = now.month.toString().padLeft(2, '0');
      final currentYear = now.year.toString();

      // Fetch current month's attendance data
      _attendanceHistoryApi.fetchAttendanceHistory(
        empKey,
        month: currentMonth,
        year: currentYear,
      );
    }
  }

  // Logout handler: clears user prefs and returns to login (HomeScreen)
  Future<void> _performLogout() async {
    final should = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (should != true) return;

    // Preserve saved session data. Do NOT clear SharedPreferences here
    // to avoid flushing saved credentials or other session data.
    // If you need to remove specific keys on logout, do so explicitly.

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(title: 'EasyTime Online'),
      ),
      (route) => false,
    );
  }

  // Set up work hours background services
  void _setupWorkHoursServices() {
    String? empKey = _findEmployeeKey();
    if (empKey != null) {
      // Set loading state
      setState(() {
        _isLoadingMonthlyWorkHours = true;
        _isLoadingTodayPunches = true;
      });

      // Subscribe to monthly work hours updates
      _monthlyWorkHoursSubscription =
          _monthlyWorkHoursApi.workHoursStream.listen((result) {
        if (mounted) {
          setState(() {
            _isLoadingMonthlyWorkHours = false;

            if (result['success'] == true && result.containsKey('work_hours')) {
              // Format work hours to display
              var workHoursValue = result['work_hours'];
              if (kDebugMode) {}

              // Check if it's in HH:MM format
              if (workHoursValue is String && workHoursValue.contains(':')) {
                // It's in time format (HH:MM)
                List<String> parts = workHoursValue.split(':');
                if (parts.length == 2) {
                  try {
                    // Just validate the format without using the parsed values
                    int.parse(parts[0]);
                    int.parse(parts[1]);
                    // Use the original value from API without any calculations
                    _monthlyWorkHours = workHoursValue;
                    if (kDebugMode) {}
                  } catch (e) {
                    if (kDebugMode) {}
                    _monthlyWorkHours =
                        workHoursValue; // Just use the original string
                  }
                } else {
                  _monthlyWorkHours =
                      workHoursValue; // Just use the original string
                }
              } else {
                // Just use the original value without any formatting
                _monthlyWorkHours = workHoursValue.toString();
              }

              if (kDebugMode) {}
            } else {
              _monthlyWorkHoursError =
                  result['message'] ?? "Failed to load monthly work hours";
              if (kDebugMode) {}
            }
          });
        }
      });

      // Subscribe to today punches updates
      _todayPunchesSubscription = _todayPunchesApi.punchStream.listen((result) {
        if (mounted) {
          setState(() {
            _isLoadingTodayPunches = false;

            if (result['success'] == true) {
              _inPunch = result['in_punch']?.toString() ?? '';
              _outPunch = result['out_punch']?.toString() ?? '';
              _todayPunchesError = '';
              if (kDebugMode) {}
            } else {
              _todayPunchesError =
                  result['message'] ?? 'Failed to load today punches';
              if (kDebugMode) {}
            }
          });
        }
      });

      // Start periodic updates for monthly and today punches (every 5 minutes)
      _monthlyWorkHoursApi.startPeriodicUpdates(empKey,
          interval: const Duration(minutes: 5));
      _todayPunchesApi.startPeriodicUpdates(empKey,
          interval: const Duration(minutes: 5));
      // Also fetch once and print raw response to debug console
      try {
        _todayPunchesApi.fetchAndLog(empKey);
      } catch (e) {}

      // Subscribe to status pie chart data updates
      setState(() {
        _isLoadingStatusPieChart = true;
      });

      // Validate employee key one more time specifically for pie chart
      if (empKey.trim().isEmpty && !kDebugMode) {
        if (kDebugMode) {}
        setState(() {
          _isLoadingStatusPieChart = false;
          _statusPieChartError = "Employee key is empty";
        });
      } else {
        if (kDebugMode) {}

        // Make sure empKey is a valid string for API call
        final validEmpKey = empKey.trim();
        if (kDebugMode) {}

        // Set up the stream subscription first
        _statusPieChartSubscription =
            _statusPieChartApi.statusDataStream.listen((result) {
          if (kDebugMode) {}
          if (mounted) {
            setState(() {
              _isLoadingStatusPieChart = false;
              _isInitialLoad = false;

              if (result['success'] == true &&
                  result.containsKey('status_data')) {
                // Compare with existing data before updating
                final newData = result['status_data'];
                final bool shouldUpdate = _statusPieChartData == null ||
                    !_areMapContentsEqual(_statusPieChartData!, newData);

                if (shouldUpdate) {
                  _statusPieChartData = newData;
                  // Save to local storage for persistence
                  DataStorageService.saveStatusPieChartData(newData);
                }

                _statusPieChartError = "";
                if (kDebugMode && shouldUpdate) {}
              } else {
                // Only update error if we don't already have data
                if (_statusPieChartData == null) {
                  _statusPieChartError =
                      result['message'] ?? "Failed to load status data";
                  if (kDebugMode) {}
                }
              }
            });
          }
        });

        // Start periodic updates for status pie chart
        try {
          // Make an immediate direct call to fetch data
          if (kDebugMode) {}
          _statusPieChartApi.fetchStatusPieChart(validEmpKey);

          // Then set up periodic updates
          _statusPieChartApi.startPeriodicUpdates(validEmpKey,
              interval: const Duration(minutes: 15));
          if (kDebugMode) {}
        } catch (e) {
          if (kDebugMode) {}
          setState(() {
            _statusPieChartError = "Error: $e";
          });
        }
      }
    } else {
      setState(() {
        _monthlyWorkHoursError = "Employee key not found";
        _todayPunchesError = "Employee key not found";
        _statusPieChartError = "Employee key not found";
      });

      if (kDebugMode) {}
    }
  }

  // Helper method to compare two maps for equality
  bool _areMapContentsEqual(
      Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.length != map2.length) return false;

    for (final key in map1.keys) {
      if (!map2.containsKey(key)) return false;

      if (map1[key] != map2[key]) return false;
    }

    return true;
  }

  // Helper method to find employee key in userData
  String? _findEmployeeKey() {
    // Prefer the explicit empKey passed to the Dashboard if available
    try {
      final String fromWidget = widget.empKey;
      if (fromWidget.trim().isNotEmpty) return fromWidget.trim();
    } catch (_) {}

    // If userData is not provided, return null (no further fallback)
    if (widget.userData == null) {
      if (kDebugMode) {}
      return null;
    }

    try {
      if (kDebugMode) {}
    } catch (e) {
      if (kDebugMode) {}
    }

    // Fallback to hardcoded empKey for development/testing
    const String fallbackEmpKey = "1234"; // Default test emp_key
    String? foundEmpKey;

    // Check for emp_key in different possible locations in userData
    if (widget.userData!.containsKey('emp_key')) {
      if (kDebugMode) {}
      foundEmpKey = widget.userData!['emp_key']?.toString();
    }

    // Check user_data path
    if (foundEmpKey == null && widget.userData!.containsKey('user_data')) {
      var userData = widget.userData!['user_data'];
      if (userData is Map) {
        if (userData.containsKey('emp_key')) {
          if (kDebugMode) {}
          foundEmpKey = userData['emp_key']?.toString();
        } else {
          if (kDebugMode) {}
        }
      } else {
        if (kDebugMode) {}
      }
    }

    // Check response_data.user_data path
    if (foundEmpKey == null && widget.userData!.containsKey('response_data')) {
      var responseData = widget.userData!['response_data'];
      if (responseData is Map && responseData.containsKey('user_data')) {
        var userData = responseData['user_data'];
        if (userData is Map && userData.containsKey('emp_key')) {
          if (kDebugMode) {}
          foundEmpKey = userData['emp_key']?.toString();
        } else {
          if (kDebugMode) {}
        }
      } else {
        if (kDebugMode) {}
      }
    }

    // Check user path
    if (foundEmpKey == null && widget.userData!.containsKey('user')) {
      var user = widget.userData!['user'];
      if (user is Map && user.containsKey('emp_key')) {
        if (kDebugMode) {}
        foundEmpKey = user['emp_key']?.toString();
      } else {
        if (kDebugMode) {}
      }
    }

    // Check data path
    if (foundEmpKey == null && widget.userData!.containsKey('data')) {
      var data = widget.userData!['data'];
      if (data is Map) {
        if (data.containsKey('emp_key')) {
          if (kDebugMode) {}
          foundEmpKey = data['emp_key']?.toString();
        } else if (data.containsKey('user')) {
          var user = data['user'];
          if (user is Map && user.containsKey('emp_key')) {
            if (kDebugMode) {}
            foundEmpKey = user['emp_key']?.toString();
          } else {
            if (kDebugMode) {}
          }
        } else {
          if (kDebugMode) {}
        }
      } else {
        if (kDebugMode) {}
      }
    }

    // Check raw_response path
    if (foundEmpKey == null && widget.userData!.containsKey('raw_response')) {
      var rawResponse = widget.userData!['raw_response'];
      if (rawResponse is Map) {
        var empKey = _findEmpKeyInMap(rawResponse);
        if (empKey != null) {
          if (kDebugMode) {}
          foundEmpKey = empKey;
        } else {
          if (kDebugMode) {}
        }
      } else {
        if (kDebugMode) {}
      }
    }

    // If we've exhausted all known paths, try a deep search in the entire userData object
    if (foundEmpKey == null) {
      if (kDebugMode) {}
      foundEmpKey = _findEmpKeyDeep(widget.userData!);
      if (foundEmpKey != null && foundEmpKey.isNotEmpty) {
        if (kDebugMode) {}
      }
    }

    // Validate the found empKey before returning
    if (foundEmpKey != null) {
      // Trim any whitespace
      foundEmpKey = foundEmpKey.trim();

      if (kDebugMode) {}

      // Only return if it's not empty after trimming
      if (foundEmpKey.isNotEmpty) {
        return foundEmpKey;
      } else {
        if (kDebugMode) {}
      }
    }

    // Always use fallback in debug mode, otherwise return null
    if (kDebugMode) {
      return fallbackEmpKey;
    }

    if (kDebugMode) {}
    return null;
  }

  // Deep search function to look through nested maps and lists
  String? _findEmpKeyDeep(dynamic obj, [int depth = 0, int maxDepth = 5]) {
    // Stop at a reasonable depth to prevent infinite recursion
    if (depth > maxDepth) return null;

    if (obj is Map) {
      // Direct check for the key
      if (obj.containsKey('emp_key')) {
        return obj['emp_key'].toString();
      }

      // Check all entries
      for (var entry in obj.entries) {
        var key = entry.key;
        var value = entry.value;

        // If the key itself is emp_key, return the value
        if (key is String && key.toLowerCase() == 'emp_key') {
          return value.toString();
        }

        // Recursively check all map values
        if (value is Map || value is List) {
          var result = _findEmpKeyDeep(value, depth + 1, maxDepth);
          if (result != null) return result;
        }
      }
    } else if (obj is List) {
      // For each item in the list, recursively check it
      for (var item in obj) {
        if (item is Map || item is List) {
          var result = _findEmpKeyDeep(item, depth + 1, maxDepth);
          if (result != null) return result;
        }
      }
    }

    return null;
  }

  // Format time string to HH:MM (strip seconds). If invalid, return original or '-'.
  String _formatToHHMM(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return '-';
    try {
      // Accept formats like HH:MM:SS or HH:MM
      final parts = timeStr.trim().split(':');
      if (parts.length >= 2) {
        final hh = parts[0].padLeft(2, '0');
        final mm = parts[1].padLeft(2, '0');
        return '$hh:$mm';
      }
      return timeStr;
    } catch (_) {
      return timeStr;
    }
  }

  // Helper method to recursively search for emp_key in a nested map
  String? _findEmpKeyInMap(Map<dynamic, dynamic> map) {
    // Direct check for emp_key
    if (map.containsKey('emp_key')) {
      return map['emp_key'].toString();
    }

    // Check all map values that are maps themselves
    for (var key in map.keys) {
      var value = map[key];
      if (value is Map) {
        var empKey = _findEmpKeyInMap(value);
        if (empKey != null) {
          return empKey;
        }
      } else if (key == 'emp_key') {
        return value.toString();
      }
    }

    return null;
  }

  // Helper to locate announcements list anywhere inside a nested object
  List<dynamic>? _locateAnnouncements(dynamic obj, [int depth = 0]) {
    if (depth > 6) return null;
    if (obj == null) return null;
    if (obj is Map) {
      for (final key in obj.keys) {
        if (key is String) {
          final low = key.toLowerCase();
          if (low == 'announcements' || low == 'announcement') {
            final val = obj[key];
            if (val is List) return val;
            if (val is Map) return [val];
          }
        }
      }

      for (final entry in obj.entries) {
        final v = entry.value;
        if (v is Map || v is List) {
          final res = _locateAnnouncements(v, depth + 1);
          if (res != null) return res;
        }
      }
    } else if (obj is List) {
      for (final item in obj) {
        if (item is Map || item is List) {
          final res = _locateAnnouncements(item, depth + 1);
          if (res != null) return res;
        }
      }
    }
    return null;
  }

  // Extract allow_mobile_punch flag from various response shapes
  bool _extractAllowMobilePunch(dynamic obj, [int depth = 0]) {
    if (depth > 6) return false;
    if (obj == null) return false;

    try {
      if (obj is Map) {
        // direct key
        if (obj.containsKey('allow_mobile_punch')) {
          final v = obj['allow_mobile_punch'];
          return _coerceToBool(v);
        }

        // nested user_data
        if (obj.containsKey('user_data') && obj['user_data'] is Map) {
          final v = obj['user_data']['allow_mobile_punch'];
          if (v != null) return _coerceToBool(v);
        }

        // response_data
        if (obj.containsKey('response_data') && obj['response_data'] is Map) {
          final v = obj['response_data']['allow_mobile_punch'];
          if (v != null) return _coerceToBool(v);
          // also user_data inside response_data
          final ud = obj['response_data']['user_data'];
          if (ud is Map && ud.containsKey('allow_mobile_punch')) {
            return _coerceToBool(ud['allow_mobile_punch']);
          }
        }

        // deep search for the key
        for (final entry in obj.entries) {
          final val = entry.value;
          if (val is Map || val is List) {
            final res = _extractAllowMobilePunch(val, depth + 1);
            if (res) return true;
          }
        }
      } else if (obj is List) {
        for (final item in obj) {
          final res = _extractAllowMobilePunch(item, depth + 1);
          if (res) return true;
        }
      }
    } catch (e) {}

    return false;
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

  @override
  void dispose() {
    // Cancel work hours subscriptions
    _monthlyWorkHoursSubscription?.cancel();
    _todayPunchesSubscription?.cancel();
    _statusPieChartSubscription?.cancel();

    // Stop periodic updates
    _monthlyWorkHoursApi.stopPeriodicUpdates();
    _todayPunchesApi.stopPeriodicUpdates();
    // Do not dispose the singleton StatusPieChartApi here — only stop its timer.
    // Disposing the singleton closes its stream controller which prevents
    // new DashboardScreen instances from listening after a logout/login.
    _statusPieChartApi.stopPeriodicUpdates();

    _mainScrollController.dispose();
    _tabController.dispose();
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-evaluate allow_mobile_punch when userData updates
    final updated = _extractAllowMobilePunch(widget.userData);
    if (updated != _allowMobilePunch) {
      setState(() {
        _allowMobilePunch = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double scaleFactor =
        (MediaQuery.of(context).size.width / 360).clamp(0.75, 1.0);
    // Prefer explicit emp_code if provided, else fallback to userData['emp_code'], then empKey
    final String displayEmpCode = widget.emp_code ??
        widget.userData?['emp_code']?.toString() ??
        widget.empKey;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        controller: _mainScrollController,
        physics: (_isReorderMode || _isHolding)
            ? const NeverScrollableScrollPhysics()
            : const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${widget.userName ?? ''} ($displayEmpCode)',
                      style: TextStyle(
                        fontSize: 20 * scaleFactor,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'logout') {
                        _performLogout();
                      } else if (value == 'change_password') {
                        String? empKey = _findEmployeeKey();
                        if (empKey != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChangePasswordScreen(
                                empKey: empKey,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Employee key not found.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'change_password',
                        child: Row(
                          children: [
                            Icon(Icons.lock, color: Colors.black54),
                            SizedBox(width: 8),
                            Text('Change Password'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: Colors.black54),
                            SizedBox(width: 8),
                            Text('Logout'),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(13),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          widget.userName?.isNotEmpty == true
                              ? widget.userName![0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Stats Cards (reorderable)
          SliverToBoxAdapter(
            child: Container(
              height: 100,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  for (int i = 0; i < _statOrder.length; i++)
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: i == _statOrder.length - 1 ? 0 : 12),
                        child: _buildReorderableStatItem(_statOrder[i]),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Quick Actions
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 16 * scaleFactor,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickActionButton(
                        icon: Icons.login,
                        label: 'Check In',
                        color: Colors.green,
                        scale: scaleFactor,
                        onTap: () async {
                          String? empKey = _findEmployeeKey();
                          if (empKey == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Employee key not found.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (!_allowMobilePunch) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Mobile punch is disabled for your account.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CheckInOutScreen(
                                headerTitle: 'Check In',
                                empKey: empKey,
                              ),
                            ),
                          );

                          // If the check-in screen popped with emp_key, refresh today's punches
                          if (result is Map && result['emp_key'] != null) {
                            final res =
                                await _todayPunchesApi.fetchTodayPunches(
                                    result['emp_key'].toString());
                            if (mounted && res['success'] == true) {
                              setState(() {
                                _inPunch = res['in_punch']?.toString() ?? '';
                                _outPunch = res['out_punch']?.toString() ?? '';
                              });
                            }
                          }
                        },
                        enabled: _allowMobilePunch,
                      ),
                      _buildQuickActionButton(
                        icon: Icons.logout,
                        label: 'Check Out',
                        color: Colors.red,
                        scale: scaleFactor,
                        onTap: () async {
                          String? empKey = _findEmployeeKey();
                          if (empKey == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Employee key not found.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (!_allowMobilePunch) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Mobile punch is disabled for your account.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CheckInOutScreen(
                                headerTitle: 'Check Out',
                                empKey: empKey,
                              ),
                            ),
                          );
                          if (result is Map && result['emp_key'] != null) {
                            final res =
                                await _todayPunchesApi.fetchTodayPunches(
                                    result['emp_key'].toString());
                            if (mounted && res['success'] == true) {
                              setState(() {
                                _inPunch = res['in_punch']?.toString() ?? '';
                                _outPunch = res['out_punch']?.toString() ?? '';
                              });
                            }
                          }
                        },
                        enabled: _allowMobilePunch,
                      ),
                      _buildQuickActionButton(
                        icon: Icons.history,
                        label: 'My Punches',
                        color: Colors.teal,
                        scale: scaleFactor,
                        onTap: () {
                          String? empKey = _findEmployeeKey();
                          if (empKey != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MyPunchesScreen(empKey: empKey),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Employee key not found. Cannot load punches.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                      _buildQuickActionButton(
                        icon: Icons.access_time,
                        label: 'Time Card',
                        color: Colors.blue,
                        scale: scaleFactor,
                        onTap: () {
                          String? empKey = _findEmployeeKey();
                          if (empKey != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TimeCardScreen(
                                  empKey: empKey,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Employee key not found. Cannot load time card.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Announcements Card (separate section below Quick Actions)
          SliverToBoxAdapter(
            child: _buildAnnouncementCard(),
          ),

          // Status Pie Chart
          SliverToBoxAdapter(
            child: _buildStatusPieChart(),
          ),

          // Tab Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).primaryColor,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: 'Applications'),
                  Tab(text: 'Views'),
                ],
              ),
            ),
          ),

          // Tab Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Projects Tab (Applications)
                _buildProjectsTab(),

                // Team Tab (Views)
                _buildTeamTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 12 * scaleFactor),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex > 1 ? 0 : _currentIndex,
          onDestinationSelected: (index) {
            if (index == 1) {
              // Navigate to Attendance History screen
              String? empKey = _findEmployeeKey();
              if (empKey != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceHistoryScreen(
                      empKey: empKey,
                      userData: widget.userData,
                      userName: widget.userName,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Employee key not found. Cannot load attendance history.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } else {
              setState(() {
                _currentIndex = index;
              });
            }
          },
          backgroundColor: Colors.white,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.access_time_outlined),
              selectedIcon: Icon(Icons.access_time),
              label: 'Attendance',
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for UI components
  Widget _buildStatusPieChart() {
    return _buildStatusPieChartWidget();
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required int flex,
    bool isWorkHours = false,
  }) {
    return GestureDetector(
      onTap: () {
        // Handle tap based on card type
        if (title == 'Monthly') {
          _navigateToMonthlyWorkHoursDetail();
        } else if (title == 'Today') {
          // Future implementation for today punches details
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withAlpha(179)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(77),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12 *
                          (MediaQuery.of(context).size.width / 360)
                              .clamp(0.75, 1.0),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 6),
                  // For Today card show IN/OUT on two lines with larger text
                  if (title == 'Today')
                    Flexible(
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'IN: ${_inPunch.isNotEmpty ? _formatToHHMM(_inPunch) : '-'}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32 *
                                    (MediaQuery.of(context).size.width / 360)
                                        .clamp(0.75, 1.0),
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'OUT: ${_outPunch.isNotEmpty ? _formatToHHMM(_outPunch) : '-'}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30 *
                                    (MediaQuery.of(context).size.width / 360)
                                        .clamp(0.75, 1.0),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22 *
                                (MediaQuery.of(context).size.width / 360)
                                    .clamp(0.75, 1.0),
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withAlpha(204),
                      fontSize: 10 *
                          (MediaQuery.of(context).size.width / 360)
                              .clamp(0.75, 1.0),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build a reorderable stat item wrapped with drag target and draggable
  Widget _buildReorderableStatItem(String id) {
    Widget card;
    if (id == 'Monthly') {
      card = _buildStatCard(
        title: 'Monthly',
        value: _isLoadingMonthlyWorkHours ? "..." : _monthlyWorkHours,
        subtitle: _monthlyWorkHoursError.isNotEmpty
            ? _monthlyWorkHoursError
            : 'This month',
        color: Colors.blue,
        icon: Icons.calendar_month,
        flex: 1,
        isWorkHours: true,
      );
    } else {
      card = _buildStatCard(
        title: 'Today',
        value: _isLoadingTodayPunches
            ? "..."
            : ((_inPunch.isNotEmpty || _outPunch.isNotEmpty)
                ? 'IN: $_inPunch  OUT: $_outPunch'
                : 'No punches'),
        subtitle: _todayPunchesError.isNotEmpty ? _todayPunchesError : '',
        color: Colors.green,
        icon: Icons.access_time,
        flex: 1,
        isWorkHours: true,
      );
    }

    return GestureDetector(
      onTapDown: (_) => _startLongHold(id),
      onTapUp: (_) => _cancelLongHold(),
      onTapCancel: () => _cancelLongHold(),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) => details.data != id,
        onAcceptWithDetails: (details) {
          final sourceId = details.data;
          // swap positions
          final from = _statOrder.indexOf(sourceId);
          final to = _statOrder.indexOf(id);
          if (from >= 0 && to >= 0) {
            setState(() {
              final item = _statOrder.removeAt(from);
              _statOrder.insert(to, item);
              _isReorderMode = false;
              _activeDragItem = null;
            });
            _saveStatOrder();
          }
        },
        builder: (context, candidateData, rejectedData) {
          final highlight = candidateData.isNotEmpty;
          Widget child = Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  border: highlight
                      ? Border.all(
                          color: Theme.of(context).primaryColor, width: 2)
                      : null,
                ),
                child: card,
              ),
              if (_isReorderMode && _activeDragItem == id)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.drag_indicator, color: Colors.white70),
                ),
            ],
          );

          // If this item is active for dragging, wrap it in Draggable
          if (_isReorderMode && _activeDragItem == id) {
            return Draggable<String>(
              data: id,
              feedback: _buildStatCardFeedback(id),
              childWhenDragging: Opacity(opacity: 0.4, child: card),
              onDragEnd: (details) {
                // reset reorder mode after drag
                setState(() {
                  _isReorderMode = false;
                  _activeDragItem = null;
                });
                _cancelLongHold();
              },
              child: child,
            );
          }

          return child;
        },
      ),
    );
  }

  // Compact drag feedback to avoid huge overlay while dragging
  Widget _buildStatCardFeedback(String id) {
    final bool isMonthly = id == 'Monthly';
    final Color color = isMonthly ? Colors.blue : Colors.green;
    final String title = isMonthly ? 'Monthly' : 'Today';
    final String value = isMonthly
        ? (_isLoadingMonthlyWorkHours ? '...' : _monthlyWorkHours)
        : (_isLoadingTodayPunches
            ? '...'
            : ((_inPunch.isNotEmpty || _outPunch.isNotEmpty)
                ? 'IN: ${_formatToHHMM(_inPunch)}\nOUT: ${_formatToHHMM(_outPunch)}'
                : 'No punches'));

    final double width = (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2;
    const double height = 100;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withAlpha(179)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Navigate to Monthly Work Hours Detail Screen
  void _navigateToMonthlyWorkHoursDetail() {
    String? empKey = _findEmployeeKey();
    if (empKey != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MonthlyWorkHoursDetailScreen(
            empKey: empKey,
            totalWorkHours: _monthlyWorkHours,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee key not found. Cannot load details.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    double scale = 1.0,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (enabled ? color : Colors.grey).withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: enabled ? color : Colors.grey, size: 22),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 12 * scale,
                    color: enabled ? const Color(0xFF555555) : Colors.grey),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard() {
    try {
      final List<dynamic>? annListInitial =
          _locateAnnouncements(widget.userData ?? {});

      return FutureBuilder<Map<String, dynamic>>(
        future: SharedPreferences.getInstance().then((prefs) {
          final String baseRaw =
              prefs.getString('base_api_url') ?? ApiService.defaultBaseUrl;
          final String baseUrl = baseRaw.endsWith('/')
              ? baseRaw.substring(0, baseRaw.length - 1)
              : baseRaw;

          final String? stored = prefs.getString('latest_announcements_json');
          List<dynamic>? storedList;
          if (stored != null && stored.isNotEmpty) {
            try {
              final decoded = jsonDecode(stored);
              if (decoded is List) {
                storedList = decoded;
              } else if (decoded is Map) {
                storedList = [decoded];
              }
            } catch (_) {}
          }

          return {'baseUrl': baseUrl, 'storedList': storedList};
        }),
        builder: (context, snapshot) {
          final String baseUrl = (snapshot.data?['baseUrl'] as String?) ??
              ApiService.defaultBaseUrl;
          final List<dynamic>? storedList =
              snapshot.data?['storedList'] as List<dynamic>?;

          List<dynamic> annList = annListInitial ?? [];
          if (annList.isEmpty && storedList != null && storedList.isNotEmpty) {
            annList = storedList;
          }

          if (annList.isEmpty) return const SizedBox.shrink();

          // Build a card for each announcement
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.campaign, color: Color(0xFFFF6B35), size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Announcements',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ),
                ...annList.map((item) {
                  final Map<String, dynamic> ann = item is Map
                      ? Map<String, dynamic>.from(item)
                      : {'message': item?.toString() ?? ''};

                  final String docFile = ann['document_file']?.toString() ?? '';
                  final String imageUrl =
                      docFile.isNotEmpty ? '$baseUrl/uploads/$docFile' : '';
                  final String message = ann['message']?.toString() ?? '';
                  final String uploaderName = ann['emp_name']?.toString() ?? '';
                  final String date =
                      ann['announcement_created_at']?.toString() ?? '';

                  return GestureDetector(
                    onTap: () => _showAnnouncementDetail(ann, baseUrl),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFF6B35).withAlpha(40),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(8),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Thumbnail
                          imageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    imageUrl,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, st) =>
                                        _announcementPlaceholder(),
                                  ),
                                )
                              : _announcementPlaceholder(),
                          const SizedBox(width: 12),
                          // Text content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF333333),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (uploaderName.isNotEmpty) ...[
                                      Icon(Icons.person_outline,
                                          size: 13, color: Colors.grey[500]),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          uploaderName,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Tap arrow
                          Icon(Icons.chevron_right,
                              color: Colors.grey[400], size: 22),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _announcementPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B35).withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.campaign, color: Color(0xFFFF6B35), size: 26),
    );
  }

  void _showAnnouncementDetail(Map<String, dynamic> ann, String baseUrl) {
    final String message = ann['message']?.toString() ?? '';
    final String uploaderName = ann['emp_name']?.toString() ?? '';
    final String docFile = ann['document_file']?.toString() ?? '';
    final String imageUrl =
        docFile.isNotEmpty ? '$baseUrl/uploads/$docFile' : '';
    final String date = ann['announcement_created_at']?.toString() ?? '';
    final String fromDate = ann['from_date']?.toString() ?? '';
    final String toDate = ann['to_date']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.campaign,
                              color: Color(0xFFFF6B35), size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Announcement',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Document preview
                        if (imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrl,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, st) => Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Icon(Icons.broken_image,
                                      size: 48, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        if (imageUrl.isNotEmpty) const SizedBox(height: 16),
                        // Full message
                        Text(
                          message,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Meta info
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              if (uploaderName.isNotEmpty)
                                _announcementMetaRow(
                                    Icons.person_outline, 'By', uploaderName),
                              if (fromDate.isNotEmpty || toDate.isNotEmpty)
                                _announcementMetaRow(Icons.date_range, 'Period',
                                    '$fromDate  –  $toDate'),
                              if (date.isNotEmpty)
                                _announcementMetaRow(
                                    Icons.access_time, 'Posted', date),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _announcementMetaRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  // Create a method to build the pie chart
  Widget _buildStatusPieChartWidget() {
    // Random color generator that creates visually pleasing colors
    Color getRandomColor(int index, String status) {
      // Pre-defined seed colors for known status codes to maintain consistency
      final Map<String, Color> seedColors = {
        'PP': const Color(0xFF2196F3), // Blue
        'WO': const Color(0xFF4CAF50), // Green
        'AA': const Color(0xFFFFC107), // Yellow/Amber
      };

      // If we have a seed color for this status, use it
      if (seedColors.containsKey(status)) {
        return seedColors[status]!;
      }

      // Otherwise generate a color based on the index using HSL for better visual appeal
      // This ensures a good spread of colors around the color wheel
      final hue = (index * 137.5) %
          360; // Golden angle approximation for good distribution
      return HSLColor.fromAHSL(
              1.0, // Alpha (opacity)
              hue, // Hue (color)
              0.7, // Saturation (vibrant but not too aggressive)
              0.5 +
                  (index % 2) *
                      0.1 // Lightness (alternating between lighter and darker)
              )
          .toColor();
    }

    // Helper function to convert status code to readable text
    String getStatusLabel(String code) {
      switch (code) {
        case 'PP':
          return 'Present';
        case 'WO':
          return 'Week Off';
        case 'AA':
          return 'Absent';
        case 'HD':
          return 'Half Day';
        case 'HO':
          return 'Holiday';
        case 'LE':
          return 'Leave';
        default:
          return code;
      }
    }

    // Function to refresh the status pie chart
    Future<void> refreshStatusPieChart() async {
      setState(() {
        _isLoadingStatusPieChart = true;
      });

      String? empKey = _findEmployeeKey();
      if (empKey != null) {
        try {
          final baseUrl = await StatusPieChartApi.getBaseApiUrl();
          if (kDebugMode) {}

          // Fetch data properly through the main API method
          _statusPieChartApi.fetchStatusPieChart(empKey);
        } catch (e) {
          if (kDebugMode) {}
          setState(() {
            _statusPieChartError = "Error: $e";
            _isLoadingStatusPieChart = false;
          });
        }
      } else {
        setState(() {
          _statusPieChartError = "Employee key not found";
          _isLoadingStatusPieChart = false;
        });
      }
    }

    // If loading, show a placeholder with activity indicator
    if (_isLoadingStatusPieChart) {
      return Container(
        height: 350,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If there's an error, show the error message with nice UI
    if (_statusPieChartError.isNotEmpty) {
      return Container(
        height: 350,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _statusPieChartError,
              style: TextStyle(
                color: Colors.red[400],
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: refreshStatusPieChart,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Data'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // If there's no data yet, show a message with nice UI
    if (_statusPieChartData == null) {
      return Container(
        height: 350,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No attendance data available',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: refreshStatusPieChart,
              icon: const Icon(Icons.download),
              label: const Text('Load Data'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Prepare the pie chart sections and legend items
    final sections = <PieChartSectionData>[];
    final legendItems = <Widget>[];
    final statusMap = Map<String, dynamic>.from(_statusPieChartData!);
    double total = 0;

    // Calculate total for percentage
    statusMap.forEach((key, value) {
      // Handle both numeric and boolean values
      if (value is num) {
        total += value.toDouble();
      } else if (value is bool) {
        total += value ? 1.0 : 0.0;
      }
    });

    // Create sections and legends with random colors
    int colorIndex = 0;

    // Preferred ordering: present, absent, pa, ap, week off, wop, holiday, then others
    final preferredOrderCodes = ['PP', 'AA', 'PA', 'AP', 'WO', 'WOP', 'HO'];
    final preferredOrderLabels = [
      'present',
      'absent',
      'pa',
      'ap',
      'week off',
      'wop',
      'holiday'
    ];

    // Convert map entries to a list and sort according to preferred order
    final entries = statusMap.entries.toList();

    int orderIndex(String key) {
      final keyUpper = key.toString().toUpperCase();
      // Check by code first
      final codeIdx = preferredOrderCodes.indexOf(keyUpper);
      if (codeIdx >= 0) return codeIdx;

      // Otherwise check by label
      final label = getStatusLabel(key).toLowerCase();
      for (int i = 0; i < preferredOrderLabels.length; i++) {
        final p = preferredOrderLabels[i];
        if (label == p ||
            label.contains(p) ||
            keyUpper.contains(p.toUpperCase())) {
          return i;
        }
      }
      return preferredOrderLabels.length; // others go last
    }

    entries.sort((a, b) => orderIndex(a.key).compareTo(orderIndex(b.key)));

    for (final entry in entries) {
      final key = entry.key;
      final value = entry.value;

      // Generate color and value
      final color = getRandomColor(colorIndex++, key);
      double doubleValue = 0.0;
      if (value is num) {
        doubleValue = value.toDouble();
      } else if (value is bool) {
        doubleValue = value ? 1.0 : 0.0;
      }

      final double percentage = total > 0 ? doubleValue / total * 100 : 0;
      final formattedPercentage = percentage.toStringAsFixed(1);

      sections.add(
        PieChartSectionData(
          color: color,
          value: doubleValue,
          title: '',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          badgeWidget: null,
        ),
      );

      legendItems.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getStatusLabel(key),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$value ($formattedPercentage%)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Return the completed pie chart widget with clean design (simplified)
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: const BoxDecoration(
                color: Color(0xFF506D94),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.pie_chart, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Attendance Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Colors.white, size: 20),
                    onPressed: refreshStatusPieChart,
                    tooltip: 'Refresh Data',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 20,
                  ),
                ],
              ),
            ),
            Container(height: 4, color: Colors.grey[100]),
            // Content
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: PieChart(
                        PieChartData(
                          centerSpaceRadius: 22,
                          sectionsSpace: 2,
                          centerSpaceColor: Colors.white,
                          borderData: FlBorderData(show: false),
                          sections: sections,
                        ),
                        swapAnimationDuration:
                            const Duration(milliseconds: 500),
                        swapAnimationCurve: Curves.easeInOutQuint,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: statusMap.length <= 3
                            ? _buildLegendColumn(legendItems)
                            : SizedBox(
                                height: 120,
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  physics: const ClampingScrollPhysics(),
                                  children: legendItems,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get icon for status
  IconData _getIconForStatus(String status) {
    switch (status) {
      case 'PP':
        return Icons.check_circle;
      case 'WO':
        return Icons.home_work;
      case 'AA':
        return Icons.cancel;
      case 'HD':
        return Icons.horizontal_split;
      case 'HO':
        return Icons.celebration;
      case 'LE':
        return Icons.beach_access;
      default:
        return Icons.circle;
    }
  }

  // Helper method to build legend column
  Widget _buildLegendColumn(List<Widget> items) {
    // This method helps avoid the 'prefer_const_constructors' lint warning
    // We can't use const here because items is a runtime value
    // Wrap the column in a scrollable container so it won't overflow
    // when the available vertical space is constrained.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: items,
      ),
    );
  }

  Widget _buildProjectsTab() {
    // Shortcut action cards in a 2x2 grid for the Applications tab
    final actions = [
      {
        'title': 'Leave Application',
        'icon': Icons.beach_access,
        'color': Colors.blue,
      },
      {
        'title': 'Pending Request',
        'icon': Icons.pending_actions,
        'color': Colors.teal,
      },
      {
        'title': 'Manual Punch',
        'icon': Icons.edit,
        'color': Colors.orange,
      },
      {
        'title': 'Manual Attendance',
        'icon': Icons.history_toggle_off,
        'color': Colors.green,
      },
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final item = actions[index];
        return InkWell(
          onTap: () async {
            final title = item['title'] as String;
            if (title == 'Leave Application') {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        LeaveApplicationScreen(empKey: widget.empKey)),
              );
              return;
            }
            if (title == 'Pending Request') {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        PendingRequestScreen(empKey: widget.empKey)),
              );
              return;
            }
            if (title == 'Manual Punch') {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ManualPunchListScreen(empKey: widget.empKey)),
              );
              return;
            }
            if (title == 'Manual Attendance') {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ManualAttendanceListScreen(empKey: widget.empKey)),
              );
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Open: $title')),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    color: item['color'] as Color,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    item['title'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeamTab() {
    // Views tab: show a 2x2 grid similar to Applications
    final views = [
      {
        'title': 'My Approver',
        'icon': Icons.supervisor_account,
        'color': Colors.blue,
      },
      {
        'title': 'My Leave Balance',
        'icon': Icons.account_balance_wallet,
        'color': Colors.teal,
      },
      {
        'title': 'My Team',
        'icon': Icons.group,
        'color': Colors.green,
      },
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: views.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final item = views[index];
        return InkWell(
          onTap: () {
            final title = item['title'] as String;
            if (title == 'My Approver') {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ApproverScreen(empKey: widget.empKey)),
              );
              return;
            }
            if (title == 'My Leave Balance') {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        MyLeaveBalanceScreen(empKey: widget.empKey)),
              );
              return;
            }
            if (title == 'My Team') {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => TeamScreen(empKey: widget.empKey)),
              );
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Open: $title')),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    color: item['color'] as Color,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    item['title'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final activities = [
          {
            'title': 'Checked in',
            'time': '08:30 AM',
            'icon': Icons.login,
            'color': Colors.green,
            'description': 'Started workday',
          },
          {
            'title': 'Meeting with Design Team',
            'time': '10:00 AM',
            'icon': Icons.people,
            'color': Colors.blue,
            'description': 'Discussed new UI components',
          },
          {
            'title': 'Completed task: Homepage UI',
            'time': '11:45 AM',
            'icon': Icons.task_alt,
            'color': Colors.orange,
            'description': 'Finished all required components',
          },
          {
            'title': 'Lunch break',
            'time': '01:00 PM',
            'icon': Icons.restaurant,
            'color': Colors.amber,
            'description': '45 minutes break',
          },
          {
            'title': 'Code review',
            'time': '02:30 PM',
            'icon': Icons.code,
            'color': Colors.purple,
            'description': 'Reviewed PR #42',
          },
          {
            'title': 'Project planning',
            'time': '04:15 PM',
            'icon': Icons.calendar_today,
            'color': Colors.teal,
            'description': 'Next sprint planning',
          },
        ];

        if (index >= activities.length) return null;

        final activity = activities[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (activity['color'] as Color).withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  activity['icon'] as IconData,
                  color: activity['color'] as Color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          activity['title'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          activity['time'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activity['description'] as String,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
