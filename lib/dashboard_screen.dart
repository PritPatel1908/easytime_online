import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:easytime_online/monthly_work_hours_api.dart';
import 'package:easytime_online/weekly_work_hours_api.dart';
import 'package:easytime_online/monthly_work_hours_detail_screen.dart';
import 'package:easytime_online/status_pie_chart_api.dart';
import 'package:easytime_online/attendance_history_screen.dart';
import 'package:easytime_online/attendance_history_api.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'dart:convert';
import 'main.dart';

class DashboardScreen extends StatefulWidget {
  final String? userName;
  final Map<String, dynamic>? userData;

  const DashboardScreen({super.key, this.userName, this.userData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final ScrollController _mainScrollController = ScrollController();
  late TabController _tabController;

  // Add state variables for work hours
  String _monthlyWorkHours = "0.0";
  bool _isLoadingMonthlyWorkHours = false;
  String _monthlyWorkHoursError = "";

  // Add state variables for weekly work hours
  String _weeklyWorkHours = "0.0";
  bool _isLoadingWeeklyWorkHours = false;
  String _weeklyWorkHoursError = "";

  // Work hours API services
  final MonthlyWorkHoursApi _monthlyWorkHoursApi = MonthlyWorkHoursApi();
  final WeeklyWorkHoursApi _weeklyWorkHoursApi = WeeklyWorkHoursApi();
  final StatusPieChartApi _statusPieChartApi = StatusPieChartApi();
  final AttendanceHistoryApi _attendanceHistoryApi = AttendanceHistoryApi();
  StreamSubscription? _monthlyWorkHoursSubscription;
  StreamSubscription? _weeklyWorkHoursSubscription;
  StreamSubscription? _statusPieChartSubscription;

  // Status Pie Chart Data
  Map<String, dynamic>? _statusPieChartData;
  bool _isLoadingStatusPieChart = false;
  String _statusPieChartError = "";

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

    _tabController = TabController(length: 3, vsync: this);

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

    // Prefetch attendance history data in background
    _prefetchAttendanceHistory();
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
    // Find employee key from userData
    String? empKey = _findEmployeeKey();

    if (empKey != null) {
      // Set loading state
      setState(() {
        _isLoadingMonthlyWorkHours = true;
        _isLoadingWeeklyWorkHours = true;
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

      // Subscribe to weekly work hours updates
      _weeklyWorkHoursSubscription =
          _weeklyWorkHoursApi.workHoursStream.listen((result) {
        if (mounted) {
          setState(() {
            _isLoadingWeeklyWorkHours = false;

            if (result['success'] == true && result.containsKey('work_hours')) {
              // Format work hours to display
              var workHoursValue = result['work_hours'];
              if (kDebugMode) {
                print(
                    "Processing weekly work hours value: $workHoursValue (${workHoursValue.runtimeType})");
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
                    _weeklyWorkHours = workHoursValue;
                    if (kDebugMode) {
                      print(
                          "Using original time format from API: $_weeklyWorkHours");
                    }
                  } catch (e) {
                    if (kDebugMode) {
                      print("Error parsing time format: $e");
                    }
                    _weeklyWorkHours =
                        workHoursValue; // Just use the original string
                  }
                } else {
                  _weeklyWorkHours =
                      workHoursValue; // Just use the original string
                }
              } else {
                // Just use the original value without any formatting
                _weeklyWorkHours = workHoursValue.toString();
              }

              if (kDebugMode) {
                print("Updated weekly work hours: $_weeklyWorkHours");
              }
            } else {
              _weeklyWorkHoursError =
                  result['message'] ?? "Failed to load weekly work hours";
              if (kDebugMode) {
                print("Weekly work hours error: $_weeklyWorkHoursError");
              }
            }
          });
        }
      });

      // Start periodic updates (every 5 minutes)
      _monthlyWorkHoursApi.startPeriodicUpdates(empKey,
          interval: const Duration(minutes: 5));

      _weeklyWorkHoursApi.startPeriodicUpdates(empKey,
          interval: const Duration(minutes: 5));

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

              if (result['success'] == true &&
                  result.containsKey('status_data')) {
                _statusPieChartData = result['status_data'];
                _statusPieChartError = "";
                if (kDebugMode) {
                  print("Updated status pie chart data: $_statusPieChartData");
                }
              } else {
                _statusPieChartError =
                    result['message'] ?? "Failed to load status data";
                if (kDebugMode) {
                  print("Status pie chart error: $_statusPieChartError");
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
        _weeklyWorkHoursError = "Employee key not found";
        _statusPieChartError = "Employee key not found";
      });

      if (kDebugMode) {
        print("Failed to start API services: Employee key is null or empty");
      }
    }
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
    _weeklyWorkHoursSubscription?.cancel();
    _statusPieChartSubscription?.cancel();

    // Stop periodic updates
    _monthlyWorkHoursApi.stopPeriodicUpdates();
    _weeklyWorkHoursApi.stopPeriodicUpdates();
    _statusPieChartApi.dispose();

    _mainScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        controller: _mainScrollController,
        physics: const ClampingScrollPhysics(),
        slivers: [
          // Modern App Bar with profile
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Padding(
                padding: const EdgeInsets.only(right: 60),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'EasyTime',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      ' Online',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor.withAlpha(179),
                        fontWeight: FontWeight.w400,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              background: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Welcome back, ${widget.userName ?? 'User'}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
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
          ),

          // Stats Cards
          SliverToBoxAdapter(
            child: Container(
              height: 100,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  _buildStatCard(
                    title: 'Monthly',
                    value:
                        _isLoadingMonthlyWorkHours ? "..." : _monthlyWorkHours,
                    subtitle: _monthlyWorkHoursError.isNotEmpty
                        ? _monthlyWorkHoursError
                        : 'This month',
                    color: Colors.blue,
                    icon: Icons.calendar_month,
                    flex: 1,
                    isWorkHours: true,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    title: 'Weekly',
                    value: _isLoadingWeeklyWorkHours ? "..." : _weeklyWorkHours,
                    subtitle: _weeklyWorkHoursError.isNotEmpty
                        ? _weeklyWorkHoursError
                        : 'This week',
                    color: Colors.green,
                    icon: Icons.access_time,
                    flex: 1,
                    isWorkHours: true,
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
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
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
                      ),
                      _buildQuickActionButton(
                        icon: Icons.logout,
                        label: 'Check Out',
                        color: Colors.red,
                      ),
                      _buildQuickActionButton(
                        icon: Icons.event_note,
                        label: 'Tasks',
                        color: Colors.blue,
                      ),
                      _buildQuickActionButton(
                        icon: Icons.bar_chart,
                        label: 'Reports',
                        color: Colors.purple,
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
                  Tab(text: 'Projects'),
                  Tab(text: 'Team'),
                  Tab(text: 'Activity'),
                ],
              ),
            ),
          ),

          // Tab Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Projects Tab
                _buildProjectsTab(),

                // Team Tab
                _buildTeamTab(),

                // Activity Tab
                _buildActivityTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
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
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () {
          // Handle tap based on card type
          if (title == 'Monthly') {
            _navigateToMonthlyWorkHoursDetail();
          } else if (title == 'Weekly') {
            // Future implementation for weekly details
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withAlpha(204),
                        fontSize: 10,
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
  }) {
    return Column(
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
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
        ),
      ],
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
          return 'Work Off';
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

          // Direct API call for testing
          await _statusPieChartApi.callApiDirectly(empKey, baseUrl);
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
      total += (value as num).toDouble();
    });

    // Create sections and legends with random colors
    int colorIndex = 0;
    statusMap.forEach((key, value) {
      // Generate random color based on index and status code
      final color = getRandomColor(colorIndex++, key);

      final double percentage =
          total > 0 ? (value as num).toDouble() / total * 100 : 0;
      final formattedPercentage = percentage.toStringAsFixed(1);

      // Create pie section with large percentage text
      sections.add(
        PieChartSectionData(
          color: color,
          value: (value as num).toDouble(),
          title: '${percentage.round()}%',
          radius: 70, // Matches the new radius in the chart
          titleStyle: const TextStyle(
            fontSize: 16, // Matches the new font size in the chart
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          badgeWidget: Icon(
            _getIconForStatus(key),
            size: 14, // Even smaller icon
            color: Colors.white,
          ),
          badgePositionPercentageOffset: 0.8, // Move badge closer to center
        ),
      );

      // Create legend item with dot, label and value
      legendItems.add(
        Container(
          margin: const EdgeInsets.only(bottom: 4), // Further reduced margin
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  getStatusLabel(key),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  '$value ($formattedPercentage%)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    });

    // Return the completed pie chart widget with clean design
    return Container(
      height: 385, // Slightly increased to accommodate the added spacing
      margin: const EdgeInsets.fromLTRB(
          16, 0, 16, 10), // Reduced bottom margin from 16 to 10
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
        mainAxisSize: MainAxisSize.max,
        children: [
          // Title bar with gradient - fixed height
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF506D94), // Navy blue like in screenshot
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pie_chart, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Attendance Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
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

          // Add a divider to clearly separate header from content
          Container(
            height: 4,
            color: Colors.grey[100],
          ),

          // Content container with clear bounds
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(top: 10), // Reduced from 12 to 10
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  // Add extra spacing after header - reduced from 8 to 5
                  const SizedBox(height: 5),

                  // Pie chart area with fixed height to prevent overlap
                  SizedBox(
                    height: 175, // Increased from 165 to 175
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1.3,
                        child: PieChart(
                          PieChartData(
                            centerSpaceRadius: 30,
                            sectionsSpace: 2,
                            centerSpaceColor: Colors.white,
                            borderData: FlBorderData(show: false),
                            sections: sections
                                .map((section) => section.copyWith(
                                      radius: 70, // Even smaller radius
                                      titleStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ))
                                .toList(),
                          ),
                          swapAnimationDuration:
                              const Duration(milliseconds: 500),
                          swapAnimationCurve: Curves.easeInOutQuint,
                        ),
                      ),
                    ),
                  ),

                  // Legend with compact layout - reduced from 100 to 90
                  Container(
                    height: 90, // Smaller fixed height for legend
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: items,
    );
  }

  Widget _buildProjectsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final projects = [
          {
            'name': 'Website Redesign',
            'progress': 0.7,
            'color': Colors.blue,
            'deadline': 'Oct 15',
            'members': 4,
          },
          {
            'name': 'Mobile App Development',
            'progress': 0.4,
            'color': Colors.orange,
            'deadline': 'Nov 20',
            'members': 6,
          },
          {
            'name': 'Database Migration',
            'progress': 0.9,
            'color': Colors.green,
            'deadline': 'Oct 5',
            'members': 3,
          },
          {
            'name': 'API Integration',
            'progress': 0.3,
            'color': Colors.purple,
            'deadline': 'Dec 10',
            'members': 5,
          },
          {
            'name': 'UI Testing',
            'progress': 0.6,
            'color': Colors.teal,
            'deadline': 'Oct 30',
            'members': 2,
          },
        ];

        if (index >= projects.length) return null;

        final project = projects[index];

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (project['color'] as Color).withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.folder,
                      color: project['color'] as Color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      project['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Due ${project['deadline']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: project['progress'] as double,
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: project['color'] as Color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${((project['progress'] as double) * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: project['color'] as Color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${project['members']} members',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(60, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTeamTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final members = [
          {
            'name': 'John Smith',
            'avatar': 'J',
            'role': 'Project Manager',
            'color': Colors.blue,
            'status': 'Online',
          },
          {
            'name': 'Sarah Johnson',
            'avatar': 'S',
            'role': 'UI Designer',
            'color': Colors.green,
            'status': 'In a meeting',
          },
          {
            'name': 'Michael Brown',
            'avatar': 'M',
            'role': 'Developer',
            'color': Colors.orange,
            'status': 'Online',
          },
          {
            'name': 'Lisa Davis',
            'avatar': 'L',
            'role': 'QA Tester',
            'color': Colors.purple,
            'status': 'Away',
          },
          {
            'name': 'David Wilson',
            'avatar': 'D',
            'role': 'Backend Dev',
            'color': Colors.red,
            'status': 'Offline',
          },
          {
            'name': 'Emma Taylor',
            'avatar': 'E',
            'role': 'UX Researcher',
            'color': Colors.teal,
            'status': 'Online',
          },
        ];

        if (index >= members.length) return null;

        final member = members[index];
        final bool isOnline = member['status'] == 'Online';

        return Container(
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: (member['color'] as Color).withAlpha(51),
                    child: Text(
                      member['avatar'] as String,
                      style: TextStyle(
                        color: member['color'] as Color,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                member['name'] as String,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                member['role'] as String,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline
                      ? Colors.green.withAlpha(26)
                      : Colors.grey.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  member['status'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    color: isOnline ? Colors.green : Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
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
