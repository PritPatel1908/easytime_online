import 'package:flutter/material.dart';

class LeaveApplicationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> application;
  final String? empName;

  const LeaveApplicationDetailScreen(
      {Key? key, required this.application, this.empName})
      : super(key: key);

  String _fmt(String? s) =>
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

  @override
  Widget build(BuildContext context) {
    final leaveType = _fmt(application['leave_type_code'] ??
        application['leave_type_key']?.toString());
    final days = _fmt(application['debit_leave_days']?.toString());
    final from = _fmt(application['from_date']?.toString());
    final to = _fmt(application['to_date']?.toString());
    final reason = _fmt(application['reason']?.toString());
    final created = _fmt(application['leave_application_created_at'] ??
        application['leave_application_date']);
    final status = _approvalStatusNameFrom(application);

    final endorsement = (application['endorsement_flow'] as List<dynamic>?)
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
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 6),
            const Flexible(
              child: Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Text(
                  'Leave Details',
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
                  Text('$leaveType • $days day(s)',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (empName != null)
                    Text(empName!,
                        style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  Text('From: $from',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('To: $to',
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
                      Text('Applied: $created',
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          status,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
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
