import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easytime_online/monthly_work_hours_detail_api.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';
import 'main.dart';

class MonthlyWorkHoursDetailScreen extends StatefulWidget {
  final String empKey;
  final String totalWorkHours;

  const MonthlyWorkHoursDetailScreen({
    super.key,
    required this.empKey,
    required this.totalWorkHours,
  });

  @override
  State<MonthlyWorkHoursDetailScreen> createState() =>
      _MonthlyWorkHoursDetailScreenState();
}

class _MonthlyWorkHoursDetailScreenState
    extends State<MonthlyWorkHoursDetailScreen> with WidgetsBindingObserver {
  final MonthlyWorkHoursDetailApi _api = MonthlyWorkHoursDetailApi();
  StreamSubscription? _subscription;

  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _dailyData = [];
  String _totalWorkHours = '';

  // Track selected day for highlighting
  int? _selectedIndex;

  // Scroll controller for list
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Ensure system UI settings are maintained
    SystemUIUtil.hideSystemNavigationBar();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));

    _totalWorkHours = widget.totalWorkHours;

    // Register observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Setup data
    _setupData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Clear cache when app is terminated or in background for long time
    if (state == AppLifecycleState.detached) {
      MonthlyWorkHoursDetailApi.clearCache();
    }
  }

  void _setupData() {
    // Check for cached data first
    final cachedData = MonthlyWorkHoursDetailApi.getCachedData(widget.empKey);

    if (cachedData != null && cachedData['success'] == true) {
      // Use cached data immediately
      setState(() {
        _isLoading = false;
        if (cachedData.containsKey('daily_data') &&
            cachedData['daily_data'] != null) {
          _dailyData =
              List<Map<String, dynamic>>.from(cachedData['daily_data']);

          // Find today's date in the list and scroll to it
          _scrollToCurrentDate();
        }

        if (cachedData.containsKey('total_work_hours') &&
            cachedData['total_work_hours'] != null) {
          _totalWorkHours = cachedData['total_work_hours'].toString();
        }
      });
    }

    // Setup API subscription for fresh data
    _setupApiSubscription();
  }

  void _setupApiSubscription() {
    _subscription = _api.workHoursDetailStream.listen((result) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result['success'] == true) {
            if (result.containsKey('daily_data') &&
                result['daily_data'] != null) {
              // Check if data is different before updating
              final newDailyData =
                  List<Map<String, dynamic>>.from(result['daily_data']);
              if (_dailyData.isEmpty ||
                  _hasDataChanged(_dailyData, newDailyData)) {
                _dailyData = newDailyData;
                // Find today's date in the list and scroll to it
                _scrollToCurrentDate();
              }
            } else {
              _errorMessage = 'No daily data available';
            }

            if (result.containsKey('total_work_hours') &&
                result['total_work_hours'] != null) {
              final newTotalHours = result['total_work_hours'].toString();
              if (_totalWorkHours != newTotalHours) {
                _totalWorkHours = newTotalHours;
              }
            }
          } else {
            _errorMessage = result['message'] ?? 'Failed to load data';
          }
        });
      }
    });

    // Start fetching data - use cache if available
    _api.fetchMonthlyWorkHoursDetail(widget.empKey);
  }

  // Helper method to check if data has changed
  bool _hasDataChanged(
      List<Map<String, dynamic>> oldData, List<Map<String, dynamic>> newData) {
    if (oldData.length != newData.length) return true;

    for (int i = 0; i < oldData.length; i++) {
      if (oldData[i]['date'] != newData[i]['date'] ||
          oldData[i]['work_hours'] != newData[i]['work_hours']) {
        return true;
      }
    }

    return false;
  }

  void _scrollToCurrentDate() {
    if (_dailyData.isEmpty) return;

    final today = DateTime.now();
    final formattedToday = DateFormat('yyyy-MM-dd').format(today);

    for (int i = 0; i < _dailyData.length; i++) {
      final date = _dailyData[i]['date'];
      if (date == formattedToday) {
        // Wait for the list to build, then scroll to today
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            final itemHeight = 72.0; // Approximate height of each list item
            _scrollController.animateTo(
              i * itemHeight,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
            setState(() {
              _selectedIndex = i;
            });
          }
        });
        break;
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _api.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Monthly Work Hours Detail'),
        elevation: 0,
        backgroundColor: const Color(0xFF1E3C72),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            onPressed: () {
              // Calendar view could be implemented here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calendar view coming soon')),
              );
            },
          ),
        ],
      ),
      body: _dailyData.isNotEmpty
          ? _buildContentView() // Show content if we have data (cached or fresh)
          : _isLoading
              ? _buildLoadingView() // Show loading only if no data is available
              : _buildErrorView(), // Show error if no data and not loading
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/Lottie/attenndance_splash_animation.json',
            width: 200,
            height: 200,
          ),
          const SizedBox(height: 20),
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: const Text(
              'Loading work hours data...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 80,
            color: Color(0xFFE53935),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Error: $_errorMessage',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Don\'t worry, we\'ll use cached data if available.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = '';
                  });
                  _api.fetchMonthlyWorkHoursDetail(widget.empKey,
                      useCache: false);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3C72),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentView() {
    final currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());

    // Calculate statistics
    int totalDays = _dailyData.length;
    int daysWithHours = 0;
    int weekendDays = 0;

    for (var day in _dailyData) {
      final workHours = day['work_hours'];
      if (workHours != "00:00") {
        daysWithHours++;
      }

      final DateTime parsedDate = DateTime.parse(day['date']);
      if (parsedDate.weekday == DateTime.saturday ||
          parsedDate.weekday == DateTime.sunday) {
        weekendDays++;
      }
    }

    int workingDays = totalDays - weekendDays;
    double attendancePercentage =
        workingDays > 0 ? (daysWithHours / workingDays) * 100 : 0;

    return CustomScrollView(
      // Add bottom padding to the entire scroll view to prevent overlap with navigation bar
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Show banner if using cached data and there was an error
        if (_errorMessage.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[800]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Using cached data',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Could not refresh: $_errorMessage',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _errorMessage = '';
                      });
                      _api.fetchMonthlyWorkHoursDetail(widget.empKey,
                          useCache: false);
                    },
                    tooltip: 'Retry',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: _buildSummaryCard(currentMonth, attendancePercentage),
        ),
        SliverToBoxAdapter(
          child: _buildStatisticsRow(daysWithHours, workingDays),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Daily Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Date',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E3C72),
                    ),
                  ),
                  Text(
                    'Work Hours',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E3C72),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Add space between header and list
        SliverToBoxAdapter(
          child: const SizedBox(height: 16),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = _dailyData[index];
              final date = item['date'];
              final workHours = item['work_hours'];
              // Get status from the data
              final status = item['status'] ?? '';

              // Parse date to show in better format
              final DateTime parsedDate = DateTime.parse(date);
              final String formattedDate =
                  DateFormat('dd MMM (EEE)').format(parsedDate);

              // Check if work hours is zero
              final bool isZeroHours = workHours == "00:00";

              // Check if it's weekend
              final bool isWeekend = parsedDate.weekday == DateTime.saturday ||
                  parsedDate.weekday == DateTime.sunday;

              // Check if it's today
              final bool isToday =
                  DateFormat('yyyy-MM-dd').format(DateTime.now()) == date;

              // Check if it's selected
              final bool isSelected = _selectedIndex == index;

              // Determine background color based on status
              Color backgroundColor;
              if (status == 'WO') {
                // Weekend Off days get light dark color
                backgroundColor = isSelected
                    ? const Color(0xFFE3F2FD)
                    : const Color(0xFFEEEEEE);
              } else if (status == 'HO') {
                // Holiday - light blue color
                backgroundColor = isSelected
                    ? const Color(0xFFE3F2FD)
                    : const Color(0xFFE1F5FE);
              } else if (status == 'AA') {
                // Absent - light red color
                backgroundColor = isSelected
                    ? const Color(0xFFE3F2FD)
                    : const Color(0xFFFFEBEE);
              } else if (status == 'PP') {
                // Partial Present - light green background
                backgroundColor = isSelected
                    ? const Color(0xFFE3F2FD)
                    : const Color(0xFFE8F5E9);
              } else {
                // Default color
                backgroundColor = isSelected
                    ? const Color(0xFFE3F2FD)
                    : (isWeekend && status != 'PR')
                        ? const Color(0xFFF5F5F5)
                        : Colors.white;
              }

              return Container(
                margin: EdgeInsets.fromLTRB(
                    16,
                    index == 0 ? 0 : 8,
                    16,
                    // Add extra bottom padding to the last item to prevent overlap with navigation bar
                    index == _dailyData.length - 1 ? 80 : 0),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: isToday
                      ? Border.all(color: const Color(0xFF1E3C72), width: 2)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // Date indicator with dot
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isZeroHours
                                ? Colors.grey[200]
                                : const Color(0xFF1E3C72).withOpacity(0.1),
                          ),
                          child: Center(
                            child: Text(
                              parsedDate.day.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isZeroHours
                                    ? Colors.grey[500]
                                    : const Color(0xFF1E3C72),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Date text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE').format(parsedDate),
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: isWeekend
                                      ? Colors.grey[600]
                                      : Colors.black87,
                                ),
                              ),
                              Text(
                                DateFormat('dd MMM, yyyy').format(parsedDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (isToday)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E3C72),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Today',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              // Add status badge if available
                              if (status.isNotEmpty && status != 'PR')
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getStatusText(status),
                                    style: TextStyle(
                                      color: _getStatusTextColor(status),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Hours
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isZeroHours
                                ? Colors.grey[200]
                                : const Color(0xFF1E3C72).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            workHours,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isZeroHours
                                  ? Colors.grey[500]
                                  : const Color(0xFF1E3C72),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            childCount: _dailyData.length,
          ),
        ),
        // Add additional padding at the bottom to ensure the last item is fully visible
        SliverToBoxAdapter(
          child: const SizedBox(height: 16),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String currentMonth, double attendancePercentage) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentMonth,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Work Summary',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time_filled,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${attendancePercentage.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.timer,
                  color: Colors.white70,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  _totalWorkHours,
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Total Hours This Month',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsRow(int daysWithHours, int workingDays) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Days Present',
              '$daysWithHours',
              Icons.check_circle_outline,
              const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Working Days',
              '$workingDays',
              Icons.calendar_today,
              const Color(0xFF1E3C72),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Average Hours',
              _calculateAverageHours(),
              Icons.access_time,
              const Color(0xFFFF9800),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateAverageHours() {
    if (_dailyData.isEmpty) return '00:00';

    int totalMinutes = 0;
    int daysWithWork = 0;

    for (var day in _dailyData) {
      final String workHours = day['work_hours'];
      if (workHours != '00:00') {
        final parts = workHours.split(':');
        if (parts.length == 2) {
          totalMinutes += (int.parse(parts[0]) * 60) + int.parse(parts[1]);
          daysWithWork++;
        }
      }
    }

    if (daysWithWork == 0) return '00:00';

    int avgMinutes = totalMinutes ~/ daysWithWork;
    int hours = avgMinutes ~/ 60;
    int minutes = avgMinutes % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper method to get status color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'WO':
        return Colors.grey[700]!;
      case 'HO':
        return Colors.indigo[700]!;
      case 'AA':
        return Colors.red[700]!;
      case 'PP':
        return Colors.green[700]!;
      case 'HD':
        return Colors.orange[700]!;
      case 'LV':
        return Colors.green[700]!;
      default:
        return Colors.grey[600]!;
    }
  }

  // Helper method to get status text color
  Color _getStatusTextColor(String status) {
    return Colors.white;
  }

  // Helper method to get status display text
  String _getStatusText(String status) {
    switch (status) {
      case 'WO':
        return 'Weekend Off';
      case 'HO':
        return 'Holiday';
      case 'AA':
        return 'Absent';
      case 'PP':
        return 'Partial Present';
      case 'HD':
        return 'Half Day';
      case 'LV':
        return 'Leave';
      case 'PR':
        return 'Present';
      default:
        return status;
    }
  }
}
