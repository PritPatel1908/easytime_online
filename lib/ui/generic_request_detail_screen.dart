import 'package:flutter/material.dart';

class GenericRequestDetailScreen extends StatelessWidget {
  final Map<String, dynamic> record;
  final String title;

  const GenericRequestDetailScreen(
      {Key? key, required this.record, required this.title})
      : super(key: key);

  String _fmt(dynamic v) {
    if (v == null) return '-';
    final s = v.toString();
    if (s.trim().isEmpty) return '-';
    return s;
  }

  Widget _buildKeyValue(String k, dynamic v) {
    // If this key represents an approval/status key, show human friendly status
    final keyLower = k.toString().toLowerCase();
    if (RegExp(r'status_key|approval_status|entity_approval_status')
        .hasMatch(keyLower)) {
      final statusName = _approvalStatusNameFrom(v);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                flex: 3,
                child: Text(
                  _prettyLabel(k),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Text(statusName,
                  style: const TextStyle(color: Colors.black87)),
            )
          ],
        ),
      );
    }

    // If this key is an employee key/id, try to show employee name instead of raw key
    final empKeyRegex = RegExp(r'emp(?:loyee)?[_-]?key|emp(?:loyee)?[_-]?id');
    if (empKeyRegex.hasMatch(keyLower)) {
      final empName = _lookupEmployeeName(v) ?? _formatValue(v);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                flex: 3,
                child: Text(
                  _prettyLabel(k),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child:
                  Text(empName, style: const TextStyle(color: Colors.black87)),
            )
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              flex: 3,
              child: Text(
                _prettyLabel(k),
                style: const TextStyle(fontWeight: FontWeight.w600),
              )),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(_formatValue(v),
                style: const TextStyle(color: Colors.black87)),
          )
        ],
      ),
    );
  }

  // Friendly labels for common keys
  String _prettyLabel(String key) {
    const map = {
      'emp_name': 'Employee',
      'emp_key': 'Employee',
      'employee_key': 'Employee',
      'employee_id': 'Employee',
      'emp_code': 'Employee Code',
      'leave_type_code': 'Leave Type',
      'debit_leave_days': 'Days',
      'from_date': 'From',
      'to_date': 'To',
      'reason': 'Reason',
      'leave_application_created_at': 'Applied',
      'leave_application_date': 'Applied',
      'miss_punch_time': 'Punch Time',
      'miss_punch_reason': 'Reason',
      'miss_punch_application_date': 'Applied',
      'in_time': 'In Time',
      'out_time': 'Out Time',
      'overtime_duration_minutes': 'Duration (mins)',
      'coff_against_date': 'C-off Date',
      'shift_application_date': 'Requested Date',
    };

    if (map.containsKey(key)) return map[key]!;
    // fallback: convert snake_case or camelCase to Title Case
    final cleaned = key.replaceAll(RegExp(r'[\_\-]+'), ' ');
    final words = cleaned.split(' ');
    return words.map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }

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

  String _approvalStatusNameFrom(dynamic val) {
    if (val == null) return '-';
    // If val is a map containing name
    if (val is Map) {
      final name =
          val['approval_status_name'] ?? val['approval_status_name'.toString()];
      if (name != null && name.toString().trim().isNotEmpty)
        return name.toString();
      final key =
          val['approval_status_key'] ?? val['approval_status_key'.toString()];
      if (key != null) {
        final k = int.tryParse(key.toString());
        if (k != null && _approvalStatusNames.containsKey(k))
          return _approvalStatusNames[k]!;
        return key.toString();
      }
    }
    // If val is a raw key (string/number)
    final s = val.toString();
    final k = int.tryParse(s);
    if (k != null && _approvalStatusNames.containsKey(k))
      return _approvalStatusNames[k]!;
    return s;
  }

  String _formatValue(dynamic v) {
    if (v == null) return '-';
    // Show booleans as human-friendly Yes/No
    if (v is bool) return v ? 'Yes' : 'No';
    if (v is String) {
      final sLow = v.trim().toLowerCase();
      if (sLow == 'true') return 'Yes';
      if (sLow == 'false') return 'No';
    }
    if (v is List) {
      try {
        // Try to extract readable names from list of maps
        final names = v
            .map((e) {
              if (e is Map && e.containsKey('emp_name'))
                return e['emp_name'].toString();
              if (e is Map && e.containsKey('name'))
                return e['name'].toString();
              return e.toString();
            })
            .where((s) => s.isNotEmpty)
            .toList();
        return names.isNotEmpty ? names.join(', ') : '-';
      } catch (_) {
        return v.toString();
      }
    }
    if (v is Map) return v.toString();
    final s = v.toString();
    final timeOnly = RegExp(r'^\d{2}:\d{2}(:\d{2})?\$');
    if (timeOnly.hasMatch(s)) return s.substring(0, 5);
    // try parse ISO datetime
    try {
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        final dd = dt.day.toString().padLeft(2, '0');
        final mm = dt.month.toString().padLeft(2, '0');
        final yyyy = dt.year.toString();
        final hh = dt.hour.toString().padLeft(2, '0');
        final min = dt.minute.toString().padLeft(2, '0');
        // show date and time if time is present
        if (dt.hour != 0 || dt.minute != 0 || dt.second != 0) {
          return '$dd-$mm-$yyyy $hh:$min';
        }
        return '$dd-$mm-$yyyy';
      }
    } catch (_) {}
    return s.isEmpty ? '-' : s;
  }

  String? _lookupEmployeeName(dynamic keyVal) {
    if (keyVal == null) return null;
    // If value is a map containing name, use it
    if (keyVal is Map) {
      final name = keyVal['emp_name'] ??
          keyVal['name'] ??
          keyVal['employee_name'] ??
          keyVal['full_name'];
      if (name != null && name.toString().trim().isNotEmpty)
        return name.toString();
    }

    final keyStr = keyVal.toString().trim();
    // If this record itself references the same key, prefer the top-level emp_name
    if ((record['emp_key'] ?? record['employee_key']) != null) {
      final rKey =
          (record['emp_key'] ?? record['employee_key']).toString().trim();
      if (rKey == keyStr && record['emp_name'] != null)
        return record['emp_name'].toString();
    }

    // Look inside an 'employees' list in the record for a matching key/code/id
    final employeesObj = record['employees'];
    if (employeesObj is List) {
      for (final e in employeesObj) {
        if (e is Map) {
          final possibleKeys = [
            'emp_key',
            'employee_key',
            'emp_code',
            'code',
            'id',
            'employee_id'
          ];
          for (final kk in possibleKeys) {
            if (e.containsKey(kk) &&
                e[kk] != null &&
                e[kk].toString().trim() == keyStr) {
              final name = e['emp_name'] ??
                  e['name'] ??
                  e['employee_name'] ??
                  e['full_name'];
              if (name != null && name.toString().trim().isNotEmpty)
                return name.toString();
            }
          }
        }
      }
    }

    // No match found
    return null;
  }

  List<Widget> _buildMainFields() {
    final List<String> ignore = [
      'endorsement_flow',
      'employees',
      'application_id',
      'record_id',
      'request_details_key',
      'entity_name',
    ];
    final keys = record.keys.where((k) => !ignore.contains(k)).toList();
    keys.sort();
    return keys.map((k) => _buildKeyValue(k, record[k])).toList();
  }

  Widget _buildEndorsementSection() {
    final endorsement = (record['endorsement_flow'] as List<dynamic>?)
            ?.map<Map<String, dynamic>>((e) {
          if (e is Map<String, dynamic>) return e;
          return Map<String, dynamic>.from(e as Map);
        }).toList() ??
        [];

    if (endorsement.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text('Approval Flow',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...endorsement.map((e) {
          final action = e['action'] ?? '-';
          final level = e['level_number'] ?? '-';
          final pendingEmp = e['pending_emp'] ?? '-';
          final actionByRaw = e['action_by'];
          final actionBy = actionByRaw == null
              ? ''
              : actionByRaw.toString().replaceAll(RegExp(r'[\[\]]'), '').trim();
          final reject = e['reject_reason'];
          final status =
              e['approval_status_name'] ?? e['approval_status_key'] ?? '-';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(action.toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                      Text('Level: $level',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Pending: ${pendingEmp.toString()}',
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 13)),
                  const SizedBox(height: 4),
                  if (actionBy.isNotEmpty)
                    Text('By: ${actionBy.toString()}',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text('Status: $status',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (reject != null) ...[
                    const SizedBox(height: 6),
                    const Text('Reject reason:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(reject.toString()),
                  ]
                ],
              ),
            ),
          );
        }).toList()
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final entityKey =
        (record['entity_name'] ?? record['type'] ?? record['entity'] ?? '')
            .toString();
    final entityPretty =
        entityKey.isNotEmpty ? _prettyEntityName(entityKey) : '';

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
                  title,
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (entityPretty.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.widgets, color: Color(0xFF1E3C72)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(entityPretty,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildMainFields(),
              ),
            ),
          ),
          _buildEndorsementSection(),
        ],
      ),
    );
  }

  String _prettyEntityName(String key) {
    final map = <String, String>{
      'manual_att': 'Manual Attendance',
      'miss_punch': 'Manual Punch',
      'leave_application': 'Leave Application',
      'coff_application': 'C-Off Application',
      'od_leave_application': 'Out Duty Leave Application',
      'overtime_apply': 'OverTime Apply',
      'shift_application': 'Shift Change Application',
      'short_leave_application': 'Short Leave Application',
      'wo_application': 'WeekOff Change Application',
    };

    if (map.containsKey(key)) return map[key]!;
    return key
        .split(RegExp(r'[_\s]+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
