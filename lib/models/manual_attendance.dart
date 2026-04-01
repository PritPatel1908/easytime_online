class ManualAttendanceApplication {
  final List<String> employeeKeys;
  final DateTime inDatetime;
  final DateTime outDatetime;
  final String reason;

  ManualAttendanceApplication({
    required this.employeeKeys,
    required this.inDatetime,
    required this.outDatetime,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'employee_keys': employeeKeys,
        'in_datetime': inDatetime.toIso8601String(),
        'out_datetime': outDatetime.toIso8601String(),
        'reason': reason,
      };

  factory ManualAttendanceApplication.fromJson(Map<String, dynamic> json) {
    return ManualAttendanceApplication(
      employeeKeys: List<String>.from(json['employee_keys'] ?? []),
      inDatetime: DateTime.parse(json['in_datetime']),
      outDatetime: DateTime.parse(json['out_datetime']),
      reason: json['reason'] ?? '',
    );
  }
}
