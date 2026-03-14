import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easytime_online/api/get_emp_scope_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easytime_online/api/leave_applications_api.dart';
import 'package:easytime_online/ui/leave_application_detail_screen.dart';
import 'package:easytime_online/ui/new_leave_application_screen.dart';
import 'package:shimmer/shimmer.dart';

class LeaveApplicationScreen extends StatefulWidget {
  final String empKey;
  const LeaveApplicationScreen({Key? key, required this.empKey})
      : super(key: key);

  @override
  State<LeaveApplicationScreen> createState() => _LeaveApplicationScreenState();
}

class _LeaveApplicationScreenState extends State<LeaveApplicationScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  String _error = '';
  List<Map<String, dynamic>> _applications = [];
  Map<String, Map<String, dynamic>> _empMap = {};

  static const Map<int, String> _approvalStatusNames = {
    1: 'Applied',
    2: 'Pending',
    3: 'Rejected',
    4: 'Approved',
    5: 'Ignored',
    6: 'Overridden Approved',
    7: 'Overridden Rejected',
    8: 'Reapplied',
    9: 'Reapplied/Pending',
    10: 'Cancelled',
    11: 'Pending At Previous Level',
  };

  String _getApprovalStatusName(Map<String, dynamic> a) {
    final name = a['approval_status_name'];
    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString();
    }
    final key = a['approval_status_key'];
    if (key == null) return '-';
    try {
      final k = int.tryParse(key.toString()) ?? -1;
      if (k != -1 && _approvalStatusNames.containsKey(k)) {
        return _approvalStatusNames[k]!;
      }
    } catch (_) {}
    return key.toString();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadApplications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final scopeRes = await GetEmpScopeApi().fetchEmpScope(widget.empKey);
      if (scopeRes['success'] == true && scopeRes['data'] != null) {
        final data = scopeRes['data'] as Map<String, dynamic>;
        // cache emp_scope response so other screens (e.g., NewLeaveApplication) can reuse
        try {
          final prefs = await SharedPreferences.getInstance();
          final key = 'emp_scope_cache_${widget.empKey}';
          await prefs.setString(key, jsonEncode(data));
        } catch (_) {}
        final emps = data['emps'] as List<dynamic>? ?? [];
        final empKeys = <dynamic>[];
        _empMap = {};
        for (final e in emps) {
          try {
            final map = e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map);
            final key = (map['emp_key'] ?? '').toString();
            _empMap[key] = map;
            empKeys.add(map['emp_key']);
          } catch (_) {}
        }

        if (empKeys.isEmpty) {
          setState(() {
            _applications = [];
            _isLoading = false;
          });
          return;
        }

        // Fetch leave applications and leave types in parallel
        final appsFuture = LeaveApplicationsApi().fetchByEmpKeys(empKeys);
        final typesFuture =
            LeaveApplicationsApi().fetchLeaveTypesByEmpKeys(empKeys);

        final results = await Future.wait([appsFuture, typesFuture]);
        final appsRes = results[0];
        final typesRes = results[1];

        // Cache leave types result for NewLeaveApplicationScreen
        try {
          if (typesRes['success'] == true && typesRes['data'] != null) {
            final prefs = await SharedPreferences.getInstance();
            final key = 'leave_types_cache_${widget.empKey}';
            await prefs.setString(key, jsonEncode(typesRes['data']));
          }
        } catch (_) {}

        if (appsRes['success'] == true && appsRes['data'] != null) {
          final ad = appsRes['data'] as Map<String, dynamic>;
          final list = ad['data'] as List<dynamic>? ?? [];
          final parsed = list.map<Map<String, dynamic>>((e) {
            if (e is Map<String, dynamic>) return e;
            return Map<String, dynamic>.from(e as Map);
          }).toList();

          // sort by created_at or application_date desc
          parsed.sort((a, b) {
            DateTime pa = DateTime.tryParse(
                    (a['leave_application_created_at'] ??
                            a['leave_application_date'] ??
                            '')
                        .toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            DateTime pb = DateTime.tryParse(
                    (b['leave_application_created_at'] ??
                            b['leave_application_date'] ??
                            '')
                        .toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return pb.compareTo(pa);
          });

          setState(() {
            _applications = parsed;
            _isLoading = false;
          });
          return;
        } else {
          setState(() {
            _isLoading = false;
            _error = appsRes['message'] ?? 'Failed to load applications';
          });
          return;
        }
      } else {
        setState(() {
          _isLoading = false;
          _error = scopeRes['message'] ?? 'Failed to load team';
        });
        return;
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E3C72),
        leadingWidth: 200,
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
                  'Leave Application',
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
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadApplications,
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              ElevatedButton.icon(
                onPressed: () async {
                  final res = await Navigator.push<bool?>(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            NewLeaveApplicationScreen(empKey: widget.empKey)),
                  );
                  if (res == true) {
                    _loadApplications();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('New Leave Application'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadApplications,
                  child: _isLoading
                      ? ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: 4,
                          itemBuilder: (_, __) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(children: [
                                      Shimmer.fromColors(
                                        baseColor: Colors.grey[300]!,
                                        highlightColor: Colors.grey[100]!,
                                        child: const CircleAvatar(
                                            radius: 18,
                                            backgroundColor: Colors.white),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Shimmer.fromColors(
                                            baseColor: Colors.grey[300]!,
                                            highlightColor: Colors.grey[100]!,
                                            child: Container(
                                                height: 12,
                                                color: Colors.white),
                                          ),
                                          const SizedBox(height: 8),
                                          Shimmer.fromColors(
                                            baseColor: Colors.grey[300]!,
                                            highlightColor: Colors.grey[100]!,
                                            child: Container(
                                                height: 10,
                                                width: 80,
                                                color: Colors.white),
                                          ),
                                        ],
                                      ))
                                    ]),
                                  ),
                                ),
                              ))
                      : _error.isNotEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [Center(child: Text('Error: $_error'))],
                            )
                          : _applications.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    Center(child: Text('No applications'))
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount: _applications.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final a = _applications[index];
                                    final empKey =
                                        (a['emp_key'] ?? '').toString();
                                    final emp = _empMap[empKey];
                                    final empName = emp != null
                                        ? (emp['emp_name'] ?? '')
                                        : '';
                                    return InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                LeaveApplicationDetailScreen(
                                                    application: a,
                                                    empName:
                                                        empName?.toString()),
                                          ),
                                        );
                                      },
                                      child: Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Row(
                                            children: [
                                              const CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor:
                                                      Colors.blueAccent,
                                                  child: Icon(
                                                      Icons.event_available,
                                                      color: Colors.white,
                                                      size: 18)),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                        '${a['leave_type_code'] ?? '-'} • ${a['debit_leave_days'] ?? '-'} day(s)',
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600)),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      a['reason'] ?? '-',
                                                      style: const TextStyle(
                                                          color: Colors.grey),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    if (empName.isNotEmpty) ...[
                                                      const SizedBox(height: 6),
                                                      Text(empName,
                                                          style: const TextStyle(
                                                              color: Colors
                                                                  .black54,
                                                              fontSize: 12)),
                                                    ]
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                width: 110,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      '${a['from_date'] ?? '-'} → ${a['to_date'] ?? '-'}',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      'Status: ${_getApprovalStatusName(a)}',
                                                      style: const TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 12),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
