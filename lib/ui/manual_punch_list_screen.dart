import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:easytime_online/ui/manual_punch_application_screen.dart';
import 'package:easytime_online/ui/manual_punch_detail_screen.dart';
import 'package:easytime_online/api/get_emp_scope_api.dart';
import 'package:easytime_online/api/manual_punch_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManualPunchListScreen extends StatefulWidget {
  final String empKey;
  const ManualPunchListScreen({Key? key, required this.empKey})
      : super(key: key);

  @override
  State<ManualPunchListScreen> createState() => _ManualPunchListScreenState();
}

class _ManualPunchListScreenState extends State<ManualPunchListScreen> {
  bool _isLoading = false;
  String _error = '';
  List<Map<String, dynamic>> _items = [];

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final scopeRes = await GetEmpScopeApi().fetchEmpScope(widget.empKey);
      if (scopeRes['success'] == true && scopeRes['data'] != null) {
        final data = scopeRes['data'] as Map<String, dynamic>;
        try {
          final prefs = await SharedPreferences.getInstance();
          final key = 'emp_scope_cache_${widget.empKey}';
          await prefs.setString(key, jsonEncode(data));
        } catch (_) {}

        final emps = data['emps'] as List<dynamic>? ?? [];
        final empKeys = <dynamic>[];
        for (final e in emps) {
          try {
            final map = e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map);
            empKeys.add(map['emp_key']);
          } catch (_) {}
        }

        if (empKeys.isEmpty) {
          setState(() {
            _items = [];
            _isLoading = false;
          });
          return;
        }

        final res = await ManualPunchApi()
            .fetchByEmpCodes(empKeys.map((e) => e.toString()).toList());

        if (res['success'] == true && res['data'] != null) {
          final ad = res['data'] as Map<String, dynamic>;
          final list = ad['data'] as List<dynamic>? ?? [];
          final parsed = list.map<Map<String, dynamic>>((e) {
            if (e is Map<String, dynamic>) return e;
            return Map<String, dynamic>.from(e as Map);
          }).toList();

          // sort by created_at or application_date desc
          parsed.sort((a, b) {
            DateTime pa = DateTime.tryParse((a['miss_punch_created_at'] ??
                        a['miss_punch_application_date'] ??
                        '')
                    .toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            DateTime pb = DateTime.tryParse((b['miss_punch_created_at'] ??
                        b['miss_punch_application_date'] ??
                        '')
                    .toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return pb.compareTo(pa);
          });

          setState(() {
            _items = parsed;
            _isLoading = false;
          });
          return;
        } else {
          setState(() {
            _isLoading = false;
            _error = res['message'] ?? 'Failed to load manual punches';
          });
          return;
        }
      } else {
        setState(() {
          _isLoading = false;
          _error = scopeRes['message'] ?? 'Failed to load employees';
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

  String _initials(String name) {
    final parts =
        name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _formatTime(String raw) {
    final s = raw.toString().trim();
    if (s.isEmpty) return '';
    final simple = RegExp(r'^\d{2}:\d{2}(:\d{2})?\$');
    if (simple.hasMatch(s)) return s.substring(0, 5);
    try {
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        final hh = dt.hour.toString().padLeft(2, '0');
        final mm = dt.minute.toString().padLeft(2, '0');
        return '$hh:$mm';
      }
    } catch (_) {}
    final m = RegExp(r'(\d{2}:\d{2})');
    final mm = m.firstMatch(s);
    if (mm != null) return mm.group(1)!;
    return s;
  }

  @override
  void initState() {
    super.initState();
    _load();
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
                  'Manual Punch',
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
            onPressed: _load,
          ),
        ],
      ),
      body: Padding(
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
                          ManualPunchApplicationScreen(empKey: widget.empKey)),
                );
                if (res == true) _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('New Manual Punch'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _isLoading
                    ? ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: 3,
                        itemBuilder: (_, __) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(children: [
                                    const CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.blueAccent,
                                        child: Icon(Icons.edit,
                                            color: Colors.white, size: 18)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Container(
                                              height: 12,
                                              color: Colors.grey[300]),
                                          const SizedBox(height: 8),
                                          Container(
                                              height: 10,
                                              width: 80,
                                              color: Colors.grey[300])
                                        ])),
                                  ]),
                                ),
                              ),
                            ))
                    : _error.isNotEmpty
                        ? ListView(
                            children: [Center(child: Text('Error: $_error'))])
                        : _items.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                    Center(child: Text('No manual punches'))
                                  ])
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, index) {
                                  final a = _items[index];

                                  String reason = (a['miss_punch_reason'] ??
                                          a['reason'] ??
                                          '')
                                      .toString();
                                  final punchType = a['punch_type_name'] ??
                                      a['miss_punch_type'] ??
                                      a['punch_type'] ??
                                      '';

                                  final dateRaw =
                                      (a['miss_punch_application_date'] ??
                                              a['miss_punch_created_at'] ??
                                              '')
                                          .toString();
                                  String date = '';
                                  if (dateRaw.isNotEmpty) {
                                    try {
                                      final dt = DateTime.tryParse(dateRaw);
                                      if (dt != null) {
                                        date =
                                            '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                                      } else {
                                        date = dateRaw.split('T').first;
                                      }
                                    } catch (_) {
                                      date = dateRaw.split('T').first;
                                    }
                                  }

                                  final time = _formatTime(
                                      a['punch_time_only'] ??
                                          a['miss_punch_time'] ??
                                          '');
                                  final formattedTime =
                                      date; // show date as formattedTime above card if needed

                                  String empDisplay = '';
                                  try {
                                    final emps =
                                        a['employees'] as List<dynamic>? ?? [];
                                    if (emps.isNotEmpty) {
                                      final displays = <String>[];
                                      for (final e in emps) {
                                        try {
                                          final m = e is Map<String, dynamic>
                                              ? e
                                              : Map<String, dynamic>.from(
                                                  e as Map);
                                          String d = (m['emp_display'] ??
                                                      m['emp_name'] ??
                                                      m['emp_code'] ??
                                                      m['emp_key'])
                                                  ?.toString() ??
                                              '';
                                          final mbr = RegExp(r'\[([^\]]+)\]')
                                              .firstMatch(d);
                                          if (mbr != null) {
                                            displays.add(mbr.group(1)!);
                                          } else if (d.trim().isNotEmpty)
                                            displays.add(d.trim());
                                        } catch (_) {}
                                      }
                                      empDisplay = displays.join(', ');
                                    }
                                  } catch (_) {}

                                  final punchTypeStr = punchType.toString();
                                  String empClean = empDisplay
                                      .replaceAll(RegExp(r'\s+'), ' ')
                                      .trim();

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      InkWell(
                                        onTap: () async {
                                          // open detail screen for this record
                                          final emps = (a['employees']
                                                  as List<dynamic>?) ??
                                              [];
                                          String? empName;
                                          if (emps.isNotEmpty) {
                                            final displays = <String>[];
                                            for (final e in emps) {
                                              try {
                                                final m = e
                                                        is Map<String, dynamic>
                                                    ? e
                                                    : Map<String, dynamic>.from(
                                                        e as Map);
                                                String d = (m['emp_display'] ??
                                                            m['emp_name'] ??
                                                            m['emp_code'] ??
                                                            m['emp_key'])
                                                        ?.toString() ??
                                                    '';
                                                final mbr =
                                                    RegExp(r'\[([^\]]+)\]')
                                                        .firstMatch(d);
                                                if (mbr != null) {
                                                  displays.add(mbr.group(1)!);
                                                } else if (d.trim().isNotEmpty)
                                                  displays.add(d.trim());
                                              } catch (_) {}
                                            }
                                            empName = displays.join(', ');
                                          }
                                          await Navigator.push<bool?>(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    ManualPunchDetailScreen(
                                                        record: a,
                                                        empName: empName)),
                                          );
                                        },
                                        child: Card(
                                          elevation: 1,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                CircleAvatar(
                                                  radius: 20,
                                                  backgroundColor:
                                                      Colors.blueAccent,
                                                  child: empClean.isNotEmpty
                                                      ? Text(
                                                          _initials(empClean),
                                                          style: const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600))
                                                      : const Icon(Icons.edit,
                                                          color: Colors.white,
                                                          size: 18),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(punchTypeStr,
                                                          style:
                                                              const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize:
                                                                      14)),
                                                      if (empClean.isNotEmpty)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  top: 4.0),
                                                          child: Text(empClean,
                                                              style: const TextStyle(
                                                                  fontSize: 13,
                                                                  color: Colors
                                                                      .black87)),
                                                        ),
                                                      if (reason.isNotEmpty)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  top: 8.0),
                                                          child: Text(reason,
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .grey),
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                        date.isNotEmpty
                                                            ? date
                                                            : '-',
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                    if (time.isNotEmpty)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                top: 6.0,
                                                                bottom: 6.0),
                                                        child: Text(time,
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                      ),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 6),
                                                      decoration: BoxDecoration(
                                                          color:
                                                              Colors.grey[200],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      12)),
                                                      child: Text(
                                                          '${a['approval_status_name'] ?? a['approval_status_key'] ?? '-'}',
                                                          style: const TextStyle(
                                                              color: Colors
                                                                  .black54,
                                                              fontSize: 12)),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
