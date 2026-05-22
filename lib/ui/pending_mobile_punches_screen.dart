import 'package:flutter/material.dart';
import 'package:easytime_online/api/pending_mobile_punches_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingMobilePunchesScreen extends StatefulWidget {
  final String approverKey;
  const PendingMobilePunchesScreen({Key? key, required this.approverKey})
      : super(key: key);

  /// Convenience helper: attempts to resolve approverKey from preferences
  /// if not provided, then navigates to the screen.
  static Future<void> show(BuildContext context, {String? approverKey}) async {
    String? keyToUse = approverKey;
    if (keyToUse == null || keyToUse.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      keyToUse = prefs.getString('emp_key') ?? prefs.getString('approver_key');
    }
    if (keyToUse == null || keyToUse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Approver key not available')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PendingMobilePunchesScreen(approverKey: keyToUse!)),
    );
  }

  @override
  State<PendingMobilePunchesScreen> createState() =>
      _PendingMobilePunchesScreenState();
}

class _PendingMobilePunchesScreenState
    extends State<PendingMobilePunchesScreen> {
  bool _isLoading = false;
  String _error = '';
  List<Map<String, dynamic>> _items = [];
  String _baseApiUrl = '';
  final Map<String, bool> _swipedState = {};
  final Duration _swipeDuration = const Duration(milliseconds: 350);
  bool _suppressNextTap = false;
  // Track selection state for checkbox on each item
  final Set<String> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _loadBaseUrl();
    _load();
  }

  Future<void> _loadBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString('base_api_url') ?? '';
      setState(() {
        _baseApiUrl = url;
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final res = await PendingMobilePunchesApi()
          .fetchPendingMobilePunches(approverKey: widget.approverKey);

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        List<dynamic> list = [];

        if (data is Map &&
            data.containsKey('pending') &&
            data['pending'] is List) {
          list = data['pending'] as List<dynamic>;
        } else if (data is Map && data.containsKey('data')) {
          final d2 = data['data'];
          if (d2 is Map && d2.containsKey('pending') && d2['pending'] is List) {
            list = d2['pending'] as List<dynamic>;
          } else if (d2 is List) {
            list = d2;
          }
        } else if (data is List) {
          list = data;
        }

        final parsed = list.map<Map<String, dynamic>>((e) {
          if (e is Map<String, dynamic>) return e;
          return Map<String, dynamic>.from(e as Map);
        }).toList();

        parsed.sort((a, b) {
          DateTime pa = DateTime.tryParse((a['datetime'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          DateTime pb = DateTime.tryParse((b['datetime'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return pb.compareTo(pa);
        });

        setState(() {
          _items = parsed;
          _isLoading = false;
          // initialize swipe state
          _swipedState.clear();
          for (int i = 0; i < _items.length; i++) {
            final it = _items[i];
            final k = (it['in_out_punch_key'] ??
                    it['in_out_punch'] ??
                    it['in_out_punch_id'] ??
                    i)
                .toString();
            _swipedState[k] = false;
          }
        });
        return;
      } else {
        setState(() {
          _isLoading = false;
          _error = res['message'] ?? 'Failed to load pending mobile punches';
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

  String _formatDateTime(String raw) {
    final s = raw.toString().trim();
    if (s.isEmpty) return '';
    try {
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        final y = dt.year.toString().padLeft(4, '0');
        final m = dt.month.toString().padLeft(2, '0');
        final d = dt.day.toString().padLeft(2, '0');
        final hh = dt.hour.toString().padLeft(2, '0');
        final mm = dt.minute.toString().padLeft(2, '0');
        return '$y-$m-$d $hh:$mm';
      }
    } catch (_) {}
    return s;
  }

  Widget _buildThumbnail(String? path) {
    final p = path?.trim() ?? '';
    if (p.isEmpty) {
      return const CircleAvatar(
        radius: 20,
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.photo, color: Colors.white, size: 18),
      );
    }

    // Resolve possible absolute or relative URL
    final photoUrl = _getPhotoUrl(p);
    if (photoUrl.isNotEmpty &&
        (photoUrl.startsWith('http://') || photoUrl.startsWith('https://'))) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, st) {
            // fallback to asset if provided path looks like an asset reference
            if (p.startsWith('assets/')) {
              return Image.asset(
                p,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (c2, e2, s2) => Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Colors.blueAccent),
                  child: const Icon(Icons.photo, color: Colors.white, size: 18),
                ),
              );
            }
            return Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.blueAccent),
              child: const Icon(Icons.photo, color: Colors.white, size: 18),
            );
          },
        ),
      );
    }

    if (p.startsWith('assets/')) {
      return ClipOval(
        child: Image.asset(
          p,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, st) => Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Colors.blueAccent),
            child: const Icon(Icons.photo, color: Colors.white, size: 18),
          ),
        ),
      );
    }

    // fallback placeholder
    return const CircleAvatar(
      radius: 20,
      backgroundColor: Colors.blueAccent,
      child: Icon(Icons.photo, color: Colors.white, size: 18),
    );
  }

  String _getPhotoUrl(String path) {
    final photoPath = path.trim();
    if (photoPath.isEmpty) return '';
    if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
      return photoPath;
    }
    final base = _baseApiUrl.trim();
    if (base.isEmpty) return '';
    final cleanBase =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final cleanPath =
        photoPath.startsWith('/') ? photoPath.substring(1) : photoPath;
    return '$cleanBase/$cleanPath';
  }

  void _showPhotoPreview(String path) {
    final p = path.trim();
    final photoUrl = _getPhotoUrl(p);
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              color: Colors.black,
              child: InteractiveViewer(
                child: Builder(builder: (ctx) {
                  // Prefer network URL when available
                  if (photoUrl.isNotEmpty &&
                      (photoUrl.startsWith('http://') ||
                          photoUrl.startsWith('https://'))) {
                    return Image.network(
                      photoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) {
                        // network failed — if original path looks like an asset, try it
                        if (p.startsWith('assets/')) {
                          return Image.asset(
                            p,
                            fit: BoxFit.contain,
                            errorBuilder: (c2, e2, s2) => const Center(
                                child: Icon(Icons.broken_image,
                                    color: Colors.white)),
                          );
                        }
                        return const Center(
                            child:
                                Icon(Icons.broken_image, color: Colors.white));
                      },
                    );
                  }

                  // If path is asset-like, try asset with network fallback
                  if (p.startsWith('assets/')) {
                    return Image.asset(
                      p,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) {
                        if (photoUrl.isNotEmpty &&
                            (photoUrl.startsWith('http://') ||
                                photoUrl.startsWith('https://'))) {
                          return Image.network(
                            photoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (c2, e2, s2) => const Center(
                                child: Icon(Icons.broken_image,
                                    color: Colors.white)),
                          );
                        }
                        return const Center(
                            child:
                                Icon(Icons.broken_image, color: Colors.white));
                      },
                    );
                  }

                  // Last resort: show broken image
                  return const Center(
                      child: Icon(Icons.broken_image, color: Colors.white));
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRecordDetail(Map<String, dynamic> a) async {
    final location = (a['location'] ?? '').toString();
    final remark = (a['remark'] ?? '').toString();
    final datetime = _formatDateTime(a['datetime'] ?? a['date'] ?? '');
    final photo = (a['photo_path'] ?? '').toString();
    final empName = (a['emp_name'] ??
            a['emp_fullname'] ??
            a['employee_name'] ??
            a['name'] ??
            a['emp'] ??
            a['emp_key'] ??
            '')
        .toString()
        .trim();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Punch Detail'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (empName.isNotEmpty) Text('Employee: $empName'),
              if (location.isNotEmpty) Text('Location: $location'),
              if (remark.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Remark: $remark')),
              if (datetime.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Time: $datetime')),
              if (photo.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: SizedBox(
                    height: 160,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        _showPhotoPreview(photo);
                      },
                      child: photo.startsWith('assets/')
                          ? Image.asset(
                              photo,
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) {
                                final alt = _getPhotoUrl(photo);
                                if (alt.isNotEmpty &&
                                    (alt.startsWith('http://') ||
                                        alt.startsWith('https://'))) {
                                  return Image.network(
                                    alt,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c2, e2, s2) =>
                                        const Icon(Icons.broken_image),
                                  );
                                }
                                return const Icon(Icons.broken_image);
                              },
                            )
                          : Image.network(_getPhotoUrl(photo),
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) =>
                                  const Icon(Icons.broken_image)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close')),
        ],
      ),
    );
  }

  // Helper: shows a bottom-sheet text input and preserves the
  // TextEditingController across rebuilds so keyboard/back presses
  // don't erase the typed text.
  Future<String?> _showTextInputModal({
    required String title,
    String hint = '',
    String confirmLabel = 'OK',
    bool autofocus = true,
  }) async {
    final controller = TextEditingController();
    try {
      final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
        builder: (ctx) {
          final mq = MediaQuery.of(ctx);
          final maxH = mq.size.height * 0.6;
          return Padding(
            padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
            child: SafeArea(
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
                        Text(title),
                        const SizedBox(height: 8),
                        TextField(
                          controller: controller,
                          autofocus: autofocus,
                          maxLines: 5,
                          decoration: InputDecoration(
                              hintText: hint,
                              border: const OutlineInputBorder()),
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
                                  onPressed: () => Navigator.of(ctx)
                                      .pop(controller.text.trim()),
                                  child: Text(confirmLabel)),
                            ])
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
      return result;
    } finally {
      controller.dispose();
    }
  }

  Future<bool> _performApproveApi(
      List<String> keys, bool approve, String note) async {
    // show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      debugPrint(
          'UI -> approveMobilePunch call: keys=$keys approve=$approve note="$note" approver=${widget.approverKey}');
    } catch (_) {}
    final res = await PendingMobilePunchesApi().approveMobilePunch(
        approverKey: widget.approverKey,
        inOutPunchKeys: keys,
        approve: approve,
        note: note);
    try {
      debugPrint('UI <- approveMobilePunch response: $res');
    } catch (_) {}
    Navigator.of(context).pop();

    if (res['success'] == true) {
      setState(() {
        _items.removeWhere((it) {
          final k = (it['in_out_punch_key'] ??
                  it['in_out_punch'] ??
                  it['in_out_punch_id'])
              .toString();
          return keys.contains(k);
        });
        for (final k in keys) {
          _swipedState.remove(k);
          _selectedItems.remove(k);
        }
      });
      final msg = res['message'] ?? 'Done';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return true;
    } else {
      final msg = res['message'] ?? 'Failed';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Action failed: $msg')));
      return false;
    }
  }

  Future<void> _approveSingle(String itemKey, Map<String, dynamic> a) async {
    // Ask for an optional note, then call API
    final note = await _showTextInputModal(
      title: 'Please enter note for approval (optional)',
      hint: 'Approval note',
      confirmLabel: 'Approve',
      autofocus: true,
    );

    if (note == null) return;
    await _performApproveApi([itemKey], true, note);
  }

  Future<void> _rejectSingle(String itemKey, Map<String, dynamic> a) async {
    final reason = await _showTextInputModal(
      title: 'Please enter reason for rejection',
      hint: 'Rejection reason',
      confirmLabel: 'Reject',
      autofocus: true,
    );

    if (reason == null || reason.trim().isEmpty) return;

    await _performApproveApi([itemKey], false, reason);
  }

  Future<void> _bulkApproveSelected() async {
    final count = _selectedItems.length;
    // ask for optional note for bulk approval
    final note = await _showTextInputModal(
      title: 'Approve $count selected mobile punch(es)',
      hint: 'Note',
      confirmLabel: 'Approve',
      autofocus: true,
    );

    if (note == null) return;
    final keys = _selectedItems.toList();
    await _performApproveApi(keys, true, note);
  }

  Future<void> _bulkRejectSelected() async {
    final count = _selectedItems.length;
    final reason = await _showTextInputModal(
      title: 'Reject $count selected mobile punch(s)',
      hint: 'Rejection reason',
      confirmLabel: 'Reject',
      autofocus: true,
    );

    if (reason == null || reason.trim().isEmpty) return;

    final keys = _selectedItems.toList();
    await _performApproveApi(keys, false, reason);
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
                  'Manage Mobile Punches',
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
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: _selectedItems.isNotEmpty
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'bulk_approve',
                  onPressed: _bulkApproveSelected,
                  backgroundColor: Colors.green,
                  tooltip: 'Approve selected',
                  child: const Icon(Icons.check),
                ),
                const SizedBox(height: 10),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 6),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _isLoading
                    ? ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: 3,
                        itemBuilder: (_, __) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(children: [
                                    const CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.blueAccent,
                                        child: Icon(Icons.edit,
                                            color: Colors.white, size: 18)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Container(
                                              height: 12,
                                              color: Colors.grey[300]),
                                          const SizedBox(height: 8),
                                          Container(
                                              height: 10,
                                              width: 80,
                                              color: Colors.grey[300])
                                        ])),
                                  ]),
                                ),
                              ),
                            ))
                    : _error.isNotEmpty
                        ? ListView(
                            children: [Center(child: Text('Error: $_error'))])
                        : _items.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                    Center(
                                        child:
                                            Text('No pending mobile punches'))
                                  ])
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, index) {
                                  final a = _items[index];

                                  final location =
                                      (a['location'] ?? '').toString();
                                  final remark = (a['remark'] ?? '').toString();
                                  final datetime = _formatDateTime(
                                      a['datetime'] ?? a['date'] ?? '');
                                  final photo =
                                      (a['photo_path'] ?? '').toString();
                                  final status = (a['approval_status_name'] ??
                                          a['approval_status'] ??
                                          a['approval_status_key'] ??
                                          '')
                                      .toString();
                                  final punchType =
                                      (a['punch_type_key'] ?? a['punch_type'])
                                          .toString();
                                  final emp = (a['emp_key'] ?? a['emp_code'])
                                      .toString();
                                  final empName = (a['emp_name'] ??
                                          a['emp_fullname'] ??
                                          a['employee_name'] ??
                                          a['name'] ??
                                          a['emp'] ??
                                          '')
                                      .toString()
                                      .trim();
                                  final empDisplay =
                                      empName.isNotEmpty ? empName : emp;

                                  final itemKey = (a['in_out_punch_key'] ??
                                          a['in_out_punch'] ??
                                          a['in_out_punch_id'] ??
                                          index)
                                      .toString();
                                  final isSwiped =
                                      _swipedState[itemKey] == true;

                                  return Stack(
                                    children: [
                                      // background action bar
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

                                                      if (_selectedItems
                                                          .isNotEmpty) {
                                                        for (int j = 0;
                                                            j < _items.length;
                                                            j++) {
                                                          final it2 = _items[j];
                                                          final k2 = (it2[
                                                                      'in_out_punch_key'] ??
                                                                  it2['in_out_punch'] ??
                                                                  it2['in_out_punch_id'] ??
                                                                  j)
                                                              .toString();
                                                          _swipedState[k2] =
                                                              true;
                                                        }
                                                      } else {
                                                        _swipedState.clear();
                                                      }
                                                    });
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // view
                                              Container(
                                                decoration: const BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle),
                                                child: IconButton(
                                                  icon: Icon(
                                                      Icons.remove_red_eye,
                                                      size: 20,
                                                      color: _selectedItems
                                                              .contains(itemKey)
                                                          ? Colors.grey
                                                          : null),
                                                  onPressed: _selectedItems
                                                          .contains(itemKey)
                                                      ? null
                                                      : () {
                                                          _showRecordDetail(a);
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
                                                  icon: Icon(Icons.check,
                                                      color: _selectedItems
                                                              .contains(itemKey)
                                                          ? Colors.grey
                                                          : Colors.green,
                                                      size: 20),
                                                  onPressed: _selectedItems
                                                          .contains(itemKey)
                                                      ? null
                                                      : () {
                                                          _approveSingle(
                                                              itemKey, a);
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
                                                  icon: Icon(Icons.close,
                                                      color: _selectedItems
                                                              .contains(itemKey)
                                                          ? Colors.grey
                                                          : Colors.red,
                                                      size: 20),
                                                  onPressed: _selectedItems
                                                          .contains(itemKey)
                                                      ? null
                                                      : () async {
                                                          await _rejectSingle(
                                                              itemKey, a);
                                                        },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // foreground sliding card
                                      AnimatedSlide(
                                        offset: isSwiped
                                            ? const Offset(-0.8, 0)
                                            : Offset.zero,
                                        duration: _swipeDuration,
                                        curve: Curves.easeInOut,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () async {
                                            if (_suppressNextTap) {
                                              setState(() {
                                                _suppressNextTap = false;
                                              });
                                              return;
                                            }
                                            final currently =
                                                _swipedState[itemKey] == true;
                                            setState(() {
                                              if (!currently) {
                                                _swipedState.clear();
                                                _swipedState[itemKey] = true;
                                              } else {
                                                _swipedState[itemKey] = false;
                                              }
                                            });
                                            await Future.delayed(
                                                _swipeDuration);
                                          },
                                          child: Card(
                                            elevation: 1,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(12.0),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  GestureDetector(
                                                      onTap: () {
                                                        if (photo.isNotEmpty) {
                                                          setState(() {
                                                            _suppressNextTap =
                                                                true;
                                                          });
                                                          _showPhotoPreview(
                                                              photo);
                                                        }
                                                      },
                                                      child: _buildThumbnail(
                                                          photo)),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                                location.isNotEmpty
                                                                    ? location
                                                                    : 'Punch for $empDisplay',
                                                                style: const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    fontSize:
                                                                        14),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis),
                                                            if (location
                                                                    .isNotEmpty &&
                                                                empDisplay
                                                                    .isNotEmpty)
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        top:
                                                                            4.0),
                                                                child: Text(
                                                                    empDisplay,
                                                                    style: const TextStyle(
                                                                        color: Colors
                                                                            .black54,
                                                                        fontSize:
                                                                            12)),
                                                              ),
                                                          ],
                                                        ),
                                                        if (remark.isNotEmpty)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    top: 6.0),
                                                            child: Text(remark,
                                                                style: const TextStyle(
                                                                    color: Colors
                                                                        .grey),
                                                                maxLines: 2,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis),
                                                          ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  top: 8.0),
                                                          child: Text(datetime,
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .black54,
                                                                  fontSize:
                                                                      12)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                          punchType.isNotEmpty
                                                              ? punchType
                                                              : (a['is_out'] ==
                                                                      1
                                                                  ? 'OUT'
                                                                  : 'IN'),
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                      const SizedBox(height: 8),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 6),
                                                        decoration: BoxDecoration(
                                                            color: Colors
                                                                .grey[200],
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12)),
                                                        child: Text(
                                                            status.isNotEmpty
                                                                ? status
                                                                : '-'),
                                                      ),
                                                    ],
                                                  )
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
