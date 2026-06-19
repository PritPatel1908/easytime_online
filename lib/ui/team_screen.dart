import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easytime_online/api/get_emp_scope_api.dart';
import 'package:shimmer/shimmer.dart';

class TeamScreen extends StatefulWidget {
  final String empKey;
  const TeamScreen({Key? key, required this.empKey}) : super(key: key);

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  String _error = '';
  List<Map<String, dynamic>> _emps = [];
  Map<String, dynamic>? _summary;
  String _query = '';

  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchFocus.dispose();
    super.dispose();
  }

  void _setupData() {
    _loadCached().then((_) {
      _fetch();
    });
  }

  Future<void> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'emp_scope_cache_${widget.empKey}';
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> && decoded.containsKey('emps')) {
          final list = decoded['emps'] as List<dynamic>;
          setState(() {
            _emps = list.map<Map<String, dynamic>>((e) {
              if (e is Map<String, dynamic>) return e;
              return Map<String, dynamic>.from(e as Map);
            }).toList();
            if (decoded.containsKey('summary') &&
                decoded['summary'] is Map<String, dynamic>) {
              _summary = Map<String, dynamic>.from(decoded['summary'] as Map);
            }
            _isLoading = true;
          });
          return;
        }
      }
    } catch (_) {}
    setState(() => _isLoading = true);
  }

  Future<void> _fetch({bool force = false}) async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final res = await GetEmpScopeApi().fetchEmpScope(widget.empKey);
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final list = data['emps'] as List<dynamic>? ?? [];
        final newEmps = list.map<Map<String, dynamic>>((e) {
          if (e is Map<String, dynamic>) return e;
          return Map<String, dynamic>.from(e as Map);
        }).toList();

        setState(() {
          _emps = newEmps;
          _summary = data['summary'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(data['summary'] as Map)
              : null;
          _isLoading = false;
        });

        try {
          final prefs = await SharedPreferences.getInstance();
          final key = 'emp_scope_cache_${widget.empKey}';
          await prefs.setString(key, jsonEncode(data));
        } catch (_) {}
      } else {
        setState(() {
          _isLoading = false;
          _error = res['message'] ?? 'Failed to load team';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  Widget _buildStatTile(String label, String value) {
    return SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Color _statusColor(String? status) {
    final s = status?.toUpperCase() ?? '';
    switch (s) {
      case 'PP':
      case 'P':
        return Colors.green;
      case 'PA':
        return Colors.orange;
      case 'AA':
      case 'A':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _emps.where((e) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      final name = (e['emp_name'] ?? '').toString().toLowerCase();
      final code = (e['emp_code'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();

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
                  'My Team',
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
            onPressed: () => _fetch(force: true),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _searchFocus.unfocus();
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                focusNode: _searchFocus,
                decoration: InputDecoration(
                  hintText: 'Search by name or code',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (_summary != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 12.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxW = constraints.maxWidth;
                        const dateW = 96.0;
                        const spacing = 12.0;
                        const statCount = 4;
                        final available =
                            maxW - dateW - spacing * (statCount - 1);
                        final per = available / statCount;
                        final useWrap = per < 64 || per.isNaN || per.isInfinite;

                        if (useWrap) {
                          return Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildStatTile(
                                  'Total',
                                  _summary!['total_employees']?.toString() ??
                                      '-'),
                              _buildStatTile('Present',
                                  _summary!['present']?.toString() ?? '-'),
                              _buildStatTile('Absent',
                                  _summary!['absent']?.toString() ?? '-'),
                              _buildStatTile('Half',
                                  _summary!['half_day']?.toString() ?? '-'),
                              SizedBox(
                                width: dateW,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _summary!['date']?.toString() ?? '',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.black54),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    Text('Summary',
                                        style: TextStyle(
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        final statW = per;
                        return Row(
                          children: [
                            SizedBox(
                                width: statW,
                                child: _buildStatTile(
                                    'Total',
                                    _summary!['total_employees']?.toString() ??
                                        '-')),
                            const SizedBox(width: spacing),
                            SizedBox(
                                width: statW,
                                child: _buildStatTile('Present',
                                    _summary!['present']?.toString() ?? '-')),
                            const SizedBox(width: spacing),
                            SizedBox(
                                width: statW,
                                child: _buildStatTile('Absent',
                                    _summary!['absent']?.toString() ?? '-')),
                            const SizedBox(width: spacing),
                            SizedBox(
                                width: statW,
                                child: _buildStatTile('Half',
                                    _summary!['half_day']?.toString() ?? '-')),
                            const SizedBox(width: spacing),
                            SizedBox(
                              width: dateW,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _summary!['date']?.toString() ?? '',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.black54),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 5),
                                  Text('Summary',
                                      style: TextStyle(
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _isLoading && visible.isEmpty
                  ? ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: 6,
                      itemBuilder: (_, __) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(children: [
                                  Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!,
                                    highlightColor: Colors.grey[100]!,
                                    child: const CircleAvatar(
                                        radius: 20,
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
                                            height: 12, color: Colors.white),
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
                      ? Center(child: Text('Error: $_error'))
                      : visible.isEmpty
                          ? const Center(child: Text('No team members found'))
                          : RefreshIndicator(
                              onRefresh: () => _fetch(force: true),
                              child: ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: visible.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, idx) {
                                  final e = visible[idx];
                                  final name = (e['emp_name'] ?? '').toString();
                                  final code = (e['emp_code'] ?? '').toString();
                                  final today = e['today_attendance']
                                      as Map<String, dynamic>?;
                                  final status = (today?['text_status'] ??
                                          today?['att_status'])
                                      ?.toString();
                                  final firstIn =
                                      today?['first_in_datetime']?.toString();
                                  final lastOut =
                                      today?['last_out_datetime']?.toString();
                                  return Card(
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors
                                            .primaries[name.hashCode %
                                                Colors.primaries.length]
                                            .shade200,
                                        child: Text(
                                            name.isNotEmpty
                                                ? name
                                                    .split(' ')
                                                    .map((s) => s.isNotEmpty
                                                        ? s[0]
                                                        : '')
                                                    .take(2)
                                                    .join()
                                                : '?',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                      title: Text(name),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Code: $code'),
                                          const SizedBox(height: 6),
                                          if (today != null)
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _statusColor(status)
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(status ?? '-',
                                                      style: TextStyle(
                                                          color: _statusColor(
                                                              status),
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                ),
                                                if (firstIn != null)
                                                  ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                        maxWidth: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            0.5),
                                                    child: Text(
                                                      'In: ${firstIn.split('.').first}',
                                                      style: const TextStyle(
                                                          fontSize: 12),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                if (lastOut != null)
                                                  ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                        maxWidth: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            0.5),
                                                    child: Text(
                                                      'Out: ${lastOut.split('.').first}',
                                                      style: const TextStyle(
                                                          fontSize: 12),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                        ],
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
    );
  }
}
