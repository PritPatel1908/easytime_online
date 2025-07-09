import 'package:flutter/material.dart';
import 'package:easytime_online/monthly_work_hours_api.dart';
import 'package:easytime_online/weekly_work_hours_api.dart';
import 'dart:async';

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
  StreamSubscription? _monthlyWorkHoursSubscription;
  StreamSubscription? _weeklyWorkHoursSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Debug print userData
    print("Dashboard initialized with userData: ${widget.userData}");

    // Start background service for work hours
    _setupWorkHoursServices();
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
              print(
                  "Processing monthly work hours value: $workHoursValue (${workHoursValue.runtimeType})");

              // Check if it's in HH:MM format
              if (workHoursValue is String && workHoursValue.contains(':')) {
                // It's in time format (HH:MM)
                List<String> parts = workHoursValue.split(':');
                if (parts.length == 2) {
                  try {
                    int hours = int.parse(parts[0]);
                    int minutes = int.parse(parts[1]);
                    // Use the original value from API without any calculations
                    _monthlyWorkHours = workHoursValue;
                    print(
                        "Using original time format from API: $_monthlyWorkHours");
                  } catch (e) {
                    print("Error parsing time format: $e");
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

              print("Updated monthly work hours: $_monthlyWorkHours");
            } else {
              _monthlyWorkHoursError =
                  result['message'] ?? "Failed to load monthly work hours";
              print("Monthly work hours error: $_monthlyWorkHoursError");
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
              print(
                  "Processing weekly work hours value: $workHoursValue (${workHoursValue.runtimeType})");

              // Check if it's in HH:MM format
              if (workHoursValue is String && workHoursValue.contains(':')) {
                // It's in time format (HH:MM)
                List<String> parts = workHoursValue.split(':');
                if (parts.length == 2) {
                  try {
                    int hours = int.parse(parts[0]);
                    int minutes = int.parse(parts[1]);
                    // Use the original value from API without any calculations
                    _weeklyWorkHours = workHoursValue;
                    print(
                        "Using original time format from API: $_weeklyWorkHours");
                  } catch (e) {
                    print("Error parsing time format: $e");
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

              print("Updated weekly work hours: $_weeklyWorkHours");
            } else {
              _weeklyWorkHoursError =
                  result['message'] ?? "Failed to load weekly work hours";
              print("Weekly work hours error: $_weeklyWorkHoursError");
            }
          });
        }
      });

      // Start periodic updates (every 5 minutes)
      _monthlyWorkHoursApi.startPeriodicUpdates(empKey,
          interval: const Duration(minutes: 5));

      _weeklyWorkHoursApi.startPeriodicUpdates(empKey,
          interval: const Duration(minutes: 5));
    } else {
      setState(() {
        _monthlyWorkHoursError = "Employee key not found";
        _weeklyWorkHoursError = "Employee key not found";
      });
    }
  }

  // Helper method to find employee key in userData
  String? _findEmployeeKey() {
    if (widget.userData == null) {
      print("userData is null");
      return null;
    }

    // Check for emp_key in different possible locations in userData
    if (widget.userData!.containsKey('emp_key')) {
      return widget.userData!['emp_key'].toString();
    } else if (widget.userData!.containsKey('user_data') &&
        widget.userData!['user_data'] is Map &&
        (widget.userData!['user_data'] as Map).containsKey('emp_key')) {
      return widget.userData!['user_data']['emp_key'].toString();
    } else if (widget.userData!.containsKey('response_data') &&
        widget.userData!['response_data'] is Map &&
        widget.userData!['response_data'].containsKey('user_data') &&
        widget.userData!['response_data']['user_data'] is Map &&
        widget.userData!['response_data']['user_data'].containsKey('emp_key')) {
      return widget.userData!['response_data']['user_data']['emp_key']
          .toString();
    }

    print("Missing emp_key in userData: ${widget.userData}");
    return null;
  }

  @override
  void dispose() {
    // Cancel work hours subscriptions
    _monthlyWorkHoursSubscription?.cancel();
    _weeklyWorkHoursSubscription?.cancel();

    // Stop periodic updates
    _monthlyWorkHoursApi.stopPeriodicUpdates();
    _weeklyWorkHoursApi.stopPeriodicUpdates();

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
          setState(() {
            _currentIndex = index;
          });
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
    );
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
