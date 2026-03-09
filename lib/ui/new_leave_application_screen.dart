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
                                final res = await showDialog<List<String>>(
                                  context: context,
                                  builder: (ctx) {
                                    final temp =
                                        List<String>.from(_selectedEmployees);
                                    return Dialog(
                                      insetPadding: const EdgeInsets.symmetric(
                                          horizontal: 40, vertical: 24),
                                      child: StatefulBuilder(
                                          builder: (dCtx, setDialogState) {
                                        return Material(
                                          elevation: 4,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6)),
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                                maxHeight: 360),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: ListView(
                                                    shrinkWrap: true,
                                                    padding: const EdgeInsets
                                                        .symmetric(vertical: 8),
                                                    children: [
                                                      for (final item
                                                          in _sampleEmployees)
                                                        Container(
                                                          color: temp.contains(
                                                                  item[
                                                                      'emp_key'])
                                                              ? Colors
                                                                  .blue.shade50
                                                              : null,
                                                          child: ListTile(
                                                            dense: true,
                                                            title: Text(
                                                                ((item['emp_name'] !=
                                                                            null &&
                                                                        (item['emp_name'] ??
                                                                                '')
                                                                            .toString()
                                                                            .trim()
                                                                            .isNotEmpty)
                                                                    ? '${item['emp_name']}(${item['emp_code'] ?? item['emp_key'] ?? ''})'
                                                                    : (item['emp_code'] ??
                                                                        item[
                                                                            'emp_key'] ??
                                                                        '')),
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            14)),
                                                            contentPadding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        12),
                                                            trailing: temp
                                                                    .contains(item[
                                                                        'emp_key'])
                                                                ? const Icon(
                                                                    Icons.check,
                                                                    color: Color(
                                                                        0xFF1E3C72))
                                                                : const SizedBox(
                                                                    width: 24),
                                                            onTap: () =>
                                                                setDialogState(
                                                                    () {
                                                              final key = item[
                                                                      'emp_key'] ??
                                                                  '';
                                                              if (temp.contains(
                                                                  key))
                                                                temp.remove(
                                                                    key);
                                                              else
                                                                temp.add(key);
                                                            }),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                const Divider(height: 1),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  ctx, null),
                                                          child: const Text(
                                                              'CANCEL')),
                                                      const SizedBox(width: 8),
                                                      ElevatedButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  ctx, temp),
                                                          child:
                                                              const Text('OK')),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    );
                                  },
                                );
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
                                    child: Builder(builder: (_) {
                                      if (_selectedEmployees.isEmpty) {
                                        return const Text('Select employees',
                                            style: TextStyle(fontSize: 16));
                                      }
                                      final displayList =
                                          _selectedEmployees.map((k) {
                                        final found =
                                            _sampleEmployees.firstWhere(
                                                (e) => e['emp_key'] == k,
                                                orElse: () => {
                                                      'emp_key': k,
                                                      'emp_code': k,
                                                      'emp_name': k
                                                    });
                                        final name = found['emp_name'] ?? '';
                                        final code = found['emp_code'] ?? k;
                                        return (name.trim().isNotEmpty)
                                            ? '$name($code)'
                                            : code;
                                      }).toList();
                                      final text = displayList.length > 4
                                          ? '${displayList.sublist(0, 4).join(', ')}, ...'
                                          : displayList.join(', ');
                                      return Text(text,
                                          style: const TextStyle(fontSize: 16),
                                          overflow: TextOverflow.ellipsis);
                                    }),
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
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                        labelText: 'Leave Type',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12)),
                    items: _leaveTypes.isNotEmpty
                        ? _leaveTypes
                            .map((e) => DropdownMenuItem(
                                value: (e['leave_type_key'] ?? '').toString(),
                                child: Text(
                                    (e['leave_type_code'] ?? '').toString())))
                            .toList()
                        : <DropdownMenuItem<String>>[
                            const DropdownMenuItem(
                                value: '', child: Text('No leave types'))
                          ],
                    onChanged: (v) => setState(() => _leaveType = v ?? ''),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Select leave type'
                        : null,
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
