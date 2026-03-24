import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easytime_online/api/today_all_punches_api.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class MyPunchesScreen extends StatefulWidget {
  final String empKey;

  const MyPunchesScreen({super.key, required this.empKey});

  @override
  State<MyPunchesScreen> createState() => _MyPunchesScreenState();
}

class _MyPunchesScreenState extends State<MyPunchesScreen> {
  final TodayAllPunchesApi _api = TodayAllPunchesApi();
  final DateFormat _dateApiFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _dateUiFormat = DateFormat('dd MMM yyyy');
  final DateFormat _timeUiFormat = DateFormat('hh:mm a');

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String _error = '';
  String _baseUrl = '';
  List<Map<String, dynamic>> _punches = <Map<String, dynamic>>[];
  final Map<String, Future<Uint8List?>> _photoBytesCache = {};

  @override
  void initState() {
    super.initState();
    _loadPunches();
  }

  Future<void> _loadPunches() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    final response = await _api.fetchTodayAllPunches(
      empKey: widget.empKey,
      date: _dateApiFormat.format(_selectedDate),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (response['success'] == true) {
        final list = response['punch_list'] as List<dynamic>? ?? [];
        _punches = list
            .map(
              (e) => e is Map<String, dynamic>
                  ? e
                  : Map<String, dynamic>.from(e as Map),
            )
            .toList();
        _baseUrl = (response['base_url'] ?? '').toString();
        _error = '';
      } else {
        _punches = <Map<String, dynamic>>[];
        _error = response['message']?.toString() ?? 'Failed to load punches';
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
    });

    await _loadPunches();
  }

  DateTime? _parseDateTime(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;
    try {
      return DateTime.tryParse(input);
    } catch (_) {
      return null;
    }
  }

  String _getPhotoUrl(String path) {
    final photoPath = path.trim();
    if (photoPath.isEmpty) return '';

    if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
      return photoPath;
    }

    final baseUrl = _baseUrl.trim();
    if (baseUrl.isEmpty) return '';

    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPhotoPath =
        photoPath.startsWith('/') ? photoPath.substring(1) : photoPath;

    return '$cleanBase/$cleanPhotoPath';
  }

  Widget _buildPhotoPreview(String photoPath) {
    final photoUrl = _getPhotoUrl(photoPath);
    if (photoUrl.isEmpty) {
      return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        color: const Color(0xFFF3F4F6),
        child: const Text(
          'Preview URL not available',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: photoUrl,
      height: 150,
      width: double.infinity,
      fit: BoxFit.cover,
      httpHeaders: {
        'Accept': 'image/*,*/*',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/122.0.0.0 Mobile Safari/537.36',
        'Referer': _baseUrl,
      },
      placeholder: (context, url) => Container(
        height: 150,
        color: const Color(0xFFF3F4F6),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      ),
      errorWidget: (context, url, error) => FutureBuilder<Uint8List?>(
        future: _photoBytesCache.putIfAbsent(
            photoUrl, () => _downloadImageBytes(photoUrl)),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Container(
              height: 150,
              color: const Color(0xFFF3F4F6),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            );
          }

          final bytes = snap.data;
          if (bytes != null && bytes.isNotEmpty) {
            return Image.memory(
              bytes,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            );
          }

          return Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFFF3F4F6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Photo preview unavailable',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 4),
                Text(
                  photoUrl,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF1E3C72)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final uri = Uri.tryParse(photoUrl);
                        if (uri != null) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      child: const Text('Open URL'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final probe = await _probeUrl(photoUrl);
                        if (!mounted) return;
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Probe Result'),
                            content: Text(probe),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('OK'))
                            ],
                          ),
                        );
                      },
                      child: const Text('Probe'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Uint8List?> _downloadImageBytes(String url) async {
    try {
      final uri = Uri.parse(url);
      final resp = await http.get(uri, headers: {
        'Accept': 'image/*,*/*',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/122.0.0.0 Mobile Safari/537.36',
        'Referer': _baseUrl,
      }).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        return resp.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Widget _buildPunchCard(Map<String, dynamic> punch) {
    final dateTimeRaw = (punch['datetime'] ?? '').toString();
    final dt = _parseDateTime(dateTimeRaw);
    final empCode = (punch['emp_code'] ?? '').toString();
    final deviceCode = (punch['device_code'] ?? '').toString();
    final processNote = (punch['process_note'] ?? '').toString();

    Map<String, dynamic>? inOut;
    if (punch['in_out_punch'] is Map<String, dynamic>) {
      inOut = punch['in_out_punch'] as Map<String, dynamic>;
    } else if (punch['in_out_punch'] is Map) {
      inOut = Map<String, dynamic>.from(punch['in_out_punch'] as Map);
    }

    final location = (inOut?['location'] ?? '').toString();
    final remark = (inOut?['remark'] ?? '').toString();
    final photoPath = (inOut?['photo_path'] ?? '').toString();
    final photoUrl = _getPhotoUrl(photoPath);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3C72).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.fingerprint,
                    color: Color(0xFF1E3C72),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dt != null
                            ? _timeUiFormat.format(dt)
                            : (dateTimeRaw.isNotEmpty ? dateTimeRaw : '-'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3C72),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dt != null
                            ? _dateUiFormat.format(dt)
                            : _dateUiFormat.format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (empCode.isNotEmpty && empCode.toLowerCase() != 'null')
                  _buildTag('Emp: $empCode', const Color(0xFFEEF2FF)),
                if (deviceCode.isNotEmpty && deviceCode.toLowerCase() != 'null')
                  _buildTag('Device: $deviceCode', const Color(0xFFE8F7EF)),
                _buildTag(
                  'Log: ${punch['att_log_key'] ?? '-'}',
                  const Color(0xFFFFF4E5),
                ),
              ],
            ),
            if (processNote.isNotEmpty &&
                processNote.toLowerCase() != 'null') ...[
              const SizedBox(height: 10),
              _buildInfoRow(Icons.info_outline, processNote),
            ],
            if (location.isNotEmpty && location.toLowerCase() != 'null') ...[
              const SizedBox(height: 10),
              _buildInfoRow(Icons.location_on_outlined, location),
            ],
            if (remark.isNotEmpty && remark.toLowerCase() != 'null') ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.edit_note_outlined, remark),
            ],
            if (photoPath.isNotEmpty && photoPath.toLowerCase() != 'null') ...[
              const SizedBox(height: 8),
              if (photoUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildPhotoPreview(photoPath),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<String> _probeUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final head = await http.head(uri).timeout(const Duration(seconds: 8));
      return 'status: ${head.statusCode}\ncontent-length: ${head.contentLength ?? 'unknown'}\nheaders: ${head.headers}';
    } catch (e) {
      return 'probe error: $e';
    }
  }

  Widget _buildTag(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF374151),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E3C72),
        title: const Text('My Punches', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadPunches,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Date',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dateApiFormat.format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3C72),
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Change'),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadPunches,
              child: _isLoading
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 180),
                        Center(child: CircularProgressIndicator()),
                      ],
                    )
                  : _error.isNotEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Text(
                                  _error,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ),
                          ],
                        )
                      : _punches.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 120),
                                Center(
                                    child:
                                        Text('No punches found for this date')),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 12),
                              itemCount: _punches.length,
                              itemBuilder: (context, index) {
                                return _buildPunchCard(_punches[index]);
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
