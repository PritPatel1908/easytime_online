import 'package:flutter/material.dart';

class ManualAttendanceDetailScreen extends StatelessWidget {
  final Map<String, dynamic> record;
  final String? empName;

  const ManualAttendanceDetailScreen(
      {Key? key, required this.record, this.empName})
      : super(key: key);

  String _fmt(dynamic s) =>
      (s == null || s.toString().trim().isEmpty) ? '-' : s.toString();

  String _formatDateTime(dynamic raw) {
    final s = (raw == null) ? '' : raw.toString().trim();
    if (s.isEmpty) return '-';
    try {
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        final dd = dt.day.toString().padLeft(2, '0');
        final mm = dt.month.toString().padLeft(2, '0');
        final yyyy = dt.year.toString().padLeft(4, '0');
        final hh = dt.hour.toString().padLeft(2, '0');
        final min = dt.minute.toString().padLeft(2, '0');
        return '$dd-$mm-$yyyy $hh:$min';
      }
    } catch (_) {}
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final inDt = _formatDateTime(record['manual_att_in_datetime'] ??
        record['in_datetime'] ??
        record['manual_att_in_time'] ??
        record['in_time']);
    final outDt = _formatDateTime(record['manual_att_out_datetime'] ??
        record['out_datetime'] ??
        record['manual_att_out_time'] ??
        record['out_time']);
    final reason = _fmt(record['reason'] ?? record['manual_att_reason']);
    final status =
        _fmt(record['approval_status_name'] ?? record['approval_status_key']);

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
            if (mbr != null)
              displays.add(mbr.group(1)!);
            else if (d.trim().isNotEmpty) displays.add(d.trim());
          } catch (_) {}
        }
        empDisplay = displays.join(', ');
      } catch (_) {}
    }

    final endorsement = (record['endorsement_flow'] as List<dynamic>?)
            ?.map<Map<String, dynamic>>((e) {
          if (e is Map<String, dynamic>) return e;
          return Map<String, dynamic>.from(e as Map);
        }).toList() ??
        [];

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
                onPressed: () => Navigator.of(context).pop()),
            const SizedBox(width: 6),
            const Flexible(
                child: Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Text('Attendance Details',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)))),
          ],
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (empDisplay.trim().isNotEmpty)
                        Text(empDisplay,
                            style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 8),
                      Text('In: $inDt',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Out: $outDt',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      const Text('Reason',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(reason),
                      const SizedBox(height: 12),
                      Align(
                          alignment: Alignment.centerRight,
                          child: Text(status,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                    ]))),
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
              : actionByRaw.toString().replaceAll(RegExp(r'[\[\]]'), '').trim();
          final reject = e['reject_reason'];
          final endorseStatus =
              e['approval_status_name'] ?? e['approval_status_key'] ?? '-';
          return Card(
              child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(action.toString(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                          Text('Level: $level',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12))
                        ]),
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
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                        if (reject != null) ...[
                          const SizedBox(height: 6),
                          const Text('Reject reason:',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(reject.toString())
                        ]
                      ])));
        }).toList(),
      ]),
    );
  }
}
