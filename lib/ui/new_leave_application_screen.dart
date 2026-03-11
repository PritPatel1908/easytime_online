import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/leave_applications_api.dart';

class NewLeaveApplicationScreen extends StatefulWidget {
  final String empKey;
  const NewLeaveApplicationScreen({Key? key, required this.empKey})
      : super(key: key);

  @override
  State<NewLeaveApplicationScreen> createState() =>
      _NewLeaveApplicationScreenState();
}

class _NewLeaveApplicationScreenState extends State<NewLeaveApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  String _leaveType = ''; // will hold leave_type_key as string
  DateTime? _fromDate;
  DateTime? _toDate;
  String _reason = '';
  List<String> _selectedEmployees = [];
  List<Map<String, String>> _sampleEmployees = [
    {'emp_key': 'EMP001', 'emp_code': 'EMP001', 'emp_name': 'EMP001'},
    {'emp_key': 'EMP002', 'emp_code': 'EMP002', 'emp_name': 'EMP002'},
    {'emp_key': 'EMP003', 'emp_code': 'EMP003', 'emp_name': 'EMP003'},
  ];
  List<Map<String, dynamic>> _leaveTypes = [];
  bool _onlyHalfDay = false;
  bool _isSecondHalf = false; // for From Date
  bool _isFirstHalf = false; // for To Date
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCachedEmployees();
    _loadCachedLeaveTypes();
  }

  Future<List<String>?> _showEmployeeSelector() async {
    final temp = List<String>.from(_selectedEmployees);
    String query = '';
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setState2) {
          final filtered = _sampleEmployees.where((e) {
            if (query.trim().isEmpty) return true;
            final name = (e['emp_name'] ?? '').toString().toLowerCase();
            final code = (e['emp_code'] ?? '').toString().toLowerCase();
            final q = query.toLowerCase();
            return name.contains(q) || code.contains(q);
          }).toList();

          // Respect keyboard insets and limit height to avoid overflow
          final mq = MediaQuery.of(ctx);
          final maxHeight = mq.size.height * 0.75;
          return Padding(
            padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
            child: SafeArea(
              child: SizedBox(
                height: maxHeight,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Expanded(
                              child: Text('Select employees',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600))),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, null),
                              child: const Text('CANCEL')),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, temp),
                              child: const Text('DONE')),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: TextField(
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search employees',
                            border: OutlineInputBorder()),
                        onChanged: (v) => setState2(() => query = v),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (_, idx) {
                          final item = filtered[idx];
                          final key = item['emp_key'] ?? '';
                          final name = item['emp_name'] ?? '';
                          final code = item['emp_code'] ?? key;
                          final selected = temp.contains(key);
                          return Container(
                            color: selected ? Colors.blue.shade50 : null,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: selected
                                        ? const Color(0xFF1E3C72)
                                        : Colors.grey[300],
                                    child: Text(
                                      (name ?? '').toString().isNotEmpty
                                          ? (name
                                              .toString()
                                              .split(' ')
                                              .map((s) =>
                                                  s.isNotEmpty ? s[0] : '')
                                              .take(2)
                                              .join())
                                          : (code ?? '').toString().substring(
                                              0,
                                              code.toString().length > 2
                                                  ? 2
                                                  : code.toString().length),
                                      style: TextStyle(
                                          color: selected
                                              ? Colors.white
                                              : Colors.black87),
                                    ),
                                  ),
                                  if (selected)
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        child: const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF1E3C72),
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                (name.toString().trim().isNotEmpty)
                                    ? '$name ($code)'
                                    : code,
                                style: const TextStyle(fontSize: 14),
                              ),
                              onTap: () => setState2(() {
                                if (selected)
                                  temp.remove(key);
                                else
                                  temp.add(key);
                              }),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Future<String?> _showLeaveTypeSelector() async {
    String query = '';
    final current = _leaveType;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setState2) {
          final filtered = _leaveTypes.where((e) {
            if (query.trim().isEmpty) return true;
            final code = (e['leave_type_code'] ?? '').toString().toLowerCase();
            final key = (e['leave_type_key'] ?? '').toString().toLowerCase();
            final q = query.toLowerCase();
            return code.contains(q) || key.contains(q);
          }).toList();

          final mq = MediaQuery.of(ctx);
          final maxHeight = mq.size.height * 0.6;

          return Padding(
            padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
            child: SafeArea(
              child: SizedBox(
                height: maxHeight,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Expanded(
                              child: Text('Leave Type',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600))),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, null),
                              child: const Text('CANCEL')),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: TextField(
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search leave types',
                            border: OutlineInputBorder()),
                        onChanged: (v) => setState2(() => query = v),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final item = filtered[idx];
                          final key = (item['leave_type_key'] ?? '').toString();
                          final code =
                              (item['leave_type_code'] ?? key).toString();
                          final selected = key == current;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: selected
                                  ? const Color(0xFF1E3C72)
                                  : Colors.grey[300],
                              child: Text(
                                code.isNotEmpty
                                    ? code.substring(
                                        0, code.length > 2 ? 2 : code.length)
                                    : key.isNotEmpty
                                        ? key.substring(
                                            0, key.length > 2 ? 2 : key.length)
                                        : '',
                                style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Colors.black87),
                              ),
                            ),
                            title: Text(code,
                                style: const TextStyle(fontSize: 14)),
                            onTap: () => Navigator.pop(ctx, key),
                            trailing: selected
                                ? const Icon(Icons.check,
                                    color: Color(0xFF1E3C72))
                                : null,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _loadCachedEmployees() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'emp_scope_cache_${widget.empKey}';
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> && decoded.containsKey('emps')) {
          final list = decoded['emps'] as List<dynamic>;
          final items = list
              .map<Map<String, String>>((e) {
                try {
                  final map = e is Map<String, dynamic>
                      ? e
                      : Map<String, dynamic>.from(e as Map);
                  final empKey = (map['emp_key'] ?? '').toString();
                  final empCode =
                      (map['emp_code'] ?? map['emp_key'] ?? '').toString();
                  final empName = (map['emp_name'] ?? empCode).toString();
                  return {
                    'emp_key': empKey,
                    'emp_code': empCode,
                    'emp_name': empName
                  };
                } catch (_) {
                  return {'emp_key': '', 'emp_code': '', 'emp_name': ''};
                }
              })
              .where((m) => (m['emp_key'] ?? '').isNotEmpty)
              .toList();
          if (items.isNotEmpty) {
            setState(() {
              _sampleEmployees = items;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        if (isFrom)
          _fromDate = picked;
        else
          _toDate = picked;
      });
    }
  }

  Future<void> _loadCachedLeaveTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'leave_types_cache_${widget.empKey}';
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          final list = decoded['data'] as List<dynamic>;
          final items = list.map<Map<String, dynamic>>((e) {
            if (e is Map<String, dynamic>) return e;
            return Map<String, dynamic>.from(e as Map);
          }).toList();
          if (items.isNotEmpty) {
            setState(() {
              _leaveTypes = items;
            });
          }
          return;
        }

        // If cached was saved as plain data array
        if (decoded is List<dynamic>) {
          final items = decoded.map<Map<String, dynamic>>((e) {
            if (e is Map<String, dynamic>) return e;
            return Map<String, dynamic>.from(e as Map);
          }).toList();
          if (items.isNotEmpty) {
            setState(() {
              _leaveTypes = items;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    final empKeys =
        _selectedEmployees.isNotEmpty ? _selectedEmployees : [widget.empKey];

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await LeaveApplicationsApi().validateSubmit(
        empKeys: empKeys,
        leaveTypeKey: _leaveType,
        onlyHalfDay: _onlyHalfDay,
        isThisSecondHalf: _isSecondHalf,
        fromDate: _fromDate,
        isFromHalfDay: _isSecondHalf,
        toDate: _toDate,
        isToHalfDay: _isFirstHalf,
        reason: _reason,
        creatorOwner: widget.empKey,
      );

      if (result['success'] == true) {
        Navigator.pop(context, true);
      } else {
        final msg = result['message']?.toString() ?? 'Unknown error';
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Submit failed'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: SelectableText(msg),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: msg));
                    Navigator.of(context).pop();
                  },
                  child: const Text('COPY')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'))
            ],
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    } catch (e) {
      final msg = e.toString();
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(msg),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: msg));
                  Navigator.of(context).pop();
                },
                child: const Text('COPY')),
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'))
          ],
        ),
      );
      setState(() {
        _isSubmitting = false;
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
                  'New Leave Application',
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
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Employees field - styled like Leave Type (no extra heading)
                  FormField<List<String>>(
                    initialValue: _selectedEmployees,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Select employee(s)' : null,
                    builder: (state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Employees',
                              errorText: state.errorText,
                              isDense: true,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                            child: InkWell(
                              onTap: () async {
                                final res = await _showEmployeeSelector();
                                if (res != null) {
                                  setState(() {
                                    _selectedEmployees = res;
                                    state.didChange(res);
                                  });
                                }
                              },
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _selectedEmployees.isEmpty
                                        ? const Text('Select employees',
                                            style: TextStyle(fontSize: 16))
                                        : SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children:
                                                  _selectedEmployees.map((k) {
                                                final found =
                                                    _sampleEmployees.firstWhere(
                                                        (e) =>
                                                            e['emp_key'] == k,
                                                        orElse: () => {
                                                              'emp_key': k,
                                                              'emp_code': k,
                                                              'emp_name': k
                                                            });
                                                final name =
                                                    found['emp_name'] ?? '';
                                                final code =
                                                    found['emp_code'] ?? k;
                                                final label = (name
                                                        .toString()
                                                        .trim()
                                                        .isNotEmpty)
                                                    ? '$name($code)'
                                                    : code;
                                                return Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 4),
                                                  child: InputChip(
                                                    label: Text(label),
                                                    onDeleted: () =>
                                                        setState(() {
                                                      _selectedEmployees
                                                          .remove(k);
                                                      state.didChange(
                                                          _selectedEmployees);
                                                    }),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                  ),
                                  Icon(Icons.arrow_drop_down,
                                      size: 24, color: Colors.grey[700]),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  FormField<String>(
                    initialValue: _leaveType,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Select leave type'
                        : null,
                    builder: (state) {
                      String display = 'Select leave type';
                      if ((_leaveType).trim().isNotEmpty) {
                        final found = _leaveTypes.firstWhere(
                            (e) =>
                                (e['leave_type_key'] ?? '').toString() ==
                                _leaveType,
                            orElse: () => {});
                        final code =
                            (found['leave_type_code'] ?? '').toString();
                        display = code.isNotEmpty ? code : _leaveType;
                      }
                      return InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Leave Type',
                          errorText: state.errorText,
                          isDense: true,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        child: InkWell(
                          onTap: () async {
                            final res = await _showLeaveTypeSelector();
                            if (res != null) {
                              setState(() {
                                _leaveType = res;
                                state.didChange(res);
                              });
                            }
                          },
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(display,
                                      style: const TextStyle(fontSize: 16))),
                              Icon(Icons.arrow_drop_down,
                                  size: 24, color: Colors.grey[700]),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 8),
                              minimumSize: const Size.fromHeight(36)),
                          onPressed: () => _pickDate(true),
                          child: Text(_fromDate == null
                              ? 'From Date'
                              : _fromDate!.toString().split(' ')[0]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 8),
                              minimumSize: const Size.fromHeight(36)),
                          onPressed:
                              _onlyHalfDay ? null : () => _pickDate(false),
                          child: Text(_toDate == null
                              ? 'To Date'
                              : _toDate!.toString().split(' ')[0]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Each toggle on its own line
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                          child: Text('Only Half Day',
                              overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Switch(
                          value: _onlyHalfDay,
                          onChanged: (v) => setState(() {
                                _onlyHalfDay = v;
                                if (v) {
                                  _toDate = null;
                                  _isFirstHalf = false;
                                }
                              })),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                          child: Text('Is Second Half',
                              overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Switch(
                          value: _isSecondHalf,
                          onChanged: (v) => setState(() => _isSecondHalf = v)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                          child: Text('Is First Half',
                              overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Switch(
                          value: _isFirstHalf,
                          onChanged: _onlyHalfDay
                              ? null
                              : (v) => setState(() => _isFirstHalf = v)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: const InputDecoration(
                        labelText: 'Reason',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 10, horizontal: 12)),
                    maxLines: 3,
                    onSaved: (v) => _reason = v?.trim() ?? '',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter reason' : null,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42)),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Submitting...'),
                              ],
                            )
                          : const Text('Submit')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
