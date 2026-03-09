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
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  'My Team',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
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
                                    child: CircleAvatar(
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
                          ? Center(child: Text('No team members found'))
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
                                      subtitle: Text('Code: $code'),
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
