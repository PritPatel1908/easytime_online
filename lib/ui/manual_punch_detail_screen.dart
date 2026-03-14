import 'package:flutter/material.dart';

class ManualPunchDetailScreen extends StatelessWidget {
  final Map<String, dynamic> record;
  final String? empName;

  const ManualPunchDetailScreen({Key? key, required this.record, this.empName})
      : super(key: key);

  String _fmt(dynamic s) =>
      (s == null || s.toString().trim().isEmpty) ? '-' : s.toString();

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

  String _approvalStatusNameFrom(dynamic rec) {
    if (rec == null) return '-';
    final name =
        rec['approval_status_name'] ?? rec['approval_status_name'.toString()];
    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString();
    }
    final key =
        rec['approval_status_key'] ?? rec['approval_status_key'.toString()];
    if (key == null) return '-';
    final k = int.tryParse(key.toString());
    if (k != null && _approvalStatusNames.containsKey(k)) {
      return _approvalStatusNames[k]!;
    }
    return key.toString();
  }

  String _formatDate(dynamic raw) {
    final s = (raw == null) ? '' : raw.toString().trim();
    if (s.isEmpty) return '-';
    try {
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        final dd = dt.day.toString().padLeft(2, '0');
        final mm = dt.month.toString().padLeft(2, '0');
        final yyyy = dt.year.toString().padLeft(4, '0');
        return '$dd-$mm-$yyyy';
      }
    } catch (_) {}
    final m = RegExp(r'(\d{4})-(\d{2})-(\d{2})');
    final mmr = m.firstMatch(s);
    if (mmr != null) return '${mmr.group(3)}-${mmr.group(2)}-${mmr.group(1)}';
    return s;
  }

  String _formatTime(dynamic raw) {
    final s = (raw == null) ? '' : raw.toString().trim();
    if (s.isEmpty) return '-';
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
    final mmr = m.firstMatch(s);
    if (mmr != null) return mmr.group(1)!;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final type = _fmt(record['miss_punch_type'] ??
        record['punch_type_name'] ??
        record['punch_type']);
    final reason = _fmt(record['miss_punch_reason'] ?? record['reason']);
    final date = _formatDate(record['miss_punch_application_date'] ??
        record['miss_punch_created_at']);
    final time = _formatTime(
        record['punch_time_only'] ?? record['miss_punch_time'] ?? '');
    final status = _approvalStatusNameFrom(record);

    final endorsement = (record['endorsement_flow'] as List<dynamic>?)
            ?.map<Map<String, dynamic>>((e) {
          if (e is Map<String, dynamic>) return e;
          return Map<String, dynamic>.from(e as Map);
        }).toList() ??
        [];

    String empDisplay = empName ?? '';
    if (empDisplay.trim().isEmpty) {
      try {
        final emps = (record['employees'] as List<dynamic>?) ?? [];
        final displays = <String>[];
        for (final e in emps) {
          try {
            final m = e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map);
            String d = (m['emp_display'] ??
                        m['emp_name'] ??
                        m['emp_code'] ??
                        m['emp_key'])
                    ?.toString() ??
                '';
            final mbr = RegExp(r'\[([^\]]+)\]').firstMatch(d);
            if (mbr != null) {
              displays.add(mbr.group(1)!);
            } else if (d.trim().isNotEmpty) displays.add(d.trim());
          } catch (_) {}
        }
        empDisplay = displays.join(', ');
      } catch (_) {}
    }

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
                  'Punch Details',
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (empDisplay.trim().isNotEmpty)
                    Text(empDisplay,
                        style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  Text('Date: $date',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  if (time != '-')
                    Text('Time: $time',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Reason',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(reason),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          'Applied: ${_formatDate(record['miss_punch_created_at'] ?? record['miss_punch_application_date'])}',
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(status,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Approval Flow Status',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...endorsement.map((e) {
            final action = e['action'] ?? '-';
            final level = e['level_number'] ?? '-';
            final pendingEmp = e['pending_emp'] ?? '-';
            final actionByRaw = e['action_by'];
            final actionBy = actionByRaw == null
                ? ''
                : actionByRaw
                    .toString()
                    .replaceAll(RegExp(r'[\[\]]'), '')
                    .trim();
            final reject = e['reject_reason'];
            final endorseStatus = _approvalStatusNameFrom(e);
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
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13)),
                    const SizedBox(height: 4),
                    if (actionBy.isNotEmpty)
                      Text('By: ${actionBy.toString()}',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text('Status: $endorseStatus',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
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
          }).toList(),
        ],
      ),
    );
  }
}
