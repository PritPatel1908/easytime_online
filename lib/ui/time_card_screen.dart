import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:easytime_online/api/time_card_api.dart';

class TimeCardScreen extends StatefulWidget {
  final String empKey;

  const TimeCardScreen({super.key, required this.empKey});

  @override
  State<TimeCardScreen> createState() => _TimeCardScreenState();
}

class _TimeCardScreenState extends State<TimeCardScreen> {
  final TimeCardApi _timeCardApi = TimeCardApi();
  StreamSubscription? _timeCardSubscription;

  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic>? _attendanceData;

  late DateTime _selectedDate;
  late String _selectedMonth;
  late String _selectedYear;
  String? _selectedRecordDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _selectedMonth = _selectedDate.month.toString().padLeft(2, '0');
    _selectedYear = _selectedDate.year.toString();

    _timeCardSubscription = _timeCardApi.timeCardDataStream.listen((result) {
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

    _fetchAttendanceData();
  }

  @override
  void dispose() {
    _timeCardSubscription?.cancel();
    super.dispose();
  }

  void _fetchAttendanceData() {
    setState(() {
      _isLoading = true;
    });

    if (_timeCardApi.hasCachedData(
      widget.empKey,
      month: _selectedMonth,
      year: _selectedYear,
    )) {
      if (kDebugMode) print('Using cached attendance data for time card');
    }

    _timeCardApi.fetchTimeCardData(
      widget.empKey,
      month: _selectedMonth,
      year: _selectedYear,
    );
  }

  void _changeMonth(int monthDelta) {
    setState(() {
      _selectedDate =
          DateTime(_selectedDate.year, _selectedDate.month + monthDelta);
      _selectedMonth = _selectedDate.month.toString().padLeft(2, '0');
      _selectedYear = _selectedDate.year.toString();
    });
    _fetchAttendanceData();
  }

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
            DropdownButtonFormField<int>(
              initialValue: int.parse(_selectedYear),
              decoration: const InputDecoration(labelText: 'Year'),
              items: years
                  .map((year) => DropdownMenuItem<int>(
                      value: year, child: Text(year.toString())))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedYear = value.toString());
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: int.parse(_selectedMonth),
              decoration: const InputDecoration(labelText: 'Month'),
              items: months
                  .map((month) => DropdownMenuItem<int>(
                      value: month,
                      child: Text(
                          DateFormat('MMMM').format(DateTime(2022, month)))))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(
                      () => _selectedMonth = value.toString().padLeft(2, '0'));
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context,
                DateTime(int.parse(_selectedYear), int.parse(_selectedMonth))),
            child: const Text('OK')),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PP':
        return Colors.blue;
      case 'AA':
        return Colors.red;
      case 'WO':
      case 'WOP':
      case 'PWO':
        return Colors.green;
      case 'HO':
      case 'PHO':
        return Colors.amber;
      case 'AP':
      case 'PA':
        return Colors.blue;
      default:
        return Colors.purple;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'PP':
        return Icons.check_circle;
      case 'AA':
        return Icons.cancel;
      case 'WO':
      case 'WOP':
      case 'PWO':
        return Icons.weekend;
      case 'HO':
      case 'PHO':
        return Icons.celebration;
      case 'AP':
      case 'PA':
        return Icons.check_circle;
      default:
        return Icons.beach_access;
    }
  }

  // Convert minutes (int or numeric) to HH:mm string. Returns '-' for null/invalid.
  String _minutesToHHMM(dynamic minutes) {
    if (minutes == null) return '-';
    int m;
    try {
      if (minutes is String) {
        m = int.tryParse(minutes) ?? 0;
      } else if (minutes is num) {
        m = minutes.toInt();
      } else {
        return '-';
      }
    } catch (_) {
      return '-';
    }

    // Show '-' for zero or negative minutes
    if (m <= 0) return '-';

    final hours = m ~/ 60;
    final mins = m % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  // Format incoming date strings to `DD (EEE)` e.g. `01 (Sun)`.
  String _formatDateShort(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '-';
    dateStr = dateStr.trim();

    DateTime? dt;
    try {
      // Common API formats: DD-MM-YYYY or YYYY-MM-DD
      if (dateStr.contains('-')) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          // If first part length == 4, assume YYYY-MM-DD
          if (parts[0].length == 4) {
            final y = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            final d = int.tryParse(parts[2]);
            if (y != null && m != null && d != null) dt = DateTime(y, m, d);
          } else {
            // Assume DD-MM-YYYY
            final d = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            final y = int.tryParse(parts[2]);
            if (y != null && m != null && d != null) dt = DateTime(y, m, d);
          }
        }
      }

      // Fallback to ISO parse
      dt ??= DateTime.tryParse(dateStr);
    } catch (_) {
      dt = null;
    }

    if (dt == null) return dateStr;

    final dd = dt.day.toString().padLeft(2, '0');
    final weekday = DateFormat('EEE').format(dt); // e.g. Sun, Mon
    return '$dd ($weekday)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E3C72),
        leadingWidth: 240,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 6),
            const Flexible(
              child: Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Text(
                  'Time Card',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            onPressed: _showMonthYearPicker,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchAttendanceData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: Theme.of(context).primaryColor.withAlpha(13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _changeMonth(-1),
                      tooltip: 'Previous Month'),
                  GestureDetector(
                      onTap: _showMonthYearPicker,
                      child: Row(children: [
                        Text(DateFormat('MMMM yyyy').format(_selectedDate),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down)
                      ])),
                  IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _changeMonth(1),
                      tooltip: 'Next Month'),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? _buildErrorView()
                      : _attendanceData == null || _attendanceData!.isEmpty
                          ? _buildEmptyView()
                          : _buildAttendanceTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTable() {
    final List<dynamic> attendanceRecords = _attendanceData ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewPadding.bottom + 64),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.only(bottom: 16),
            child: const Text('Attendance Records',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 24,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 64,
            showCheckboxColumn: false,
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
                  label: Text('Late (min)',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Early (min)',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Work (min)',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Status',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Remarks',
                      style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: attendanceRecords.map<DataRow>((record) {
              final rawDate = record['date']?.toString() ?? '';
              String dateStr = _formatDateShort(rawDate);
              String shift = record['shift'] ?? '';
              String inTime = record['in_time'] ?? '-';
              String outTime = record['out_time'] ?? '-';
              String status = record['status'] ?? '';
              String remarks = record['remarks'] ?? '-';
              final lateMinutes = record['late_minutes'];
              final earlyMinutes = record['early_minutes'];
              final totalWorking = record['total_working_minutes'];
              final String lateStr = _minutesToHHMM(lateMinutes);
              final String earlyStr = _minutesToHHMM(earlyMinutes);
              final String workStr = _minutesToHHMM(totalWorking);

              final bool selected = _selectedRecordDate == rawDate;

              return DataRow(
                  selected: selected,
                  onSelectChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedRecordDate = rawDate;
                      } else {
                        _selectedRecordDate = null;
                      }
                    });
                  },
                  color: WidgetStatePropertyAll(
                      selected ? Colors.grey[200] : null),
                  cells: [
                    DataCell(Text(dateStr)),
                    DataCell(Text(shift)),
                    DataCell(Text(inTime)),
                    DataCell(Text(outTime)),
                    DataCell(Text(lateStr)),
                    DataCell(Text(earlyStr)),
                    DataCell(Text(workStr)),
                    DataCell(Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: _getStatusColor(status).withAlpha(26),
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_getStatusIcon(status),
                              color: _getStatusColor(status), size: 16),
                          const SizedBox(width: 4),
                          Text(status,
                              style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.bold))
                        ]))),
                    DataCell(Text(remarks)),
                  ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        _buildLegend(),
      ]),
    );
  }

  Widget _buildErrorView() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
      const SizedBox(height: 16),
      Text(_errorMessage,
          style: TextStyle(
              color: Colors.red[400],
              fontWeight: FontWeight.w500,
              fontSize: 16),
          textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ElevatedButton.icon(
          onPressed: _fetchAttendanceData,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'))
    ]));
  }

  Widget _buildEmptyView() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.calendar_today, size: 48, color: Colors.grey[400]),
      const SizedBox(height: 16),
      Text('No attendance data available',
          style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
              fontSize: 16),
          textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ElevatedButton.icon(
          onPressed: _fetchAttendanceData,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'))
    ]));
  }

  Widget _buildLegend() {
    final statuses = [
      {'code': 'PP', 'name': 'Present'},
      {'code': 'AA', 'name': 'Absent'},
      {'code': 'WO', 'name': 'Week Off'},
      {'code': 'WOP', 'name': 'Week Off Paid'},
      {'code': 'PWO', 'name': 'Paid Week Off'},
      {'code': 'HO', 'name': 'Holiday'},
      {'code': 'PHO', 'name': 'Paid Holiday'},
      {'code': 'AP', 'name': 'Absent Present'},
      {'code': 'PA', 'name': 'Present Absent'},
      {'code': 'LE', 'name': 'Leave'},
    ];

    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withAlpha(51))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Legend',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
              spacing: 16,
              runSpacing: 12,
              children: statuses.map((status) {
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: _getStatusColor(status['code']!).withAlpha(26),
                          shape: BoxShape.circle),
                      child: Icon(_getStatusIcon(status['code']!),
                          color: _getStatusColor(status['code']!), size: 16)),
                  const SizedBox(width: 8),
                  Text('${status['code']!} - ${status['name']!}',
                      style: const TextStyle(fontSize: 12))
                ]);
              }).toList())
        ]));
  }
}
