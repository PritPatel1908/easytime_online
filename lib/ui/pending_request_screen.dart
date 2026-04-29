import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:easytime_online/api/pending_requests_api.dart';
import 'package:easytime_online/ui/generic_request_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingRequestScreen extends StatefulWidget {
  final String empKey;
  const PendingRequestScreen({Key? key, required this.empKey})
      : super(key: key);

  @override
  State<PendingRequestScreen> createState() => _PendingRequestScreenState();
}

class _PendingRequestScreenState extends State<PendingRequestScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  String _error = '';
  List<Map<String, dynamic>> _requests = [];
  String _selectedType = 'all';
  bool _canApproveAllEntities = false;

  static const Map<String, String> _typeOptions = {
    'all': 'All',
    'coff_application': 'C-off Application',
    'leave_application': 'Leave Application',
    'manual_att': 'Manual Attendance Application',
    'miss_punch': 'Manual Punch Application',
    'od_leave_application': 'Out Duty Leave Application',
    'overtime_apply': 'Overtime Application',
    'shift_application': 'Shift Change Application',
    'short_leave_application': 'Short Leave Application',
    'wo_application': 'Weekly Off Change Application',
  };

  List<Map<String, dynamic>> get _filteredRequests {
    if (_selectedType == 'all') return _requests;
    return _requests
        .where((r) => (r['type'] ?? '').toString() == _selectedType)
        .toList();
  }

  // Track per-item swipe animation state (true = slid left/offscreen)
  final Map<String, bool> _swipedState = {};
  final Duration _swipeDuration = const Duration(milliseconds: 350);
  // Track selection state for checkbox on each item
  final Set<String> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initRightsAndLoadRequests();
  }

  Future<void> _initRightsAndLoadRequests() async {
    await _loadUserRights();
    await _loadRequests();
  }

  Future<void> _loadUserRights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('user_rights_json') ??
          prefs.getString('user_rights') ??
          '';
      if (s.isNotEmpty) {
        final rights = json.decode(s) as Map<String, dynamic>;
        final la =
            _coerceToBool((rights['leave_application'] ?? {})['approve']);
        final mp = _coerceToBool((rights['manual_punch'] ?? {})['approve']);
        final ma =
            _coerceToBool((rights['manual_attendance'] ?? {})['approve']) ||
                _coerceToBool((rights['manual_att'] ?? {})['approve']);
        setState(() {
          _canApproveAllEntities = la && mp && ma;
        });
      } else {
        setState(() {
          _canApproveAllEntities = false;
        });
      }
    } catch (e) {
      setState(() {
        _canApproveAllEntities = false;
      });
    }
  }

  bool _coerceToBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) {
      final low = v.toLowerCase();
      return low == '1' || low == 'true' || low == 'yes';
    }
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadRequests({String? entityOverride}) async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      // Resolve entity_name param (use 'all' for all types).
      // Be flexible: modal might return the key or the label. Normalize input
      // (trim, lowercase) and match against keys and labels in a tolerant way.
      String normalize(String v) => v.trim().toLowerCase();

      String resolveEntityKey(String s) {
        final inStr = normalize(s);
        if (inStr.isEmpty) return 'all';
        // direct key match
        for (final k in _typeOptions.keys) {
          if (normalize(k) == inStr) return k;
        }
        // match by label (value)
        for (final e in _typeOptions.entries) {
          if (normalize(e.value) == inStr) return e.key;
        }
        // tolerant match: remove non-alphanum and compare
        String clean(String x) => x.replaceAll(RegExp(r'[^a-z0-9]'), '');
        final inClean = clean(inStr);
        if (inClean.isEmpty) return 'all';
        for (final e in _typeOptions.entries) {
          if (clean(normalize(e.key)) == inClean ||
              clean(normalize(e.value)) == inClean) {
            return e.key;
          }
        }
        // fallback to provided string (server may accept it), or 'all'
        return _typeOptions.containsKey(s) ? s : 'all';
      }

      final entityName = resolveEntityKey(entityOverride ?? _selectedType);

      // Fetch emp scope and pending requests in parallel
      final pendingRes = await PendingRequestsApi()
          .fetchPendingRequests(empKey: widget.empKey, entityName: entityName);

      if (pendingRes['success'] == true && pendingRes['data'] != null) {
        final pd = pendingRes['data'] as Map<String, dynamic>;
        final serverMsg =
            (pendingRes['message'] ?? pd['message'] ?? '').toString();
        final list = pd['data'] as List<dynamic>? ?? [];
        final parsed = list.map<Map<String, dynamic>>((e) {
          final Map<String, dynamic> m = e is Map<String, dynamic>
              ? Map<String, dynamic>.from(e)
              : Map<String, dynamic>.from(e as Map);
          // Ensure there's a `type` key for client-side filtering. Many
          // responses include `entity_name` (or similar) rather than `type`,
          // so prefer existing `type` but fall back to known fields.
          if (m['type'] == null || m['type'].toString().trim().isEmpty) {
            final fallback = (m['entity_name'] ??
                    m['entity'] ??
                    m['entity_key'] ??
                    m['type_key'] ??
                    '')
                .toString();
            if (fallback.isNotEmpty) m['type'] = fallback;
          }
          return m;
        }).toList();

        // sort by created/added time desc
        parsed.sort((a, b) {
          DateTime pa = DateTime.tryParse(
                  (a['entity_endorsement_flow_details_created_at'] ??
                          a['action_taken_time'] ??
                          '')
                      .toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          DateTime pb = DateTime.tryParse(
                  (b['entity_endorsement_flow_details_created_at'] ??
                          b['action_taken_time'] ??
                          '')
                      .toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return pb.compareTo(pa);
        });

        setState(() {
          _isLoading = false;
          _requests = parsed;
          // initialize swipe state for all loaded items
          _swipedState.clear();
          for (int i = 0; i < _requests.length; i++) {
            final r = _requests[i];
            final k = (r['id'] ??
                    r['entity_endorsement_flow_details_id'] ??
                    r['entity_id'] ??
                    r['request_id'] ??
                    i)
                .toString();
            _swipedState[k] = false;
          }
        });
        return;
      } else {
        setState(() {
          _isLoading = false;
          _error = pendingRes['message'] ?? 'Failed to load pending requests';
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

  String _getField(Map<String, dynamic> r, List<String> keys) {
    for (final k in keys) {
      if (r.containsKey(k) && r[k] != null) {
        final s = r[k].toString();
        if (s.trim().isNotEmpty) return s;
      }
    }
    return '';
  }

  // Extract a stable id to send to the backend for a record.
  // Prefer `request_details_key` when present, otherwise try common id fields.
  String _extractSelectedId(Map<String, dynamic> r) {
    if (r.containsKey('request_details_key') &&
        r['request_details_key'] != null &&
        r['request_details_key'].toString().isNotEmpty) {
      return r['request_details_key'].toString();
    }
    final keys = [
      'id',
      'entity_endorsement_flow_details_id',
      'entity_id',
      'request_id'
    ];
    for (final kk in keys) {
      if (r.containsKey(kk) && r[kk] != null && r[kk].toString().isNotEmpty) {
        return r[kk].toString();
      }
    }
    return '';
  }

  bool _recordMatchesId(Map<String, dynamic> rr, String id) {
    if (id.isEmpty) return false;
    if (rr.containsKey('request_details_key') &&
        rr['request_details_key'] != null &&
        rr['request_details_key'].toString() == id) {
      return true;
    }
    final keys = [
      'id',
      'entity_endorsement_flow_details_id',
      'entity_id',
      'request_id'
    ];
    for (final kk in keys) {
      if (rr.containsKey(kk) && rr[kk] != null && rr[kk].toString() == id) {
        return true;
      }
    }
    return false;
  }

  Future<void> _bulkApproveSelected() async {
    final count = _selectedItems.length;
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('Confirm Approve'),
                  content: Text('Approve $count selected request(s)?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Approve')),
                  ],
                )) ??
        false;
    if (!confirmed) return;

    // Group selected ids by entity_name
    final Map<String, List<String>> groups = {};
    for (int i = 0; i < _filteredRequests.length; i++) {
      final r = _filteredRequests[i];
      final itemKey = (r['id'] ??
              r['entity_endorsement_flow_details_id'] ??
              r['entity_id'] ??
              r['request_id'] ??
              i)
          .toString();
      if (!_selectedItems.contains(itemKey)) continue;
      final selId = _extractSelectedId(r);
      final entityName =
          (r['entity_name'] ?? r['type'] ?? r['entity'] ?? '').toString();
      if (!groups.containsKey(entityName)) groups[entityName] = [];
      groups[entityName]!.add(selId.isNotEmpty ? selId : itemKey);
    }

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No selected items to approve')));
      return;
    }

    // Build requests payload
    final List<Map<String, dynamic>> requestsPayload = groups.entries.map((e) {
      return {
        'entity_name': e.key,
        'action': 'approve_selected',
        'selected_ids': e.value,
      };
    }).toList();

    final res = await PendingRequestsApi().performBatchPendingRequestAction(
      creatorOwner: widget.empKey,
      requests: requestsPayload,
    );

    if (res['success'] == true) {
      // If server returns a 'processed' array, prefer that. Otherwise assume all were processed.
      final List<String> processedIds = [];
      try {
        final data = res['data'];
        if (data is Map && data['processed'] is List) {
          for (final p in data['processed']) {
            if (p is Map && p['id'] != null) {
              processedIds.add(p['id'].toString());
            }
          }
        }
      } catch (_) {}
      if (processedIds.isEmpty) {
        // fallback: flatten groups
        for (final v in groups.values) {
          processedIds.addAll(v);
        }
      }

      setState(() {
        for (final id in processedIds) {
          _requests.removeWhere((rr) => _recordMatchesId(rr, id));
        }
        _selectedItems.clear();
        _swipedState.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Approved ${processedIds.length} request(s)')));
    } else {
      final msg = res['message'] ?? 'Failed to approve selected items';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Approve failed: $msg')));
    }
  }

  Future<void> _bulkRejectSelected() async {
    final count = _selectedItems.length;
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) {
        final controller = TextEditingController();
        final mq = MediaQuery.of(ctx);
        final maxH = mq.size.height * 0.6;
        return Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: StatefulBuilder(builder: (ctx2, setStateSheet) {
            return SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reject $count selected request(s)',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        const Text('Please enter reason for rejection'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: controller,
                          autofocus: true,
                          maxLines: 5,
                          onChanged: (_) => setStateSheet(() {}),
                          decoration: const InputDecoration(
                              hintText: 'Rejection reason',
                              border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(null),
                                child: const Text('Cancel')),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: controller.text.trim().isEmpty
                                  ? null
                                  : () => Navigator.of(ctx)
                                      .pop(controller.text.trim()),
                              child: const Text('Reject'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );

    if (reason == null || reason.trim().isEmpty) return;

    // Group selected ids by entity_name
    final Map<String, List<String>> groups = {};
    for (int i = 0; i < _filteredRequests.length; i++) {
      final r = _filteredRequests[i];
      final itemKey = (r['id'] ??
              r['entity_endorsement_flow_details_id'] ??
              r['entity_id'] ??
              r['request_id'] ??
              i)
          .toString();
      if (!_selectedItems.contains(itemKey)) continue;
      final selId = _extractSelectedId(r);
      final entityName =
          (r['entity_name'] ?? r['type'] ?? r['entity'] ?? '').toString();
      if (!groups.containsKey(entityName)) groups[entityName] = [];
      groups[entityName]!.add(selId.isNotEmpty ? selId : itemKey);
    }

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No selected items to reject')));
      return;
    }

    // Build requests payload
    final List<Map<String, dynamic>> requestsPayload = groups.entries.map((e) {
      return {
        'entity_name': e.key,
        'action': 'reject_selected',
        'selected_ids': e.value,
        'reason': reason.trim(),
      };
    }).toList();

    final res = await PendingRequestsApi().performBatchPendingRequestAction(
      creatorOwner: widget.empKey,
      requests: requestsPayload,
    );

    if (res['success'] == true) {
      final List<String> processedIds = [];
      final List<String> failedIds = [];
      try {
        final data = res['data'];
        if (data is Map) {
          if (data['processed'] is List) {
            for (final p in data['processed']) {
              if (p is Map && p['id'] != null) {
                processedIds.add(p['id'].toString());
              }
            }
          }
          if (data['failed'] is List) {
            for (final f in data['failed']) {
              if (f is Map && f['id'] != null) {
                failedIds.add(f['id'].toString());
              }
            }
          }
        }
      } catch (_) {}

      if (processedIds.isEmpty) {
        for (final v in groups.values) {
          processedIds.addAll(v);
        }
      }

      setState(() {
        for (final id in processedIds) {
          _requests.removeWhere((rr) => _recordMatchesId(rr, id));
        }
        _selectedItems.clear();
        _swipedState.clear();
      });

      final processedCount = processedIds.length;
      final failedCount = failedIds.length;
      final msg = 'Rejected $processedCount request(s)';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(failedCount > 0 ? '$msg — $failedCount failed' : msg)));
    } else {
      final msg = res['message'] ?? 'Failed to reject selected items';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Reject failed: $msg')));
    }
  }

  Future<void> _rejectSingle(
      String itemKey, Map<String, dynamic> r, String displayTitle) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) {
        final controller = TextEditingController();
        final mq = MediaQuery.of(ctx);
        final maxH = mq.size.height * 0.6;
        return Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: StatefulBuilder(builder: (ctx2, setStateSheet) {
            return SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Please enter reason for rejection'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: controller,
                          autofocus: true,
                          maxLines: 5,
                          onChanged: (_) => setStateSheet(() {}),
                          decoration: const InputDecoration(
                              hintText: 'Rejection reason',
                              border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(null),
                                child: const Text('Cancel')),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: controller.text.trim().isEmpty
                                  ? null
                                  : () => Navigator.of(ctx)
                                      .pop(controller.text.trim()),
                              child: const Text('Reject'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );

    if (reason == null || reason.trim().isEmpty) return;

    // Prepare API params
    final entityName =
        (r['entity_name'] ?? r['type'] ?? r['entity'] ?? '').toString();
    String selectedId = '';
    if (r.containsKey('request_details_key') &&
        r['request_details_key'] != null &&
        r['request_details_key'].toString().isNotEmpty) {
      selectedId = r['request_details_key'].toString();
    } else {
      final keys = [
        'id',
        'entity_endorsement_flow_details_id',
        'entity_id',
        'request_id'
      ];
      for (final kk in keys) {
        if (r.containsKey(kk) && r[kk] != null && r[kk].toString().isNotEmpty) {
          selectedId = r[kk].toString();
          break;
        }
      }
    }

    if (selectedId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Cannot determine request id for $displayTitle')));
      return;
    }

    // Call backend to reject
    final res = await PendingRequestsApi().performPendingRequestAction(
      creatorOwner: widget.empKey,
      action: 'reject_selected',
      entityName: entityName,
      selectedIds: selectedId,
      reason: reason.trim(),
    );

    if (res['success'] == true) {
      setState(() {
        final keys = [
          'id',
          'entity_endorsement_flow_details_id',
          'entity_id',
          'request_id'
        ];
        var removed = false;
        for (final kk in keys) {
          if (r.containsKey(kk)) {
            _requests.removeWhere((rr) => rr[kk] == r[kk]);
            removed = true;
            break;
          }
        }
        if (!removed) _requests.remove(r);
        _selectedItems.remove(itemKey);
        _swipedState.remove(itemKey);
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rejected: $displayTitle — $reason')));
    } else {
      final msg = res['message'] ?? 'Failed to reject';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Reject failed: $msg')));
    }
  }

  Future<void> _approveSingle(
      String itemKey, Map<String, dynamic> r, String displayTitle) async {
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('Confirm Approve'),
                  content: Text('Approve: $displayTitle?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Approve')),
                  ],
                )) ??
        false;
    if (!confirmed) return;

    final entityName =
        (r['entity_name'] ?? r['type'] ?? r['entity'] ?? '').toString();
    String selectedId = '';
    if (r.containsKey('request_details_key') &&
        r['request_details_key'] != null &&
        r['request_details_key'].toString().isNotEmpty) {
      selectedId = r['request_details_key'].toString();
    } else {
      final keys = [
        'id',
        'entity_endorsement_flow_details_id',
        'entity_id',
        'request_id'
      ];
      for (final kk in keys) {
        if (r.containsKey(kk) && r[kk] != null && r[kk].toString().isNotEmpty) {
          selectedId = r[kk].toString();
          break;
        }
      }
    }

    if (selectedId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Cannot determine request id for $displayTitle')));
      return;
    }

    final res = await PendingRequestsApi().performPendingRequestAction(
      creatorOwner: widget.empKey,
      action: 'approve_selected',
      entityName: entityName,
      selectedIds: selectedId,
    );

    if (res['success'] == true) {
      setState(() {
        final keys = [
          'id',
          'entity_endorsement_flow_details_id',
          'entity_id',
          'request_id'
        ];
        var removed = false;
        for (final kk in keys) {
          if (r.containsKey(kk)) {
            _requests.removeWhere((rr) => rr[kk] == r[kk]);
            removed = true;
            break;
          }
        }
        if (!removed) _requests.remove(r);
        _selectedItems.remove(itemKey);
        _swipedState.remove(itemKey);
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Approved: $displayTitle')));
    } else {
      final msg = res['message'] ?? 'Failed to approve';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Approve failed: $msg')));
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
                  'Pending Request',
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
            onPressed: _loadRequests,
          ),
        ],
      ),
      floatingActionButton: _selectedItems.isNotEmpty
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_canApproveAllEntities) ...[
                  FloatingActionButton(
                    heroTag: 'bulk_approve',
                    onPressed: _bulkApproveSelected,
                    backgroundColor: Colors.green,
                    tooltip: 'Approve selected',
                    child: const Icon(Icons.check),
                  ),
                  const SizedBox(height: 10),
                ],
                FloatingActionButton(
                  heroTag: 'bulk_reject',
                  onPressed: _bulkRejectSelected,
                  backgroundColor: Colors.red,
                  tooltip: 'Reject selected',
                  child: const Icon(Icons.close),
                ),
              ],
            )
          : null,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              // Type selector (modern full-width tappable card)
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.white,
                  elevation: 1,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      final selected = await showModalBottomSheet<String>(
                        context: context,
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16))),
                        builder: (ctx) {
                          return SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 8),
                                Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(2)),
                                ),
                                const SizedBox(height: 12),
                                Flexible(
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: _typeOptions.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (c, i) {
                                      final entry =
                                          _typeOptions.entries.toList()[i];
                                      final key = entry.key;
                                      final label = entry.value;
                                      final selectedBool = key == _selectedType;
                                      return ListTile(
                                        title: Text(label),
                                        trailing: selectedBool
                                            ? const Icon(Icons.check,
                                                color: Color(0xFF1E3C72))
                                            : null,
                                        onTap: () => Navigator.pop(c, key),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          );
                        },
                      );
                      if (selected != null) {
                        setState(() {
                          _selectedType = selected;
                        });
                        // reload requests for new selection (pass selected explicitly)
                        _loadRequests(entityOverride: selected);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_list,
                              color: Color(0xFF1E3C72)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _typeOptions[_selectedType] ?? 'Select',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
                    ? ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: 4,
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
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [Center(child: Text('Error: $_error'))],
                          )
                        : _filteredRequests.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  Center(child: Text('No pending requests'))
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: _filteredRequests.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final r = _filteredRequests[index];
                                  // stable key for this record (try common id fields)
                                  final itemKey = (r['id'] ??
                                          r['entity_endorsement_flow_details_id'] ??
                                          r['entity_id'] ??
                                          r['request_id'] ??
                                          index)
                                      .toString();
                                  final isSwiped =
                                      _swipedState[itemKey] == true;
                                  // Build readable title/subtitle based on entity
                                  String entity =
                                      (r['entity_name'] ?? '').toString();
                                  String displayTitle =
                                      _typeOptions[entity] ?? 'Request';
                                  String displaySubtitle = '';
                                  String status =
                                      (r['entity_approval_status'] ??
                                              r['approval_status_name'] ??
                                              '')
                                          .toString();
                                  String dateStr =
                                      (r['entity_endorsement_flow_details_created_at'] ??
                                              r['action_taken_time'] ??
                                              r['leave_application_date'] ??
                                              r['miss_punch_application_date'] ??
                                              '')
                                          .toString();

                                  String fmtDate(String raw) {
                                    try {
                                      final d = DateTime.tryParse(raw);
                                      if (d == null) {
                                        return raw.split(' ').first;
                                      }
                                      return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
                                    } catch (_) {
                                      return raw;
                                    }
                                  }

                                  switch (entity) {
                                    case 'leave_application':
                                      final days = _getField(r, [
                                        'leave_debit_leave_days',
                                        'debit_leave_days',
                                        'leave_debit_leave_days'
                                      ]);
                                      final ld = _getField(r, [
                                        'leave_application_date',
                                        'leave_application_created_at',
                                        'action_taken_time'
                                      ]);
                                      displayTitle =
                                          '${days.isNotEmpty ? "$days day(s) • " : ''}${_typeOptions[entity] ?? 'Leave Application'}';
                                      displaySubtitle =
                                          fmtDate(ld.isNotEmpty ? ld : dateStr);
                                      break;
                                    case 'miss_punch':
                                      final punchTime = _getField(r, [
                                        'miss_punch_punch_time',
                                        'miss_punch_punch_time'
                                      ]);
                                      final appDate = _getField(r, [
                                        'miss_punch_application_date',
                                        'action_taken_time'
                                      ]);
                                      final punchType = _getField(r, [
                                        'miss_punch_punch_type_name',
                                        'miss_punch_punch_type_key'
                                      ]);
                                      displayTitle =
                                          '${_typeOptions[entity] ?? 'Miss Punch'}${punchType.isNotEmpty ? ' • $punchType' : ''}';
                                      displaySubtitle = fmtDate(
                                          punchTime.isNotEmpty
                                              ? punchTime
                                              : appDate);
                                      break;
                                    case 'manual_att':
                                    case 'manual_attendance':
                                      final inTime = _getField(
                                          r, ['manual_att_in_time', 'in_time']);
                                      final outTime = _getField(r,
                                          ['manual_att_out_time', 'out_time']);
                                      final appDate = _getField(r, [
                                        'manual_att_application_date',
                                        'action_taken_time'
                                      ]);
                                      displayTitle = _typeOptions[entity] ??
                                          'Manual Attendance';
                                      displaySubtitle =
                                          '${inTime.isNotEmpty ? inTime : ''}${inTime.isNotEmpty && outTime.isNotEmpty ? ' → ' : ''}${outTime.isNotEmpty ? outTime : fmtDate(appDate)}';
                                      break;
                                    case 'coff_application':
                                      final coffDate = _getField(r, [
                                        'coff_against_date',
                                        'coff_application_date',
                                        'coff_from_date'
                                      ]);
                                      displayTitle = _typeOptions[entity] ??
                                          'C-off Application';
                                      displaySubtitle = fmtDate(coffDate);
                                      break;
                                    case 'overtime_apply':
                                      final mins = _getField(r, [
                                        'overtime_duration_minutes',
                                        'overtime_minutes'
                                      ]);
                                      final otDate = _getField(r, [
                                        'overtime_ot_application_date',
                                        'overtime_date',
                                        'action_taken_time'
                                      ]);
                                      displayTitle =
                                          _typeOptions[entity] ?? 'Overtime';
                                      displaySubtitle = mins.isNotEmpty
                                          ? '$mins min'
                                          : fmtDate(otDate.isNotEmpty
                                              ? otDate
                                              : dateStr);
                                      break;
                                    case 'shift_application':
                                      final sApp = _getField(r, [
                                        'shift_application_date',
                                        'action_taken_time'
                                      ]);
                                      displayTitle = _typeOptions[entity] ??
                                          'Shift Change';
                                      displaySubtitle = fmtDate(
                                          sApp.isNotEmpty ? sApp : dateStr);
                                      break;
                                    case 'short_leave_application':
                                      final sApp = _getField(r, [
                                        'short_leave_application_date',
                                        'action_taken_time'
                                      ]);
                                      displayTitle =
                                          _typeOptions[entity] ?? 'Short Leave';
                                      displaySubtitle = fmtDate(
                                          sApp.isNotEmpty ? sApp : dateStr);
                                      break;
                                    case 'od_leave_application':
                                      final oApp = _getField(r, [
                                        'od_leave_application_date',
                                        'action_taken_time'
                                      ]);
                                      displayTitle =
                                          _typeOptions[entity] ?? 'Out Duty';
                                      displaySubtitle = fmtDate(
                                          oApp.isNotEmpty ? oApp : dateStr);
                                      break;
                                    case 'wo_application':
                                      final wApp = _getField(r, [
                                        'wo_application_date',
                                        'action_taken_time'
                                      ]);
                                      displayTitle = _typeOptions[entity] ??
                                          'Weekly Off Change';
                                      displaySubtitle = fmtDate(
                                          wApp.isNotEmpty ? wApp : dateStr);
                                      break;
                                    default:
                                      displayTitle = _typeOptions[entity] ??
                                          (entity.isNotEmpty
                                              ? entity
                                              : 'Request');
                                      displaySubtitle = fmtDate(dateStr);
                                  }

                                  IconData icon = Icons.list;
                                  Color iconColor = Colors.teal;
                                  if (entity == 'leave_application') {
                                    icon = Icons.beach_access;
                                    iconColor = Colors.blue;
                                  } else if (entity == 'miss_punch') {
                                    icon = Icons.access_time;
                                    iconColor = Colors.orange;
                                  } else if (entity == 'manual_att' ||
                                      entity == 'manual_attendance') {
                                    icon = Icons.edit_calendar;
                                    iconColor = Colors.green;
                                  } else if (entity == 'coff_application') {
                                    icon = Icons.calendar_today;
                                    iconColor = Colors.purple;
                                  } else if (entity == 'overtime_apply') {
                                    icon = Icons.timer;
                                    iconColor = Colors.indigo;
                                  }

                                  // stack with background action bar revealed when card slides left
                                  return Stack(
                                    children: [
                                      // background action bar (right side)
                                      Positioned.fill(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              // checkbox
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Checkbox(
                                                  value: _selectedItems
                                                      .contains(itemKey),
                                                  onChanged: (v) {
                                                    setState(() {
                                                      if (v == true) {
                                                        _selectedItems
                                                            .add(itemKey);
                                                      } else {
                                                        _selectedItems
                                                            .remove(itemKey);
                                                      }

                                                      // When at least one item is selected, reveal actions
                                                      // for all visible items. When none selected,
                                                      // hide actions again.
                                                      if (_selectedItems
                                                          .isNotEmpty) {
                                                        for (int j = 0;
                                                            j <
                                                                _filteredRequests
                                                                    .length;
                                                            j++) {
                                                          final r2 =
                                                              _filteredRequests[
                                                                  j];
                                                          final k2 = (r2[
                                                                      'id'] ??
                                                                  r2['entity_endorsement_flow_details_id'] ??
                                                                  r2['entity_id'] ??
                                                                  r2['request_id'] ??
                                                                  j)
                                                              .toString();
                                                          _swipedState[k2] =
                                                              true;
                                                        }
                                                      } else {
                                                        // clear swipe state (all closed)
                                                        _swipedState.clear();
                                                      }
                                                    });
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // view: open detailed screen for known entities
                                              Container(
                                                decoration: const BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle),
                                                child: IconButton(
                                                  icon: Icon(
                                                    Icons.remove_red_eye,
                                                    color: _selectedItems
                                                            .contains(itemKey)
                                                        ? Colors.grey
                                                        : Colors.black54,
                                                    size: 20,
                                                  ),
                                                  onPressed: _selectedItems
                                                          .contains(itemKey)
                                                      ? null
                                                      : () async {
                                                          FocusScope.of(context)
                                                              .unfocus();
                                                          // Open a generic, dynamic detail view
                                                          Navigator.of(context).push(
                                                              MaterialPageRoute(
                                                                  builder: (_) =>
                                                                      GenericRequestDetailScreen(
                                                                        record:
                                                                            r,
                                                                        title:
                                                                            displayTitle,
                                                                      )));
                                                        },
                                                ),
                                              ),
                                              // approve (only show when all three approve rights are true)
                                              if (_canApproveAllEntities) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  decoration: BoxDecoration(
                                                      color: Colors.green[50],
                                                      shape: BoxShape.circle),
                                                  child: IconButton(
                                                    icon: Icon(
                                                      Icons.check,
                                                      color: _selectedItems
                                                              .contains(itemKey)
                                                          ? Colors.grey
                                                          : Colors.green,
                                                      size: 20,
                                                    ),
                                                    onPressed: _selectedItems
                                                            .contains(itemKey)
                                                        ? null
                                                        : () {
                                                            _approveSingle(
                                                                itemKey,
                                                                r,
                                                                displayTitle);
                                                          },
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              // reject
                                              Container(
                                                decoration: BoxDecoration(
                                                    color: Colors.red[50],
                                                    shape: BoxShape.circle),
                                                child: IconButton(
                                                  icon: Icon(
                                                    Icons.close,
                                                    color: _selectedItems
                                                            .contains(itemKey)
                                                        ? Colors.grey
                                                        : Colors.red,
                                                    size: 20,
                                                  ),
                                                  onPressed: _selectedItems
                                                          .contains(itemKey)
                                                      ? null
                                                      : () {
                                                          _rejectSingle(itemKey,
                                                              r, displayTitle);
                                                        },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // foreground card that slides left to reveal actions
                                      AnimatedSlide(
                                        // slide to 80% left (not fully offscreen)
                                        offset: isSwiped
                                            ? const Offset(-0.8, 0)
                                            : Offset.zero,
                                        duration: _swipeDuration,
                                        curve: Curves.easeInOut,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () async {
                                            final currently =
                                                _swipedState[itemKey] == true;
                                            setState(() {
                                              if (!currently) {
                                                // Open this item and close any others
                                                _swipedState.clear();
                                                _swipedState[itemKey] = true;
                                              } else {
                                                // Close this item
                                                _swipedState[itemKey] = false;
                                              }
                                            });
                                            // wait for animation to finish
                                            await Future.delayed(
                                                _swipeDuration);
                                            // Intentionally do not show a SnackBar/toast
                                            // when an item is swiped. Silent reveal only.
                                          },
                                          child: Card(
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(12.0),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 20,
                                                    backgroundColor: iconColor
                                                        .withOpacity(0.12),
                                                    child: Icon(icon,
                                                        color: iconColor,
                                                        size: 18),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                  displayTitle,
                                                                  style: const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700)),
                                                            ),
                                                            if (status
                                                                .isNotEmpty) ...[
                                                              Container(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical:
                                                                        4),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade100,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              12),
                                                                ),
                                                                child: Text(
                                                                    status,
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                        color: Colors
                                                                            .black54)),
                                                              )
                                                            ]
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 6),
                                                        Text(
                                                          displaySubtitle
                                                                  .isNotEmpty
                                                              ? displaySubtitle
                                                              : '-',
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .grey),
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
