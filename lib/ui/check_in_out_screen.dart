import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easytime_online/api/today_punches_api.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:easytime_online/ui/dashboard_screen.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:easytime_online/services/location_service.dart';

// A simple Check In / Check Out screen with photo, location and remark fields

class CheckInOutScreen extends StatefulWidget {
  final String headerTitle;
  final String empKey;

  const CheckInOutScreen(
      {super.key, required this.headerTitle, required this.empKey});

  @override
  State<CheckInOutScreen> createState() => _CheckInOutScreenState();
}

class _CheckInOutScreenState extends State<CheckInOutScreen> {
  final TodayPunchesApi _todayPunchesApi = TodayPunchesApi();
  StreamSubscription? _punchSubscription;

  String _inPunch = '';
  String _outPunch = '';
  bool _isLoading = true;
  bool _isSubmitting = false;
  File? _photoFile;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Listen to global punch stream (if any part of the app emits updates)
    _punchSubscription = _todayPunchesApi.punchStream.listen((result) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        final extracted = _extractPunches(result);
        _inPunch = _formatToHHMM(extracted['in']);
        _outPunch = _formatToHHMM(extracted['out']);
      });
    });

    // Fetch today's punches once for initial state
    _todayPunchesApi.fetchTodayPunches(widget.empKey).then((res) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        final extracted = _extractPunches(res);
        _inPunch = _formatToHHMM(extracted['in']);
        _outPunch = _formatToHHMM(extracted['out']);
      });
    });

    // Fetch default location and fill into location field
    _fetchDefaultLocation();
    // Open front camera (selfie) after first frame so user can take photo immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCamera();
    });
  }

  Future<void> _fetchDefaultLocation() async {
    try {
      // Use default API key configured in LocationService
      final res = await LocationService.getLocationDetails();
      if (res['error'] != null) {
        return;
      }
      final address = (res['address'] as String?) ?? '';
      final lat = res['lat'];
      final lng = res['lng'];

      setState(() {
        if (address.isNotEmpty) {
          _locationController.text = address;
        } else if (lat != null && lng != null) {
          _locationController.text = '$lat,$lng';
        }
      });
    } catch (e) {}
  }

  @override
  void dispose() {
    try {
      _cameraController?.dispose();
    } catch (_) {}
    _punchSubscription?.cancel();
    _locationController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _performCheckIn() async {
    await _captureFromPreviewIfNeeded();
    await _submitPunch(punchTypeKey: 1, isOut: 0);
  }

  Future<void> _performCheckOut() async {
    await _captureFromPreviewIfNeeded();
    await _submitPunch(punchTypeKey: 2, isOut: 1);
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile? picked = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          preferredCameraDevice: CameraDevice.front);
      if (picked != null) {
        setState(() {
          _photoFile = File(picked.path);
        });
        // Photo captured — do not show toast as per user preference.
      }
    } catch (e) {
      _showMessage('Failed to capture photo');
    }
  }

  // Initialize front camera for live preview embedded in page.
  Future<void> _initCamera() async {
    try {
      // small delay to ensure UI is ready
      await Future.delayed(const Duration(milliseconds: 150));
      // get available cameras
      _cameras = await availableCameras();
      // prefer front camera
      CameraDescription? front;
      for (var cam in _cameras!) {
        if (cam.lensDirection == CameraLensDirection.front) {
          front = cam;
          break;
        }
      }
      final camToUse = front ?? (_cameras!.isNotEmpty ? _cameras!.first : null);
      if (camToUse == null) return;
      _cameraController = CameraController(camToUse, ResolutionPreset.medium,
          enableAudio: false);
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      // leave fallback to image_picker
      setState(() {
        _isCameraInitialized = false;
      });
    }
  }

  // Capture current frame from preview (preferred) or fallback to picker
  Future<void> _captureFromPreviewIfNeeded() async {
    if (_photoFile != null) return;
    try {
      if (_cameraController != null && _isCameraInitialized) {
        final XFile xf = await _cameraController!.takePicture();
        setState(() {
          _photoFile = File(xf.path);
        });
        return;
      }
    } catch (e) {}
    // fallback to image picker flow
    await _capturePhoto();
  }

  // Try to extract IN/OUT from various API response shapes
  Map<String, String?> _extractPunches(dynamic res) {
    try {
      // If response already contains normalized keys
      if (res is Map) {
        // If API returned top-level in_punch/out_punch
        if (res.containsKey('in_punch') || res.containsKey('out_punch')) {
          return {
            'in': res['in_punch']?.toString(),
            'out': res['out_punch']?.toString(),
          };
        }

        // If raw_response nested
        if (res.containsKey('raw_response')) {
          final raw = res['raw_response'];
          final extracted = _extractPunches(raw);
          if ((extracted['in']?.isNotEmpty ?? false) ||
              (extracted['out']?.isNotEmpty ?? false)) return extracted;
        }

        // Common alternative keys
        final inCandidates = [
          'in_time',
          'in',
          'intime',
          'inPunch',
          'in_punch_time',
          'in_punch_time_str'
        ];
        final outCandidates = [
          'out_time',
          'out',
          'outtime',
          'outPunch',
          'out_punch_time',
          'out_punch_time_str'
        ];

        String? inVal = _findFirstStringValue(res, inCandidates);
        String? outVal = _findFirstStringValue(res, outCandidates);
        if ((inVal?.isNotEmpty ?? false) || (outVal?.isNotEmpty ?? false)) {
          return {'in': inVal, 'out': outVal};
        }

        // If response is a map with a single data object or list
        for (var key in res.keys) {
          final val = res[key];
          if (val is Map || val is List) {
            final extracted = _extractPunches(val);
            if ((extracted['in']?.isNotEmpty ?? false) ||
                (extracted['out']?.isNotEmpty ?? false)) return extracted;
          }
        }
      } else if (res is List) {
        for (var item in res) {
          final extracted = _extractPunches(item);
          if ((extracted['in']?.isNotEmpty ?? false) ||
              (extracted['out']?.isNotEmpty ?? false)) return extracted;
        }
      }
    } catch (e) {}

    return {'in': null, 'out': null};
  }

  // Submit punch to server with encrypted photo
  Future<void> _submitPunch(
      {required int punchTypeKey, required int isOut}) async {
    setState(() {
      _isSubmitting = true;
    });
    try {
      // Submitting... (toast suppressed to avoid extra snackbars)

      final baseUrl = await TodayPunchesApi.getBaseApiUrl();
      var cleanUrl = baseUrl;
      if (cleanUrl.endsWith('/'))
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      final apiUrl = Uri.parse('$cleanUrl/api/in_out_punch');

      // Prepare photo (encrypt then base64)
      String photoEncoded = '';
      // Raw AES parameters to send to server (32-char key, 16-char IV)
      String encKey = '12345678901234567890123456789012';
      String encIv = '1234567890123456';
      if (_photoFile != null) {
        final bytes = await _photoFile!.readAsBytes();
        final key = encrypt_pkg.Key.fromUtf8(encKey);
        final iv = encrypt_pkg.IV.fromUtf8(encIv);
        final encrypter = encrypt_pkg.Encrypter(
            encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc));
        final encrypted = encrypter.encryptBytes(bytes, iv: iv);
        photoEncoded = encrypted.base64;
      }

      final now = DateTime.now();
      final formattedDateTime =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final bodyMap = {
        'emp_key': widget.empKey,
        'datetime': formattedDateTime,
        'punch_type_key': punchTypeKey.toString(),
        'is_out': isOut.toString(),
        'location_name': _locationController.text.trim(),
        'photo': photoEncoded,
        'remark': _remarkController.text.trim(),
        'enc_key': encKey,
        'enc_iv': encIv,
      };

      if (false) {
        bodyMap.forEach((key, value) {
          try {
            if (key == 'photo' &&
                value != null &&
                value.toString().length > 100) {
              final v = value.toString();
            } else {}
          } catch (e) {}
        });
      }

      // Try form-encoded POST first (some endpoints expect this)
      try {
        final resp = await http
            .post(apiUrl,
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: bodyMap)
            .timeout(const Duration(seconds: 60));

        if (false) {}

        if (resp.statusCode == 200) {
          final resJson = jsonDecode(resp.body);
          final bool success = _responseSuccess(resJson);
          if (success) {
            final extracted = _extractPunches(resJson);
            setState(() {
              _inPunch = _formatToHHMM(extracted['in']);
              _outPunch = _formatToHHMM(extracted['out']);
            });
            // Refresh punch stream to notify all listeners
            _todayPunchesApi.refreshPunches(widget.empKey);
            if (!mounted) return;
            Navigator.pop(context, {'emp_key': widget.empKey});
            return;
          } else {
            _showMessage(resJson['message']?.toString() ?? 'Submit failed');
          }
        } else {
          _showMessage('Submit failed: ${resp.statusCode}');
        }
      } catch (e) {}

      // Fallback: Try JSON POST
      try {
        final resp2 = await http
            .post(apiUrl,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(bodyMap))
            .timeout(const Duration(seconds: 60));

        if (false) {}

        if (resp2.statusCode == 200) {
          final resJson = jsonDecode(resp2.body);
          final bool success = _responseSuccess(resJson);
          if (success) {
            final extracted = _extractPunches(resJson);
            setState(() {
              _inPunch = _formatToHHMM(extracted['in']);
              _outPunch = _formatToHHMM(extracted['out']);
            });
            // Refresh punch stream to notify all listeners
            _todayPunchesApi.refreshPunches(widget.empKey);
            if (!mounted) return;
            Navigator.pop(context, {'emp_key': widget.empKey});
            return;
          } else {
            _showMessage(resJson['message']?.toString() ?? 'Submit failed');
          }
        } else {
          _showMessage('Submit failed: ${resp2.statusCode}');
        }
      } catch (e) {}

      // If both form and JSON attempts failed due to timeout/network, try multipart streaming upload
      try {
        final request = http.MultipartRequest('POST', apiUrl);
        // add fields
        bodyMap.forEach((k, v) {
          if (v != null) request.fields[k] = v.toString();
        });

        // if we have a photo file, attach raw bytes (streamed)
        if (_photoFile != null) {
          final bytes = await _photoFile!.readAsBytes();
          final multipartFile = http.MultipartFile.fromBytes('photo', bytes,
              filename: 'photo.jpg');
          request.files.add(multipartFile);
        }

        final streamedResp =
            await request.send().timeout(const Duration(seconds: 60));
        final resp3 = await http.Response.fromStream(streamedResp);
        if (false) {}

        if (resp3.statusCode == 200) {
          final resJson = jsonDecode(resp3.body);
          final bool success = _responseSuccess(resJson);
          if (success) {
            final extracted = _extractPunches(resJson);
            setState(() {
              _inPunch = _formatToHHMM(extracted['in']);
              _outPunch = _formatToHHMM(extracted['out']);
            });
            // Refresh punch stream to notify all listeners
            _todayPunchesApi.refreshPunches(widget.empKey);
            if (!mounted) return;
            Navigator.pop(context, {'emp_key': widget.empKey});
            return;
          } else {
            _showMessage(resJson['message']?.toString() ?? 'Submit failed');
          }
        } else {
          _showMessage('Submit failed: ${resp3.statusCode}');
        }
      } catch (e) {}

      _showMessage('Submit error');
    } catch (e) {
      _showMessage('Submit exception');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String? _findFirstStringValue(Map m, List<String> keys) {
    for (var k in keys) {
      if (m.containsKey(k) && m[k] != null) return m[k].toString();
      // also check case-insensitive keys
      for (var entry in m.entries) {
        if (entry.key is String &&
            entry.key.toString().toLowerCase() == k.toLowerCase() &&
            entry.value != null) return entry.value.toString();
      }
    }
    return null;
  }

  // Format time-like strings to HH:MM if possible
  String _formatToHHMM(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return '-';
    timeStr = timeStr.trim();
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hh = parts[0].padLeft(2, '0');
        final mm = parts[1].padLeft(2, '0');
        return '$hh:$mm';
      }

      // Try to parse numeric minutes since midnight
      final numVal = int.tryParse(timeStr);
      if (numVal != null) {
        final hh = (numVal ~/ 60).toString().padLeft(2, '0');
        final mm = (numVal % 60).toString().padLeft(2, '0');
        return '$hh:$mm';
      }
    } catch (_) {}
    return timeStr;
  }

  // Normalize various API success indicators into a boolean.
  bool _responseSuccess(dynamic resJson) {
    try {
      if (resJson == null) return false;
      if (resJson is Map) {
        // common keys
        final candidates = ['status', 'success', 'ok'];
        for (var k in candidates) {
          if (resJson.containsKey(k) && resJson[k] != null) {
            final v = resJson[k];
            if (v is bool) return v;
            if (v is num) return v == 1;
            if (v is String) {
              final low = v.toLowerCase();
              if (low == 'true' || low == '1') return true;
              if (low == 'false' || low == '0') return false;
            }
          }
        }
      }
    } catch (e) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bool isCheckIn =
        widget.headerTitle.toLowerCase().contains('check in');
    final bool isAlreadyIn =
        _inPunch.trim().isNotEmpty && _inPunch.trim() != '-';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E3C72),
        leadingWidth: 240,
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
                  widget.headerTitle,
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Today',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      // Photo capture round UI
                      Center(
                        child: GestureDetector(
                          onTap: _capturePhoto,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _photoFile == null
                                      ? (_isCameraInitialized &&
                                              _cameraController != null
                                          ? SizedBox(
                                              width: 150,
                                              height: 150,
                                              child: CameraPreview(
                                                  _cameraController!),
                                            )
                                          : Icon(Icons.camera_alt,
                                              size: 56,
                                              color: Colors.grey[700]))
                                      : Image.file(_photoFile!,
                                          fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withAlpha(10),
                                          blurRadius: 4)
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: Icon(Icons.camera,
                                        size: 18,
                                        color: Theme.of(context).primaryColor),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Check In',
                                        style:
                                            TextStyle(color: Colors.black54)),
                                    const SizedBox(height: 6),
                                    Text(_inPunch.isEmpty ? '-' : _inPunch,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Check Out',
                                        style:
                                            TextStyle(color: Colors.black54)),
                                    const SizedBox(height: 6),
                                    Text(_outPunch.isEmpty ? '-' : _outPunch,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Location (auto-fetched, non-interactive)
              TextField(
                controller: _locationController,
                readOnly: true,
                showCursor: false,
                enableInteractiveSelection: false,
                toolbarOptions: const ToolbarOptions(
                    copy: false, selectAll: false, paste: false, cut: false),
                decoration: InputDecoration(
                  labelText: 'Location',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),

              // Remark field
              TextField(
                controller: _remarkController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Remark',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),

              isCheckIn
                  ? ElevatedButton.icon(
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.login),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        child: Text(
                          _isSubmitting
                              ? 'Submitting...'
                              : (isAlreadyIn
                                  ? 'Checked in ($_inPunch)'
                                  : 'Check In'),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      onPressed: (isAlreadyIn || _isSubmitting)
                          ? null
                          : _performCheckIn,
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isAlreadyIn ? Colors.grey : Colors.green),
                    )
                  : ElevatedButton.icon(
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.logout),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        child: Text(
                          _isSubmitting ? 'Submitting...' : 'Check Out',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      onPressed: _isSubmitting ? null : _performCheckOut,
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
