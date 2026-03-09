import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easytime_online/api/leave_balance_api.dart';
import 'package:shimmer/shimmer.dart';
import 'package:easytime_online/api/leave_transactions_api.dart';

class MyLeaveBalanceScreen extends StatefulWidget {
  final String empKey;
  const MyLeaveBalanceScreen({Key? key, required this.empKey}) : super(key: key);

  @override
  State<MyLeaveBalanceScreen> createState() => _MyLeaveBalanceScreenState();
}

class _MyLeaveBalanceScreenState extends State<MyLeaveBalanceScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  String _error = '';
  List<Map<String, dynamic>> _fyears = [];
  Map<String, List<Map<String, dynamic>>> _types = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setup() {
    _loadCached().then((_) => _fetch());
  }

  Future<void> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'leave_balance_cache_${widget.empKey}';
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> && decoded.containsKey('leave_balance')) {
          final list = decoded['leave_balance'] as List<dynamic>;
          setState(() {
            _fyears = list
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            _rebuildTypes();
            _isLoading = true; // still show loading until fresh fetch
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
      final res = await LeaveBalanceApi().fetchLeaveBalance(widget.empKey);
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final list = data['leave_balance'] as List<dynamic>? ?? [];
        final parsed =
            list.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();

        setState(() {
          _fyears = parsed;
          _rebuildTypes();
          _isLoading = false;
        });

        try {
          final prefs = await SharedPreferences.getInstance();
          final key = 'leave_balance_cache_${widget.empKey}';
          await prefs.setString(key, jsonEncode(data));
        } catch (_) {}
      } else {
        setState(() {
          _isLoading = false;
          _error = res['message'] ?? 'Failed to load leave balance';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _rebuildTypes() {
    final Map<String, List<Map<String, dynamic>>> m = {};
    for (final fy in _fyears) {
      final fcode = fy['fyear_code'] ?? '';
      final fyearKey = fy['financial_year_key'] ?? fy['fyear_key'] ?? null;
      final types = (fy['leave_types'] as List<dynamic>?) ?? [];
      for (final t in types) {
        final type = Map<String, dynamic>.from(t as Map);
        final code = (type['leave_type_code'] ?? '').toString();
        m.putIfAbsent(code, () => []).add({'fyear_code': fcode, 'fyear_key': fyearKey, 'type': type});
      }
    }
    _types = m;
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
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  'My Leave Balance',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
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
        onTap: () => FocusScope.of(context).unfocus(),
        child: _isLoading && _fyears.isEmpty
            ? ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: 3,
                itemBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Shimmer.fromColors(
                                  baseColor: Colors.grey[300]!,
                                  highlightColor: Colors.grey[100]!,
                                  child: Container(height: 14, color: Colors.white),
                                ),
                                const SizedBox(height: 8),
                                Shimmer.fromColors(
                                  baseColor: Colors.grey[300]!,
                                  highlightColor: Colors.grey[100]!,
                                  child: Container(height: 12, width: 120, color: Colors.white),
                                ),
                              ],
                            ))
                          ]),
                        ),
                      ),
                    ))
            : _error.isNotEmpty
                ? Center(child: Text('Error: $_error'))
                : RefreshIndicator(
                    onRefresh: () => _fetch(force: true),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        ..._types.entries.map((entry) {
                          final typeCode = entry.key;
                          final rows = entry.value; // list of {fyear_code, type, fyear_key}
                          return InkWell(
                            onTap: () {
                              if (rows.isNotEmpty) {
                                dynamic fyearKey = rows.first['fyear_key'] ?? rows.first['financial_year_key'];
                                if (fyearKey == null) {
                                  final searchCode = typeCode;
                                  for (final fy in _fyears) {
                                    final types = (fy['leave_types'] as List<dynamic>?) ?? [];
                                    for (final t in types) {
                                      final map = Map<String, dynamic>.from(t as Map);
                                      if ((map['leave_type_code'] ?? '').toString() == searchCode) {
                                        fyearKey = fy['financial_year_key'] ?? fy['fyear_key'];
                                        break;
                                      }
                                    }
                                    if (fyearKey != null) break;
                                  }
                                }

                                final type = Map<String, dynamic>.from(rows.first['type'] as Map);
                                final leaveTypeKey = type['leave_type_key'];
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LeaveTransactionsScreen(
                                      empKey: widget.empKey,
                                      financialYearKey: fyearKey,
                                      leaveTypeKey: leaveTypeKey,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            typeCode.toString(),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Builder(builder: (_) {
                                          final first = rows.isNotEmpty ? rows.first['type'] as Map<String, dynamic>? : null;
                                          final desc = (first != null && (first['leave_type_description'] ?? first['description']) != null)
                                              ? (first['leave_type_description'] ?? first['description']).toString()
                                              : '';
                                          return Expanded(
                                            child: Text(
                                              desc.isNotEmpty ? desc : '-',
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(color: Colors.grey),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        })
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ...rows.map<Widget>((r) {
                                      final fy = r['fyear_code'] ?? '';
                                      final type = Map<String, dynamic>.from(r['type'] as Map);
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(fy.toString(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                          const SizedBox(height: 6),
                                          _buildLeaveTypeRow(type),
                                          const SizedBox(height: 10),
                                        ],
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildBalanceRow(String label, dynamic value) {
    final display = value == null ? '-' : value.toString();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(display, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLeaveTypeRow(Map<String, dynamic> type) {
    final keeps = (type['keeps_balance'] ?? 0).toString();
    final keepsBalance = keeps == '1' || keeps == 'true' || keeps == '1.0';
    final balance = type['balance'] ?? '-';
    final utilized = type['utilized'] ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show only balance or utilized depending on keeps_balance
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              keepsBalance ? 'Balance' : 'Utilized',
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
              keepsBalance ? balance.toString() : utilized.toString(),
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

class LeaveTransactionsScreen extends StatefulWidget {
  final String empKey;
  final dynamic financialYearKey;
  final dynamic leaveTypeKey;

  const LeaveTransactionsScreen({Key? key, required this.empKey, required this.financialYearKey, required this.leaveTypeKey}) : super(key: key);

  @override
  State<LeaveTransactionsScreen> createState() => _LeaveTransactionsScreenState();
}

class _LeaveTransactionsScreenState extends State<LeaveTransactionsScreen> {
  bool _isLoading = true;
  String _error = '';
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final res = await LeaveTransactionsApi().fetchLeaveTransactions(
        empKey: widget.empKey,
        financialYearKey: widget.financialYearKey,
        leaveTypeKey: widget.leaveTypeKey,
      );
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final list = data['transactions'] as List<dynamic>? ?? [];
        setState(() {
          _transactions = list.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = res['message'] ?? 'Failed to load transactions';
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
                  'Transactions',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetch,
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: _isLoading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 3,
                itemBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!,
                                    highlightColor: Colors.grey[100]!,
                                    child: Container(height: 14, color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!,
                                    highlightColor: Colors.grey[100]!,
                                    child: Container(height: 12, width: 120, color: Colors.white),
                                  ),
                                ],
                              ),
                            )
                          ]),
                        ),
                      ),
                    ))
            : _error.isNotEmpty
                ? Center(child: Text('Error: $_error'))
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: _transactions.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(16),
                            children: const [Center(child: Text('No transactions found'))],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _transactions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final t = _transactions[index];
                              return _buildTransactionTile(t);
                            },
                          ),
                  ),
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> t) {
    final kind = t['kind'] ?? '';
    final date = t['date'] ?? '';
    // Build a nicer card for transaction / opening
    final cardPadding = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0);
    if (kind == 'opening') {
      final opening = t['opening'] ?? '-';
      return Card(
        child: Padding(
          padding: cardPadding,
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.history, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Opening', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Date: $date', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Text(opening.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    final data = t['data'] as Map<String, dynamic>?;
    final credit = data != null ? (data['credit_leave_days'] ?? data['credit'] ?? '-') : '-';
    final debit = data != null ? (data['debit_leave_days'] ?? data['debit'] ?? '-') : '-';
    final entityRaw = data != null ? (data['entity_name'] ?? '') : '';
    final entity = _formatEntity(entityRaw);
    final effective = data != null ? (data['effective_date'] ?? date) : date;
    final isApproved = data != null ? ((data['is_approved'] ?? 0).toString() == '1' || data['is_approved'] == true) : false;
    final isRejected = data != null ? ((data['is_rejected'] ?? 0).toString() == '1' || data['is_rejected'] == true) : false;

    return Card(
      child: Padding(
        padding: cardPadding,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isApproved ? Colors.green : (isRejected ? Colors.red : Colors.orange),
              child: Icon(kind == 'transaction' ? Icons.swap_horiz : Icons.info, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entity.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Date: $effective', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Credit: $credit', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Debit: $debit', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 6),
                if (isApproved) const Text('Approved', style: TextStyle(color: Colors.green, fontSize: 12))
                else if (isRejected) const Text('Rejected', style: TextStyle(color: Colors.red, fontSize: 12))
                else const SizedBox.shrink(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatEntity(dynamic raw) {
    if (raw == null) return '-';
    var s = raw.toString();
    s = s.replaceAll('_', ' ').trim();
    if (s.isEmpty) return '-';
    // Capitalize first letter of each word, rest lowercase
    final parts = s.split(RegExp(r"\s+"));
    final transformed = parts.map((w) {
      if (w.isEmpty) return w;
      final lower = w.toLowerCase();
      return '${lower[0].toUpperCase()}${lower.substring(1)}';
    }).join(' ');
    return transformed;
  }
}
