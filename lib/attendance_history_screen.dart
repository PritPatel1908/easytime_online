import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easytime_online/attendance_history_api.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // Added for kDebugMode

class AttendanceHistoryScreen extends StatefulWidget {
  final String empKey;

  const AttendanceHistoryScreen({
    super.key,
    required this.empKey,
  });

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final AttendanceHistoryApi _attendanceHistoryApi = AttendanceHistoryApi();
  StreamSubscription? _attendanceHistorySubscription;

  // State variables
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic>? _attendanceData;
  bool _showAsTable = false; // Toggle between calendar and table view

  // Month and year selection
  late DateTime _selectedDate;
  late String _selectedMonth;
  late String _selectedYear;

  @override
  void initState() {
    super.initState();

    // Initialize with current month and year
    _selectedDate = DateTime.now();
    _selectedMonth = _selectedDate.month.toString().padLeft(2, '0');
    _selectedYear = _selectedDate.year.toString();

    // Set up subscription to attendance data updates
    _attendanceHistorySubscription =
        _attendanceHistoryApi.attendanceDataStream.listen((result) {
      if (mounted) {
        setState(() {
          _isLoading = false;

          if (result['success'] == true &&
              result.containsKey('attendance_data')) {
            _attendanceData = result['attendance_data'] as List<dynamic>;
            _errorMessage = '';
          } else {
            _errorMessage =
                result['message'] ?? 'Failed to load attendance data';
          }
        });
      }
    });

    // Fetch attendance data
    _fetchAttendanceData();
  }

  @override
  void dispose() {
    _attendanceHistorySubscription?.cancel();
    super.dispose();
  }

  // Fetch attendance data with selected month and year
  void _fetchAttendanceData() {
    setState(() {
      _isLoading = true;
    });

    // Check if we have cached data
    if (_attendanceHistoryApi.hasCachedData(
      widget.empKey,
      month: _selectedMonth,
      year: _selectedYear,
    )) {
      // Use cached data if available
      final cachedData = _attendanceHistoryApi.getCachedData(
        widget.empKey,
        month: _selectedMonth,
        year: _selectedYear,
      );

      if (cachedData != null && cachedData['success'] == true) {
        // We don't need to set state here as the stream listener will handle it
        if (kDebugMode) {
          print("Using cached attendance history data");
        }
      }
    }

    _attendanceHistoryApi.fetchAttendanceHistory(
      widget.empKey,
      month: _selectedMonth,
      year: _selectedYear,
    );
  }

  // Refresh data from server (force refresh)
  void _refreshAttendanceData() {
    setState(() {
      _isLoading = true;
    });

    _attendanceHistoryApi.fetchAttendanceHistory(
      widget.empKey,
      month: _selectedMonth,
      year: _selectedYear,
      forceRefresh: true,
    );
  }

  // Change month and refetch data
  void _changeMonth(int monthDelta) {
    setState(() {
      _selectedDate =
          DateTime(_selectedDate.year, _selectedDate.month + monthDelta);
      _selectedMonth = _selectedDate.month.toString().padLeft(2, '0');
      _selectedYear = _selectedDate.year.toString();
    });

    _fetchAttendanceData();
  }

  // Show month picker
  Future<void> _showMonthYearPicker() async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return _buildMonthYearPicker();
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedMonth = _selectedDate.month.toString().padLeft(2, '0');
        _selectedYear = _selectedDate.year.toString();
      });

      _fetchAttendanceData();
    }
  }

  // Build month year picker dialog
  Widget _buildMonthYearPicker() {
    final currentYear = DateTime.now().year;
    final years = List<int>.generate(5, (i) => currentYear - 2 + i);
    final months = List<int>.generate(12, (i) => i + 1);

    return AlertDialog(
      title: const Text('Select Month & Year'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Year selection
            DropdownButtonFormField<int>(
              value: int.parse(_selectedYear),
              decoration: const InputDecoration(
                labelText: 'Year',
              ),
              items: years.map((year) {
                return DropdownMenuItem<int>(
                  value: year,
                  child: Text(year.toString()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedYear = value.toString();
                });
              },
            ),
            const SizedBox(height: 16),
            // Month selection
            DropdownButtonFormField<int>(
              value: int.parse(_selectedMonth),
              decoration: const InputDecoration(
                labelText: 'Month',
              ),
              items: months.map((month) {
                return DropdownMenuItem<int>(
                  value: month,
                  child: Text(DateFormat('MMMM').format(DateTime(2022, month))),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedMonth = value.toString().padLeft(2, '0');
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              DateTime(int.parse(_selectedYear), int.parse(_selectedMonth)),
            );
          },
          child: const Text('OK'),
        ),
      ],
    );
  }

  // Get color for attendance status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'PP':
        return Colors.blue;
      case 'AA':
        return Colors.red;
      case 'WO':
        return Colors.green;
      case 'HO':
        return Colors.amber;
      case 'LE':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // Get icon for attendance status
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'PP':
        return Icons.check_circle;
      case 'AA':
        return Icons.cancel;
      case 'WO':
        return Icons.weekend;
      case 'HO':
        return Icons.celebration;
      case 'LE':
        return Icons.beach_access;
      default:
        return Icons.help;
    }
  }

  // Toggle between calendar and table view
  void _toggleViewMode() {
    setState(() {
      _showAsTable = !_showAsTable;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        actions: [
          // Toggle view button
          IconButton(
            icon: Icon(_showAsTable ? Icons.calendar_month : Icons.table_rows),
            onPressed: _toggleViewMode,
            tooltip: _showAsTable ? 'Show Calendar' : 'Show Table',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAttendanceData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Month selector
          _buildMonthSelector(),

          // Attendance data
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? _buildErrorView()
                    : _attendanceData == null || _attendanceData!.isEmpty
                        ? _buildEmptyView()
                        : _showAsTable
                            ? _buildAttendanceTable()
                            : _buildAttendanceCalendar(),
          ),
        ],
      ),
    );
  }

  // Build month selector widget
  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Theme.of(context).primaryColor.withAlpha(13), // 0.05 * 255 ≈ 13
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
            tooltip: 'Previous Month',
          ),
          GestureDetector(
            onTap: _showMonthYearPicker,
            child: Row(
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeMonth(1),
            tooltip: 'Next Month',
          ),
        ],
      ),
    );
  }

  // Build attendance table view
  Widget _buildAttendanceTable() {
    final List<dynamic> attendanceRecords = _attendanceData ?? [];

    if (attendanceRecords.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No attendance data for this month',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.only(bottom: 16),
            child: const Text(
              'Attendance Records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Attendance table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) {
                  Color baseColor = Theme.of(context).primaryColor;
                  return Color.fromRGBO(
                    (baseColor.r * 255.0).round() & 0xff,
                    (baseColor.g * 255.0).round() & 0xff,
                    (baseColor.b * 255.0).round() & 0xff,
                    0.1,
                  );
                },
              ),
              columnSpacing: 24,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 64,
              columns: const [
                DataColumn(
                    label: Text('Date',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Shift',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('In Time',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Out Time',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Status',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Remarks',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: attendanceRecords.map<DataRow>((record) {
                // Parse date for sorting if needed
                String dateStr = record['date'] ?? '';
                String shift = record['shift'] ?? '';
                String inTime = record['in_time'] ?? '-';
                String outTime = record['out_time'] ?? '-';
                String status = record['status'] ?? '';
                String remarks = record['remarks'] ?? '-';

                return DataRow(
                  cells: [
                    DataCell(Text(dateStr)),
                    DataCell(Text(shift)),
                    DataCell(Text(inTime)),
                    DataCell(Text(outTime)),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(
                            (_getStatusColor(status).r * 255.0).round() & 0xff,
                            (_getStatusColor(status).g * 255.0).round() & 0xff,
                            (_getStatusColor(status).b * 255.0).round() & 0xff,
                            0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(status),
                              color: _getStatusColor(status),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status,
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(Text(remarks)),
                  ],
                );
              }).toList(),
            ),
          ),

          // Legend
          const SizedBox(height: 24),
          _buildLegend(),
        ],
      ),
    );
  }

  // Build error view
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: TextStyle(
              color: Colors.red[400],
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchAttendanceData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // Build empty view
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 48, color: Colors.grey[400]),
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
            onPressed: _fetchAttendanceData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  // Build attendance calendar
  Widget _buildAttendanceCalendar() {
    // Get days data from attendance data
    final List<dynamic> days = _attendanceData ?? [];

    // Build calendar grid
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Calendar header
        _buildCalendarHeader(),

        // Calendar days
        if (days.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.6, // Reduced from 0.65 to give more height
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: _getDaysInMonth(_selectedDate.year, _selectedDate.month),
            itemBuilder: (context, index) {
              final day = index + 1;
              // Find the day data safely without using firstWhere
              Map<String, dynamic>? dayData;
              for (var d in days) {
                if (d is Map<String, dynamic> && d['date'] != null) {
                  // Extract day from date string (assuming format like "01-07-2025")
                  String dateStr = d['date'].toString();
                  List<String> dateParts = dateStr.split('-');
                  if (dateParts.length >= 3 &&
                      int.tryParse(dateParts[0]) == day) {
                    dayData = d;
                    break;
                  }
                }
              }
              return _buildDayCell(day, dayData);
            },
          )
        else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'No attendance data for this month',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

        // Legend
        const SizedBox(height: 24),
        _buildLegend(),
      ],
    );
  }

  // Build calendar header with weekdays
  Widget _buildCalendarHeader() {
    final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekdays.map((day) {
          final isWeekend = day == 'Sun' || day == 'Sat';
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isWeekend
                    ? Colors.grey.withAlpha(26) // 0.1 * 255 ≈ 26
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                day,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isWeekend ? Colors.grey[600] : Colors.black87,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Build day cell
  Widget _buildDayCell(int day, dynamic dayData) {
    final bool hasData = dayData != null;
    final String status = hasData ? dayData['status'] : '';
    final String inTime = hasData ? dayData['in_time'] ?? '' : '';
    final String outTime = hasData ? dayData['out_time'] ?? '' : '';
    final String workHours = hasData
        ? (inTime.isNotEmpty && outTime.isNotEmpty)
            ? '${inTime.substring(0, 5)}-${outTime.substring(0, 5)}'
            : ''
        : '';

    // Check if this day is today
    final bool isToday = _isToday(day);

    // Check if this day is in the past
    final bool isPast = _isPastDay(day);

    // Calculate the weekday (0-6, where 0 is Sunday)
    final int weekday =
        DateTime(_selectedDate.year, _selectedDate.month, day).weekday % 7;
    final bool isWeekend = weekday == 0 || weekday == 6; // Sunday or Saturday

    return GestureDetector(
      onTap: hasData ? () => _showDayDetails(day, dayData) : null,
      child: Container(
        decoration: BoxDecoration(
          color: isToday
              ? Theme.of(context).primaryColor.withAlpha(26) // 0.1 * 255 ≈ 26
              : isWeekend && !hasData
                  ? Colors.grey.withAlpha(13) // 0.05 * 255 ≈ 13
                  : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isToday
                ? Theme.of(context).primaryColor
                : Colors.grey.withAlpha(51), // 0.2 * 255 ≈ 51
            width: isToday ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Use min size to prevent overflow
          children: [
            // Day number
            Text(
              day.toString(),
              style: TextStyle(
                fontSize: 11, // Reduced font size
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isPast && !hasData && !isWeekend
                    ? Colors.red
                    : isWeekend && !hasData
                        ? Colors.grey[600]
                        : Colors.black87,
              ),
            ),
            if (hasData) ...[
              // Removed SizedBox height
              // Status icon
              Icon(
                _getStatusIcon(status),
                color: _getStatusColor(status),
                size: 10, // Minimized size
              ),
              // Removed SizedBox height
              // Status text
              Text(
                status,
                style: TextStyle(
                  fontSize: 7, // Minimized font size
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(status),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (status == 'PP' && workHours.isNotEmpty) ...[
                // Removed SizedBox height
                // Work hours
                Text(
                  workHours,
                  style: const TextStyle(
                    fontSize: 7, // Further reduced font size
                    color: Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis, // Handle overflow text
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // Build legend for status codes
  Widget _buildLegend() {
    final statuses = [
      {'code': 'PP', 'name': 'Present'},
      {'code': 'AA', 'name': 'Absent'},
      {'code': 'WO', 'name': 'Week Off'},
      {'code': 'HO', 'name': 'Holiday'},
      {'code': 'LE', 'name': 'Leave'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withAlpha(51)), // 0.2 * 255 ≈ 51
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Legend',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: statuses.map((status) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status['code']!)
                          .withAlpha(26), // 0.1 * 255 ≈ 26
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getStatusIcon(status['code']!),
                      color: _getStatusColor(status['code']!),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${status['code']!} - ${status['name']!}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Show day details in a bottom sheet
  void _showDayDetails(int day, dynamic dayData) {
    final String status = dayData['status'] ?? '';
    final String shift = dayData['shift'] ?? '-';
    final String checkIn = dayData['in_time'] ?? '-';
    final String checkOut = dayData['out_time'] ?? '-';
    final String remarks = dayData['remarks'] ?? '-';
    final String date = dayData['date'] ??
        '$_selectedYear-$_selectedMonth-${day.toString().padLeft(2, '0')}';

    // Try to parse the date to a proper format for display
    DateTime? parsedDate;
    try {
      // Assuming date format is "DD-MM-YYYY"
      List<String> dateParts = date.split('-');
      if (dateParts.length >= 3) {
        parsedDate = DateTime(int.parse(dateParts[2]), int.parse(dateParts[1]),
            int.parse(dateParts[0]));
      }
    } catch (e) {
      // If parsing fails, we'll use the original date string
    }

    final String formattedDate = parsedDate != null
        ? DateFormat('EEE, MMM d, yyyy').format(parsedDate)
        : date;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status)
                          .withAlpha(26), // 0.1 * 255 ≈ 26
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(status),
                          color: _getStatusColor(status),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: TextStyle(
                            color: _getStatusColor(status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Details
              _buildDetailItem(
                icon: Icons.work,
                title: 'Shift',
                value: shift,
              ),
              const Divider(),

              if (status == 'PP') ...[
                _buildDetailItem(
                  icon: Icons.login,
                  title: 'Check In',
                  value: checkIn,
                ),
                const Divider(),
                _buildDetailItem(
                  icon: Icons.logout,
                  title: 'Check Out',
                  value: checkOut,
                ),
                const Divider(),
              ],

              _buildDetailItem(
                icon: Icons.note,
                title: 'Remarks',
                value: remarks,
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Build detail item for bottom sheet
  Widget _buildDetailItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .primaryColor
                  .withAlpha(26), // 0.1 * 255 ≈ 26
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to get days in month
  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  // Helper method to check if a day is today
  bool _isToday(int day) {
    final now = DateTime.now();
    return now.year == _selectedDate.year &&
        now.month == _selectedDate.month &&
        now.day == day;
  }

  // Helper method to check if a day is in the past
  bool _isPastDay(int day) {
    final now = DateTime.now();
    final selectedDate = DateTime(_selectedDate.year, _selectedDate.month, day);
    return selectedDate.isBefore(DateTime(now.year, now.month, now.day));
  }
}
