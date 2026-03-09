import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:easytime_online/api/monthly_work_hours_api.dart';
import 'package:easytime_online/api/today_punches_api.dart';
import 'package:easytime_online/ui/monthly_work_hours_detail_screen.dart';
import 'package:easytime_online/ui/approver_screen.dart';
import 'package:easytime_online/ui/team_screen.dart';
import 'package:easytime_online/ui/my_leave_balance_screen.dart';
import 'package:easytime_online/ui/leave_application_screen.dart';
import 'package:easytime_online/ui/pending_request_screen.dart';
import 'package:easytime_online/api/status_pie_chart_api.dart';
import 'package:easytime_online/ui/attendance_history_screen.dart';
import 'package:easytime_online/api/attendance_history_api.dart';
import 'package:easytime_online/data_sync_service.dart';
import 'package:easytime_online/data_storage_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easytime_online/main/main.dart';

class DashboardScreen extends StatefulWidget {
  final String? userName;
  final Map<String, dynamic>? userData;
  final String empKey;

  const DashboardScreen(
      {super.key, this.userName, this.userData, required this.empKey});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _mainScrollController = ScrollController();
  late TabController _tabController;
  int _currentIndex = 0;

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

    // Debug print userData with more detailed logging
    if (kDebugMode) {
      print("Dashboard initialized with userData: ${widget.userData}");
    }

    try {
      // Try to log full userData structure for debugging
      if (widget.userData != null) {
        if (kDebugMode) {
          print("Full userData structure: ${json.encode(widget.userData)}");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error encoding userData: $e");
      }
    }

    // Start background service for work hours
    _setupWorkHoursServices();

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
    } catch (e) {
      if (kDebugMode) print('Error loading stat order: $e');
    }
  }

  Future<void> _saveStatOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('dashboard_stat_order', _statOrder);
    } catch (e) {
      if (kDebugMode) print('Error saving stat order: $e');
    }
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
      if (kDebugMode) {
        print("Prefetching attendance history data in background");
      }

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
              if (kDebugMode) {
                print(
                    "Processing monthly work hours value: $workHoursValue (${workHoursValue.runtimeType})");
              }

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
                    if (kDebugMode) {
                      print(
                          "Using original time format from API: $_monthlyWorkHours");
                    }
                  } catch (e) {
                    if (kDebugMode) {
                      print("Error parsing time format: $e");
                    }
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

              if (kDebugMode) {
                print("Updated monthly work hours: $_monthlyWorkHours");
              }
            } else {
              _monthlyWorkHoursError =
                  result['message'] ?? "Failed to load monthly work hours";
              if (kDebugMode) {
                print("Monthly work hours error: $_monthlyWorkHoursError");
              }
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
              if (kDebugMode) {
                print('Updated today punches: IN=$_inPunch OUT=$_outPunch');
              }
            } else {
              _todayPunchesError =
                  result['message'] ?? 'Failed to load today punches';
              if (kDebugMode) {
                print('Today punches error: $_todayPunchesError');
              }
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
      } catch (e) {
        if (kDebugMode) print('Error calling fetchAndLog: $e');
      }

      // Subscribe to status pie chart data updates
      setState(() {
        _isLoadingStatusPieChart = true;
      });

      // Validate employee key one more time specifically for pie chart
      if (empKey.trim().isEmpty && !kDebugMode) {
        if (kDebugMode) {
          print(
              "WARNING: Empty employee key for status pie chart after trimming");
        }
        setState(() {
          _isLoadingStatusPieChart = false;
          _statusPieChartError = "Employee key is empty";
        });
      } else {
        if (kDebugMode) {
          print("\n==== STATUS PIE CHART SETUP ====");
          print("Setting up status pie chart with empKey: '$empKey'");
          print("Employee key type: ${empKey.runtimeType}");
          print("Employee key length: ${empKey.length}");
          print(
              "Employee key codeUnits: ${empKey.codeUnits}"); // Check for invisible characters
        }

        // Make sure empKey is a valid string for API call
        final validEmpKey = empKey.trim();
        if (kDebugMode) {
          print("Using validEmpKey for status pie chart: '$validEmpKey'");
        }

        // Set up the stream subscription first
        _statusPieChartSubscription =
            _statusPieChartApi.statusDataStream.listen((result) {
          if (kDebugMode) {
            print(
                "Received status pie chart data update: ${result['success']}");
          }
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
                if (kDebugMode && shouldUpdate) {
                  print("Updated status pie chart data: $_statusPieChartData");
                }
              } else {
                // Only update error if we don't already have data
                if (_statusPieChartData == null) {
                  _statusPieChartError =
                      result['message'] ?? "Failed to load status data";
                  if (kDebugMode) {
                    print("Status pie chart error: $_statusPieChartError");
                  }
                }
              }
            });
          }
        });

        // Start periodic updates for status pie chart
        try {
          // Make an immediate direct call to fetch data
          if (kDebugMode) {
            print("Making immediate call to fetch status pie chart data");
          }
          _statusPieChartApi.fetchStatusPieChart(validEmpKey);

          // Then set up periodic updates
          _statusPieChartApi.startPeriodicUpdates(validEmpKey,
              interval: const Duration(minutes: 15));
          if (kDebugMode) {
            print(
                "Started periodic updates for status pie chart with validEmpKey: '$validEmpKey'");
            print("==== STATUS PIE CHART SETUP COMPLETE ====\n");
          }
        } catch (e) {
          if (kDebugMode) {
            print("Error starting periodic updates for status pie chart: $e");
          }
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

      if (kDebugMode) {
        print("Failed to start API services: Employee key is null or empty");
      }
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
    if (widget.userData == null) {
      if (kDebugMode) {
        print("userData is null");
      }
      return null;
    }

    try {
      if (kDebugMode) {
        print(
            "Detailed userData content for debugging: ${json.encode(widget.userData)}");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error encoding userData: $e");
      }
    }

    // Fallback to hardcoded empKey for development/testing
    const String fallbackEmpKey = "1234"; // Default test emp_key
    String? foundEmpKey;

    // Check for emp_key in different possible locations in userData
    if (widget.userData!.containsKey('emp_key')) {
      if (kDebugMode) {
        print("Found emp_key directly: ${widget.userData!['emp_key']}");
      }
      foundEmpKey = widget.userData!['emp_key']?.toString();
    }

    // Check user_data path
    if (foundEmpKey == null && widget.userData!.containsKey('user_data')) {
      var userData = widget.userData!['user_data'];
      if (userData is Map) {
        if (userData.containsKey('emp_key')) {
          if (kDebugMode) {
            print("Found emp_key in user_data: ${userData['emp_key']}");
          }
          foundEmpKey = userData['emp_key']?.toString();
        } else {
          if (kDebugMode) {
            print("user_data exists but doesn't contain emp_key: $userData");
          }
        }
      } else {
        if (kDebugMode) {
          print("user_data exists but is not a Map: $userData");
        }
      }
    }

    // Check response_data.user_data path
    if (foundEmpKey == null && widget.userData!.containsKey('response_data')) {
      var responseData = widget.userData!['response_data'];
      if (responseData is Map && responseData.containsKey('user_data')) {
        var userData = responseData['user_data'];
        if (userData is Map && userData.containsKey('emp_key')) {
          if (kDebugMode) {
            print(
                "Found emp_key in response_data.user_data: ${userData['emp_key']}");
          }
          foundEmpKey = userData['emp_key']?.toString();
        } else {
          if (kDebugMode) {
            print(
                "response_data.user_data exists but doesn't contain emp_key: $userData");
          }
        }
      } else {
        if (kDebugMode) {
          print(
              "response_data exists but doesn't contain user_data or is not a Map: $responseData");
        }
      }
    }

    // Check user path
    if (foundEmpKey == null && widget.userData!.containsKey('user')) {
      var user = widget.userData!['user'];
      if (user is Map && user.containsKey('emp_key')) {
        if (kDebugMode) {
          print("Found emp_key in user: ${user['emp_key']}");
        }
        foundEmpKey = user['emp_key']?.toString();
      } else {
        if (kDebugMode) {
          print("user exists but doesn't contain emp_key: $user");
        }
      }
    }

    // Check data path
    if (foundEmpKey == null && widget.userData!.containsKey('data')) {
      var data = widget.userData!['data'];
      if (data is Map) {
        if (data.containsKey('emp_key')) {
          if (kDebugMode) {
            print("Found emp_key in data: ${data['emp_key']}");
          }
          foundEmpKey = data['emp_key']?.toString();
        } else if (data.containsKey('user')) {
          var user = data['user'];
          if (user is Map && user.containsKey('emp_key')) {
            if (kDebugMode) {
              print("Found emp_key in data.user: ${user['emp_key']}");
            }
            foundEmpKey = user['emp_key']?.toString();
          } else {
            if (kDebugMode) {
              print("data.user exists but doesn't contain emp_key: $user");
            }
          }
        } else {
          if (kDebugMode) {
            print("data exists but doesn't contain emp_key or user: $data");
          }
        }
      } else {
        if (kDebugMode) {
          print("data exists but is not a Map: $data");
        }
      }
    }

    // Check raw_response path
    if (foundEmpKey == null && widget.userData!.containsKey('raw_response')) {
      var rawResponse = widget.userData!['raw_response'];
      if (rawResponse is Map) {
        var empKey = _findEmpKeyInMap(rawResponse);
        if (empKey != null) {
          if (kDebugMode) {
            print("Found emp_key in raw_response: $empKey");
          }
          foundEmpKey = empKey;
        } else {
          if (kDebugMode) {
            print(
                "raw_response exists but emp_key not found in it: $rawResponse");
          }
        }
      } else {
        if (kDebugMode) {
          print("raw_response exists but is not a Map: $rawResponse");
        }
      }
    }

    // If we've exhausted all known paths, try a deep search in the entire userData object
    if (foundEmpKey == null) {
      if (kDebugMode) {
        print("Trying deep search in userData for emp_key...");
      }
      foundEmpKey = _findEmpKeyDeep(widget.userData!);
      if (foundEmpKey != null && foundEmpKey.isNotEmpty) {
        if (kDebugMode) {
          print("Found emp_key via deep search: $foundEmpKey");
        }
      }
    }

    // Validate the found empKey before returning
    if (foundEmpKey != null) {
      // Trim any whitespace
      foundEmpKey = foundEmpKey.trim();

      // Print more details about the found key
      if (kDebugMode) {
        print(
            "Found empKey after trim: '$foundEmpKey', length: ${foundEmpKey.length}");
      }

      // Only return if it's not empty after trimming
      if (foundEmpKey.isNotEmpty) {
        return foundEmpKey;
      } else {
        if (kDebugMode) {
          print(
              "Found empKey is empty after trimming, will use fallback if in debug mode");
        }
      }
    }

    // Always use fallback in debug mode, otherwise return null
    if (kDebugMode) {
      print("DEVELOPMENT MODE: Using fallback emp_key: $fallbackEmpKey");
      return fallbackEmpKey;
    }

    if (kDebugMode) {
      print("Missing emp_key in userData: ${widget.userData}");
    }
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

  @override
  void dispose() {
    // Cancel work hours subscriptions
    _monthlyWorkHoursSubscription?.cancel();
    _todayPunchesSubscription?.cancel();
    _statusPieChartSubscription?.cancel();

    // Stop periodic updates
    _monthlyWorkHoursApi.stopPeriodicUpdates();
    _todayPunchesApi.stopPeriodicUpdates();
    _statusPieChartApi.dispose();

    _mainScrollController.dispose();
    _tabController.dispose();
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double _scaleFactor =
        (MediaQuery.of(context).size.width / 360).clamp(0.75, 1.0) as double;
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
                      'Welcome back, ${widget.userName ?? 'User'}',
                      style: TextStyle(
                        fontSize: 20 * _scaleFactor,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
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
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                      fontSize: 16 * _scaleFactor,
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
                        scale: _scaleFactor,
                      ),
                      _buildQuickActionButton(
                        icon: Icons.logout,
                        label: 'Check Out',
                        color: Colors.red,
                        scale: _scaleFactor,
                      ),
                      _buildQuickActionButton(
                        icon: Icons.access_time,
                        label: 'Time Card',
                        color: Colors.blue,
                        scale: _scaleFactor,
                      ),
                      _buildQuickActionButton(
                        icon: Icons.bar_chart,
                        label: 'Reports',
                        color: Colors.purple,
                        scale: _scaleFactor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
          labelTextStyle: MaterialStatePropertyAll(
            TextStyle(fontSize: 12 * _scaleFactor),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
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
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
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
            NavigationDestination(
              icon: Icon(Icons.task_outlined),
              selectedIcon: Icon(Icons.task),
              label: 'Tasks',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
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
                              .clamp(0.75, 1.0) as double,
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
                                        .clamp(0.75, 1.0) as double,
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
                                        .clamp(0.75, 1.0) as double,
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
                                    .clamp(0.75, 1.0) as double,
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
                              .clamp(0.75, 1.0) as double,
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
        onWillAccept: (data) => data != null && data != id,
        onAccept: (sourceId) {
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
                Positioned(
                  top: 8,
                  right: 8,
                  child:
                      const Icon(Icons.drag_indicator, color: Colors.white70),
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
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12 * scale, color: const Color(0xFF555555)),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
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
          if (kDebugMode) {
            print(
                "Refreshing status pie chart with URL: $baseUrl, empKey: $empKey");
          }

          // Fetch data properly through the main API method
          _statusPieChartApi.fetchStatusPieChart(empKey);
        } catch (e) {
          if (kDebugMode) {
            print("Error refreshing status pie chart: $e");
          }
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
    statusMap.forEach((key, value) {
      // Generate random color based on index and status code
      final color = getRandomColor(colorIndex++, key);

      // Convert value to double based on its type
      double doubleValue = 0.0;
      if (value is num) {
        doubleValue = value.toDouble();
      } else if (value is bool) {
        doubleValue = value ? 1.0 : 0.0;
      }

      final double percentage = total > 0 ? doubleValue / total * 100 : 0;
      final formattedPercentage = percentage.toStringAsFixed(1);

      // Create pie section; do NOT render percentage text inside the slice.
      // Percentages will be shown in the legend to avoid overlap on small screens.
      sections.add(
        PieChartSectionData(
          color: color,
          value: doubleValue,
          title: '', // hide title inside slice to prevent overlap
          radius: 70,
          titleStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          badgeWidget: null,
        ),
      );

      // Create legend item with dot and stacked label/value to avoid horizontal overflow
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
                      '$value (${formattedPercentage}%)',
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
    });

    // Return the completed pie chart widget with clean design (simplified)
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
        mainAxisSize: MainAxisSize.min,
        children: [
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
                Expanded(
                  child: Row(
                    children: const [
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
                  icon:
                      const Icon(Icons.refresh, color: Colors.white, size: 20),
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
            child: Column(
              children: [
                const SizedBox(height: 5),
                SizedBox(
                  height: 175,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1.3,
                      child: PieChart(
                        PieChartData(
                          centerSpaceRadius: 30,
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
                  ),
                ),
                Container(
                  height: 90,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
                  child: statusMap.length <= 3
                      ? _buildLegendColumn(legendItems)
                      : ListView(
                          padding: EdgeInsets.zero,
                          physics: const ClampingScrollPhysics(),
                          children: legendItems,
                        ),
                ),
              ],
            ),
          ),
        ],
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
      {
        'title': 'Requests',
        'icon': Icons.list_alt,
        'color': Colors.purple,
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
          onTap: () {
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
      {
        'title': 'Activity',
        'icon': Icons.timeline,
        'color': Colors.orange,
      },
      {
        'title': 'Notifications',
        'icon': Icons.notifications,
        'color': Colors.purple,
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
