import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easytime_online/api/get_emp_scope_api.dart';
import 'package:easytime_online/api/manual_punch_api.dart';

class ManualPunchApplicationScreen extends StatefulWidget {
  final String empKey;
  const ManualPunchApplicationScreen({Key? key, required this.empKey})
      : super(key: key);

  @override
  State<ManualPunchApplicationScreen> createState() =>
      _ManualPunchApplicationScreenState();
}

class _ManualPunchApplicationScreenState
    extends State<ManualPunchApplicationScreen> {
  bool _isLoading = true;
  String _error = '';

  final _formKey = GlobalKey<FormState>();

  Map<String, Map<String, dynamic>> _empMap = {};
  String? _selectedEmpKey;
  List<String> _selectedEmployees = [];
  List<Map<String, String>> _sampleEmployees = [];

  final List<String> _punchTypes = [
    'In',
    'Out',
    'Break Start',
    'Break End',
  ];
  String? _selectedPunchType;

  DateTime? _punchDate;
  TimeOfDay? _punchTime;

  final TextEditingController _dateCtrl = TextEditingController();
  final TextEditingController _timeCtrl = TextEditingController();
  final TextEditingController _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmpScope();
    _loadCachedEmployees();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmpScope() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final res = await GetEmpScopeApi().fetchEmpScope(widget.empKey);
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final emps = data['emps'] as List<dynamic>? ?? [];
        final map = <String, Map<String, dynamic>>{};
        final items = <Map<String, String>>[];
        for (final e in emps) {
          try {
            final m = e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map);
            final key = (m['emp_key'] ?? '').toString();
            map[key] = m;
            final empCode = (m['emp_code'] ?? m['emp_key'] ?? '').toString();
            final empName = (m['emp_name'] ?? empCode).toString();
            if (key.isNotEmpty) {
              items.add(
                  {'emp_key': key, 'emp_code': empCode, 'emp_name': empName});
            }
          } catch (_) {}
        }

        // Cache emp scope for reuse (like leave screen)
        try {
          final prefs = await SharedPreferences.getInstance();
          final key = 'emp_scope_cache_${widget.empKey}';
          await prefs.setString(key, jsonEncode(data));
        } catch (_) {}

        setState(() {
          _empMap = map;
          if (items.isNotEmpty) _sampleEmployees = items;
          // Do not preselect any employee by default
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = res['message'] ?? 'Failed to load employees';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _punchDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _punchDate = picked;
        _dateCtrl.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: _punchTime ?? now,
    );
    if (picked != null) {
      setState(() {
        _punchTime = picked;
        _timeCtrl.text = picked.format(context);
      });
    }
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
                                        decoration: const BoxDecoration(
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
                                if (selected) {
                                  temp.remove(key);
                                } else {
                                  temp.add(key);
                                }
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

  Future<String?> _showPunchTypeSelector() async {
    String query = '';
    final current = _selectedPunchType;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setState2) {
          final filtered = _punchTypes.where((t) {
            if (query.trim().isEmpty) return true;
            return t.toLowerCase().contains(query.toLowerCase());
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
                              child: Text('Punch Type',
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
                            hintText: 'Search punch types',
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
                          final t = filtered[idx];
                          final selected = t == current;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: selected
                                  ? const Color(0xFF1E3C72)
                                  : Colors.grey[300],
                              child: Text(
                                t.substring(0, t.length > 2 ? 2 : t.length),
                                style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Colors.black87),
                              ),
                            ),
                            title:
                                Text(t, style: const TextStyle(fontSize: 14)),
                            trailing: selected
                                ? const Icon(Icons.check,
                                    color: Color(0xFF1E3C72))
                                : null,
                            onTap: () => Navigator.pop(ctx, t),
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final empKeyValue = _selectedEmployees.isNotEmpty
        ? _selectedEmployees.join(',')
        : (_selectedEmpKey ?? '');

    final payload = {
      'emp_key': empKeyValue,
      'punch_type': _selectedPunchType ?? '',
      'punch_date': _punchDate != null
          ? '${_punchDate!.day.toString().padLeft(2, '0')}-${_punchDate!.month.toString().padLeft(2, '0')}-${_punchDate!.year.toString().padLeft(4, '0')}'
          : '',
      'punch_time': _punchTime != null
          ? '${_punchTime!.hour.toString().padLeft(2, '0')}:${_punchTime!.minute.toString().padLeft(2, '0')}'
          : '',
      'reason': _reasonCtrl.text.trim(),
      'creator_owner': widget.empKey,
    };

    setState(() => _isLoading = true);
    ManualPunchApi().submitManualPunchApplication(payload).then((res) {
      setState(() => _isLoading = false);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Manual punch submitted successfully'),
          duration: Duration(seconds: 2),
        ));
        Navigator.pop(context, true);
      } else {
        final msg = res['message'] ?? 'Failed to submit manual punch';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 3),
        ));
      }
    }).catchError((e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        duration: const Duration(seconds: 3),
      ));
    });
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
                  'Manual Punch Application',
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
            onPressed: _loadEmpScope,
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                  ? Center(child: Text('Error: $_error'))
                  : Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          const SizedBox(height: 6),
                          FormField<List<String>>(
                            initialValue: _selectedEmployees,
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Select employee(s)'
                                : null,
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 12),
                                    ),
                                    child: InkWell(
                                      onTap: () async {
                                        final res =
                                            await _showEmployeeSelector();
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
                                                    style:
                                                        TextStyle(fontSize: 16))
                                                : SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    child: Row(
                                                      children:
                                                          _selectedEmployees
                                                              .map((k) {
                                                        final found =
                                                            _sampleEmployees
                                                                .firstWhere(
                                                                    (e) =>
                                                                        e['emp_key'] ==
                                                                        k,
                                                                    orElse:
                                                                        () => {
                                                                              'emp_key': k,
                                                                              'emp_code': k,
                                                                              'emp_name': k
                                                                            });
                                                        final name =
                                                            found['emp_name'] ??
                                                                '';
                                                        final code =
                                                            found['emp_code'] ??
                                                                k;
                                                        final label = (name
                                                                .toString()
                                                                .trim()
                                                                .isNotEmpty)
                                                            ? '$name($code)'
                                                            : code;
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      4),
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
                                              size: 24,
                                              color: Colors.grey[700]),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          FormField<String>(
                            initialValue: _selectedPunchType,
                            validator: (v) => v == null || v.isEmpty
                                ? 'Please select punch type'
                                : null,
                            builder: (state) {
                              String display = 'Select punch type';
                              if ((_selectedPunchType ?? '')
                                  .trim()
                                  .isNotEmpty) {
                                display = _selectedPunchType!;
                              }
                              return InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Punch Type',
                                  errorText: state.errorText,
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                                child: InkWell(
                                  onTap: () async {
                                    final res = await _showPunchTypeSelector();
                                    if (res != null) {
                                      setState(() {
                                        _selectedPunchType = res;
                                        state.didChange(res);
                                      });
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      Expanded(
                                          child: Text(display,
                                              style: const TextStyle(
                                                  fontSize: 16))),
                                      Icon(Icons.arrow_drop_down,
                                          size: 24, color: Colors.grey[700]),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _dateCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                                labelText: 'Punch Date',
                                border: OutlineInputBorder()),
                            onTap: _pickDate,
                            validator: (v) => v == null || v.isEmpty
                                ? 'Please pick a date'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _timeCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                                labelText: 'Punch Time',
                                border: OutlineInputBorder()),
                            onTap: _pickTime,
                            validator: (v) => v == null || v.isEmpty
                                ? 'Please pick a time'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _reasonCtrl,
                            minLines: 3,
                            maxLines: 6,
                            decoration: const InputDecoration(
                                labelText: 'Reason',
                                border: OutlineInputBorder()),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Please enter reason'
                                : null,
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3C72)),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14.0),
                              child: Text('Submit Manual Punch'),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}
