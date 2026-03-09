import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shimmer/shimmer.dart';
import 'package:easytime_online/api/pending_requests_api.dart';
import 'package:easytime_online/api/get_emp_scope_api.dart';

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
    _loadRequests();
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
      String _normalize(String v) => v.trim().toLowerCase();

      String _resolveEntityKey(String s) {
        final inStr = _normalize(s);
        if (inStr.isEmpty) return 'all';
        // direct key match
        for (final k in _typeOptions.keys) {
          if (_normalize(k) == inStr) return k;
        }
        // match by label (value)
        for (final e in _typeOptions.entries) {
          if (_normalize(e.value) == inStr) return e.key;
        }
        // tolerant match: remove non-alphanum and compare
        String clean(String x) => x.replaceAll(RegExp(r'[^a-z0-9]'), '');
        final inClean = clean(inStr);
        if (inClean.isEmpty) return 'all';
        for (final e in _typeOptions.entries) {
          if (clean(_normalize(e.key)) == inClean ||
              clean(_normalize(e.value)) == inClean) return e.key;
        }
        // fallback to provided string (server may accept it), or 'all'
        return _typeOptions.containsKey(s) ? s : 'all';
      }

      final entityName = _resolveEntityKey(entityOverride ?? _selectedType);

      if (kDebugMode)
        print(
            'Loading pending requests: emp_key=${widget.empKey} entity_name=$entityName');

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
                  'Pending Request',
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
            onPressed: _loadRequests,
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
              // Type selector (modern full-width tappable card)
              Container(
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
                                      child: CircleAvatar(
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

                                  String _fmtDate(String raw) {
                                    try {
                                      final d = DateTime.tryParse(raw);
                                      if (d == null)
                                        return raw.split(' ').first;
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
                                          '${days.isNotEmpty ? days + " day(s) • " : ''}${_typeOptions[entity] ?? 'Leave Application'}';
                                      displaySubtitle = _fmtDate(
                                          ld.isNotEmpty ? ld : dateStr);
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
                                          '${_typeOptions[entity] ?? 'Miss Punch'}${punchType.isNotEmpty ? ' • ' + punchType : ''}';
                                      displaySubtitle = _fmtDate(
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
                                      displayTitle =
                                          '${_typeOptions[entity] ?? 'Manual Attendance'}';
                                      displaySubtitle =
                                          '${inTime.isNotEmpty ? inTime : ''}${inTime.isNotEmpty && outTime.isNotEmpty ? ' → ' : ''}${outTime.isNotEmpty ? outTime : _fmtDate(appDate)}';
                                      break;
                                    case 'coff_application':
                                      final coffDate = _getField(r, [
                                        'coff_against_date',
                                        'coff_application_date',
                                        'coff_from_date'
                                      ]);
                                      displayTitle =
                                          '${_typeOptions[entity] ?? 'C-off Application'}';
                                      displaySubtitle = _fmtDate(coffDate);
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
                                          '${_typeOptions[entity] ?? 'Overtime'}';
                                      displaySubtitle = mins.isNotEmpty
                                          ? '${mins} min'
                                          : _fmtDate(otDate.isNotEmpty
                                              ? otDate
                                              : dateStr);
                                      break;
                                    case 'shift_application':
                                      final sApp = _getField(r, [
                                        'shift_application_date',
                                        'action_taken_time'
                                      ]);
                                      displayTitle =
                                          '${_typeOptions[entity] ?? 'Shift Change'}';
                                      displaySubtitle = _fmtDate(
                                          sApp.isNotEmpty ? sApp : dateStr);
                                      break;
                                    case 'short_leave_application':
                                      final sApp = _getField(r, [
                                        'short_leave_application_date',
                                        'action_taken_time'
                                      ]);
                                      displayTitle =
                                          '${_typeOptions[entity] ?? 'Short Leave'}';
                                      displaySubtitle = _fmtDate(
                                          sApp.isNotEmpty ? sApp : dateStr);
                                      break;
                                    case 'od_leave_application':
                                      final oApp = _getField(r, [
                                        'od_leave_application_date',
                                        'action_taken_time'
                                      ]);
                                      displayTitle =
                                          '${_typeOptions[entity] ?? 'Out Duty'}';
                                      displaySubtitle = _fmtDate(
                                          oApp.isNotEmpty ? oApp : dateStr);
                                      break;
                                    case 'wo_application':
                                      final wApp = _getField(r, [
                                        'wo_application_date',
                                        'action_taken_time'
                                      ]);
                                      displayTitle =
                                          '${_typeOptions[entity] ?? 'Weekly Off Change'}';
                                      displaySubtitle = _fmtDate(
                                          wApp.isNotEmpty ? wApp : dateStr);
                                      break;
                                    default:
                                      displayTitle = _typeOptions[entity] ??
                                          (entity.isNotEmpty
                                              ? entity
                                              : 'Request');
                                      displaySubtitle = _fmtDate(dateStr);
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
                                                      if (v == true)
                                                        _selectedItems
                                                            .add(itemKey);
                                                      else
                                                        _selectedItems
                                                            .remove(itemKey);

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
                                              // view
                                              Container(
                                                decoration: BoxDecoration(
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
                                                      : () {
                                                          showDialog(
                                                            context: context,
                                                            builder: (_) =>
                                                                AlertDialog(
                                                              title: Text(
                                                                  displayTitle),
                                                              content: Text(
                                                                  'View details for this request.'),
                                                              actions: [
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            context),
                                                                    child: const Text(
                                                                        'CLOSE'))
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // approve
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
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(SnackBar(
                                                                  content: Text(
                                                                      'Approve: $displayTitle')));
                                                        },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
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
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(SnackBar(
                                                                  content: Text(
                                                                      'Reject: $displayTitle')));
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
