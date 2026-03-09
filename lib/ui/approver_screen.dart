import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';
import 'package:easytime_online/api/get_approvers_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApproverScreen extends StatefulWidget {
  final String empKey;
  const ApproverScreen({Key? key, required this.empKey}) : super(key: key);

  @override
  State<ApproverScreen> createState() => _ApproverScreenState();
}

class _ApproverScreenState extends State<ApproverScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _requests = [];
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'individual', 'group'

  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _setupData() {
    // Try to load cached data first so UI is available immediately
    _loadCachedApprovers().then((_) {
      // Fetch fresh data in background and update when ready
      _fetchApprovals();
    });
  }

  Future<void> _loadCachedApprovers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'approvers_cache_${widget.empKey}';
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> &&
            decoded.containsKey('entity_approvers')) {
          final ents = decoded['entity_approvers'];
          if (ents is List) {
            _requests = ents.map<Map<String, dynamic>>((e) {
              if (e is Map<String, dynamic>) return e;
              return Map<String, dynamic>.from(e as Map);
            }).toList();
            setState(() {
              _isLoading = true; // still loading fresh data
            });
            return;
          }
        }
      }
    } catch (_) {}

    // No cache found; ensure loading state is shown
    setState(() {
      _isLoading = true;
    });
  }

  Future<void> _fetchApprovals({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await GetApproversApi().fetchApprovers(widget.empKey);
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        if (data.containsKey('entity_approvers')) {
          final ents = data['entity_approvers'];
          if (ents is List) {
            final newRequests = ents.map<Map<String, dynamic>>((e) {
              if (e is Map<String, dynamic>) return e;
              return Map<String, dynamic>.from(e as Map);
            }).toList();

            bool changed = _requests.length != newRequests.length;
            if (!changed) {
              for (int i = 0; i < newRequests.length && !changed; i++) {
                if (jsonEncode(_requests[i]) != jsonEncode(newRequests[i]))
                  changed = true;
              }
            }

            if (changed) {
              setState(() {
                _requests = newRequests;
              });
            }

            // cache
            try {
              final prefs = await SharedPreferences.getInstance();
              final key = 'approvers_cache_${widget.empKey}';
              await prefs.setString(key, jsonEncode(data));
            } catch (_) {}
          } else {
            setState(() {
              _requests = [];
            });
          }

          setState(() {
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No approver entities returned';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result['message'] ?? 'Failed to load approvers';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load approvals: ${e.toString()}';
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
                  'My Approver',
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
            onPressed: () => _fetchApprovals(forceRefresh: true),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _searchFocus.unfocus();
          FocusScope.of(context).unfocus();
        },
        child: _requests.isNotEmpty
            ? _buildContentView()
            : _isLoading
                ? _buildInlineLoadingView()
                : _buildEmptyOrErrorView(),
      ),
    );
  }

  Widget _buildInlineLoadingView() {
    // Show a lightweight inline skeleton instead of full screen Lottie
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child:
                        CircleAvatar(radius: 24, backgroundColor: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(height: 14, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                              height: 12, width: 120, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/Lottie/attenndance_splash_animation.json',
            width: 180,
            height: 180,
          ),
          const SizedBox(height: 16),
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!.withAlpha(255),
            highlightColor: Colors.grey[100]!.withAlpha(255),
            child: const Text(
              'Loading approvals...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrErrorView() {
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Color(0xFFE53935)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Error: $_errorMessage',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _fetchApprovals(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3C72),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.checklist, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text('No pending approvals', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildContentView() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildTopControls()),

        // (Pending Approvals summary card removed per request)

        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final entity = _requests[index];
            final entityName = entity['entity_name'] ?? 'Unknown';
            final endorsementKey =
                entity['endorsement_flow_key']?.toString() ?? '';
            final approversRaw = entity['approvers'] as List<dynamic>? ?? [];

            // Apply search and filter
            final approvers = approversRaw.where((a) {
              final approver = a is Map<String, dynamic>
                  ? a
                  : Map<String, dynamic>.from(a as Map);
              final name =
                  (approver['emp_name'] ?? '').toString().toLowerCase();
              final code =
                  (approver['emp_code'] ?? '').toString().toLowerCase();
              final type = (approver['type'] ?? '').toString().toLowerCase();

              final matchesFilter = _filterType == 'all' || type == _filterType;
              final query = _searchQuery.trim().toLowerCase();
              final matchesSearch =
                  query.isEmpty || name.contains(query) || code.contains(query);

              return matchesFilter && matchesSearch;
            }).toList();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _entityIconColor(entityName)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_entityIcon(entityName),
                                color: _entityIconColor(entityName), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_prettyEntityName(entityName),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Divider(height: 1),
                      const SizedBox(height: 4),
                      // Approval flow: sequential stages horizontally; group stages show parallel nodes
                      _buildApprovalFlow(approversRaw, approvers),
                    ],
                  ),
                ),
              ),
            );
          }, childCount: _requests.length),
        ),

        // Add some bottom padding to avoid navigation bar overlap
        SliverToBoxAdapter(
            child: SizedBox(
                height: MediaQuery.of(context).viewPadding.bottom + 24)),
      ],
    );
  }

  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            focusNode: _searchFocus,
            decoration: InputDecoration(
              hintText: 'Search approvers by name or code',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filterType == 'all',
                  onSelected: (_) => setState(() => _filterType = 'all'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Individual'),
                  selected: _filterType == 'individual',
                  onSelected: (_) => setState(() => _filterType = 'individual'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Group'),
                  selected: _filterType == 'group',
                  onSelected: (_) => setState(() => _filterType = 'group'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _fetchApprovals(forceRefresh: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
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

    // Fallback: convert snake_case to Title Case
    return key
        .split(RegExp(r'[_\s]+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  IconData _entityIcon(String key) {
    switch (key) {
      case 'manual_att':
        return Icons.access_time;
      case 'miss_punch':
        return Icons.watch_later;
      case 'leave_application':
        return Icons.event_available;
      case 'coff_application':
        return Icons.local_cafe;
      case 'od_leave_application':
        return Icons.work;
      case 'overtime_apply':
        return Icons.timer;
      case 'shift_application':
        return Icons.swap_horiz;
      case 'short_leave_application':
        return Icons.timelapse;
      case 'wo_application':
        return Icons.calendar_today;
      default:
        return Icons.widgets;
    }
  }

  Color _entityIconColor(String key) {
    switch (key) {
      case 'manual_att':
        return Colors.blue.shade700;
      case 'miss_punch':
        return Colors.orange.shade700;
      case 'leave_application':
        return Colors.green.shade700;
      case 'coff_application':
        return Colors.brown.shade700;
      case 'od_leave_application':
        return Colors.purple.shade700;
      case 'overtime_apply':
        return Colors.red.shade700;
      case 'shift_application':
        return Colors.teal.shade700;
      case 'short_leave_application':
        return Colors.indigo.shade700;
      case 'wo_application':
        return Colors.cyan.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  Widget _buildApprovalFlow(
      List<dynamic> allApproversRaw, List<dynamic> visibleApproversRaw) {
    final allApprovers = allApproversRaw.map<Map<String, dynamic>>((a) {
      if (a is Map<String, dynamic>) return a;
      return Map<String, dynamic>.from(a as Map);
    }).toList();

    final visibleApprovers = visibleApproversRaw.map<Map<String, dynamic>>((a) {
      if (a is Map<String, dynamic>) return a;
      return Map<String, dynamic>.from(a as Map);
    }).toList();

    // Build original stages from the full list
    final List<List<Map<String, dynamic>>> originalStages = [];
    int i = 0;
    while (i < allApprovers.length) {
      final cur = allApprovers[i];
      final type = (cur['type'] ?? '').toString().toLowerCase();
      if (type == 'group') {
        final groupName = (cur['group_name'] ?? '').toString();
        final List<Map<String, dynamic>> members = [];
        while (i < allApprovers.length &&
            (allApprovers[i]['type'] ?? '').toString().toLowerCase() ==
                'group' &&
            (allApprovers[i]['group_name'] ?? '').toString() == groupName) {
          members.add(allApprovers[i]);
          i++;
        }
        originalStages.add(members);
      } else {
        originalStages.add([cur]);
        i++;
      }
    }

    if (originalStages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text('No approvers match your filters.',
            style: TextStyle(color: Colors.grey.shade600)),
      );
    }

    // Prepare visible set by emp_key (string) to retain original levels
    final visibleKeys =
        visibleApprovers.map((m) => (m['emp_key'] ?? '').toString()).toSet();

    // Build list of (originalStageIndex, filteredMembers) where filteredMembers not empty
    final List<Map<String, dynamic>> renderStages = [];
    for (int s = 0; s < originalStages.length; s++) {
      final stage = originalStages[s];
      final membersFiltered = stage
          .where((m) => visibleKeys.contains((m['emp_key'] ?? '').toString()))
          .toList();
      if (membersFiltered.isNotEmpty) {
        renderStages.add({'index': s, 'members': membersFiltered});
      }
    }

    if (renderStages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text('No approvers match your filters.',
            style: TextStyle(color: Colors.grey.shade600)),
      );
    }

    return SizedBox(
      height: 200,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(renderStages.length * 2 - 1, (idx) {
            if (idx.isEven) {
              final entry = renderStages[idx ~/ 2];
              final stageIndex = entry['index'] as int;
              final stageMembers =
                  entry['members'] as List<Map<String, dynamic>>;
              return _buildStageWidget(stageMembers, stageIndex + 1);
            } else {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey.shade600),
              );
            }
          }),
        ),
      ),
    );
  }

  Widget _buildStageWidget(List<Map<String, dynamic>> stage, int level) {
    final isGroup = stage.length > 1 ||
        (stage.isNotEmpty &&
            (stage.first['type'] ?? '').toString().toLowerCase() == 'group');

    const double cardSize = 160;

    final card = Container(
      width: cardSize,
      height: cardSize,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Level badge above the stage
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.blue.shade50,
              child: Text(
                level.toString(),
                style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ),
          ),
          if (isGroup)
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stage.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, idx) {
                  final approver = stage[idx];
                  return _buildApproverNode(approver, compact: true);
                },
              ),
            )
          else
            Expanded(
              child: Center(
                  child: _buildApproverNode(stage.first, compact: false)),
            ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6)),
            child: Text(
              isGroup
                  ? 'Group: ${stage.first['group_name'] ?? ''}'
                  : (stage.first['emp_name'] ?? '').toString(),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          )
        ],
      ),
    );

    return InkWell(
      onTap: () async {
        // unfocus search explicitly before opening dialog
        _searchFocus.unfocus();
        FocusScope.of(context).unfocus();
        await _showStageDetails(level, stage);
        // ensure nothing regains focus after dialog closes
        _searchFocus.unfocus();
        FocusScope.of(context).unfocus();
      },
      child: card,
    );
  }

  Future<void> _showStageDetails(
      int level, List<Map<String, dynamic>> members) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Level $level'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: members.map((m) {
                  final name = (m['emp_name'] ?? '').toString();
                  final code = (m['emp_code'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Text(code,
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
    // ensure focus is cleared after dialog closes
    FocusScope.of(context).unfocus();
  }

  Widget _buildApproverNode(Map<String, dynamic> approver,
      {bool compact = false}) {
    final name = approver['emp_name'] ?? '';
    final code = approver['emp_code'] ?? '';
    final type = (approver['type'] ?? '').toString().toLowerCase();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: compact ? 14 : 22,
          backgroundColor: Colors
              .primaries[name.toString().hashCode % Colors.primaries.length]
              .shade200,
          child: Text(
            name.toString().isNotEmpty
                ? name
                    .toString()
                    .split(' ')
                    .map((s) => s.isNotEmpty ? s[0] : '')
                    .take(2)
                    .join()
                : '?',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name.toString(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: compact ? 12 : 13)),
              if (!compact) const SizedBox(height: 4),
              if (!compact)
                Text('Code: ${code.toString()}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 11)),
            ],
          ),
        )
      ],
    );
  }
}
