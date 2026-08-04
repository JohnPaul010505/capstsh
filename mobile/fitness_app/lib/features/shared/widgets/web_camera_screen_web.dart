import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

/// Web implementation of the workout proof recorder. Uses getUserMedia for a
/// live preview (HtmlElementView) and MediaRecorder for a 30s capture, then
/// uploads the webm blob to the `proofs` bucket and pops the public URL.
/// Replaces the ImagePicker flow that only opened a file dialog on desktop.
class WebCameraScreen extends StatefulWidget {
  const WebCameraScreen({super.key});

  static const recordDuration = Duration(seconds: 30);

  @override
  State<WebCameraScreen> createState() => _WebCameraScreenState();
}

enum _WebStage { initializing, ready, countdown, recording, uploading, error }

class _WebCameraScreenState extends State<WebCameraScreen> {
  web.MediaStream? _stream;
  web.MediaRecorder? _recorder;
  web.Blob? _recordedBlob;
  _WebStage _stage = _WebStage.initializing;
  int _countdownLeft = 3;
  int _elapsedSeconds = 0;
  Timer? _timer;
  late final String _viewType;
  String? _error;

  @override
  void initState() {
    super.initState();
    _viewType = 'web-proof-camera-${DateTime.now().microsecondsSinceEpoch}';
    _initCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopTracks();
    super.dispose();
  }

  void _stopTracks() {
    try {
      _stream?.getTracks().toDart.forEach((t) => t.stop());
    } catch (_) {}
  }

  Future<void> _initCamera() async {
    try {
      final devices = web.window.navigator.mediaDevices;
      final stream = await devices
          .getUserMedia(web.MediaStreamConstraints(
            video: true.toJS,
            audio: false.toJS,
          ))
          .toDart;
      if (!mounted) return;

      final video = web.HTMLVideoElement()..muted = true
        ..playsInline = true
        ..autoplay = true;
      video.srcObject = stream;
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) => video,
      );

      setState(() {
        _stream = stream;
        _stage = _WebStage.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _WebStage.error;
        _error = 'Camera unavailable: $e';
      });
    }
  }

  /// "Ready?" gate — recording only starts after the member taps Start.
  void _startFromReady() {
    if (_stage != _WebStage.ready) return;
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _countdownLeft -= 1);
      if (_countdownLeft <= 0) {
        timer.cancel();
        _startRecording();
      }
    });
  }

  void _startRecording() {
    final stream = _stream;
    if (stream == null) return;
    final recorder = web.MediaRecorder(stream);
    recorder.ondataavailable = ((web.BlobEvent event) {
      _recordedBlob = event.data;
    }).toJS;
    recorder.onstop = ((web.Event _) {
      _upload();
    }).toJS;
    recorder.onerror = ((web.Event e) {
      _timer?.cancel();
      if (!mounted) return;
      setState(() {
        _stage = _WebStage.error;
        _error = 'Recording failed';
      });
    }).toJS;

    _recorder = recorder;
    recorder.start();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _elapsedSeconds += 1);
      if (_elapsedSeconds >= WebCameraScreen.recordDuration.inSeconds) {
        timer.cancel();
        try {
          recorder.stop();
        } catch (_) {}
      }
    });
    setState(() => _stage = _WebStage.recording);
  }

  Future<void> _upload() async {
    final blob = _recordedBlob;
    if (blob == null || !mounted) return;
    setState(() => _stage = _WebStage.uploading);
    try {
      final buffer = await blob.arrayBuffer().toDart;
      final bytes = buffer.toDart.asUint8List();

      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser!.id;
      final path = 'workouts/$userId/${DateTime.now().millisecondsSinceEpoch}.webm';
      await client.storage.from('proofs').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'video/webm'),
      );
      final url = client.storage.from('proofs').getPublicUrl(path);
      if (!mounted) return;
      Navigator.of(context).pop(url);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _WebStage.error;
        if (e is StorageException) {
          _error = 'Upload failed (${e.statusCode ?? '?'}): '
              '${e.message}'.trim();
        } else {
          _error = 'Upload failed: $e';
        }
      });
    }
  }

  void _cancel() {
    _timer?.cancel();
    try {
      _recorder?.stop();
    } catch (_) {}
    _stopTracks();
    if (mounted) Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Material(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: _cancel,
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text('Record Proof', style: TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700,
                  )),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_stream != null)
                    HtmlElementView(viewType: _viewType)
                  else
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                  if (_stage == _WebStage.ready)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Ready?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'The camera auto-records 30s. Start when you are.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            Material(
                              color: Colors.greenAccent.withAlpha(60),
                              borderRadius: BorderRadius.circular(999),
                              child: InkWell(
                                onTap: _startFromReady,
                                borderRadius: BorderRadius.circular(999),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
                                      SizedBox(width: 8),
                                      Text('Start',
                                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_stage == _WebStage.countdown)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_countdownLeft',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 64, fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (_stage == _WebStage.recording)
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10, height: 10,
                              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_elapsedSeconds / ${WebCameraScreen.recordDuration.inSeconds}s',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_stage == _WebStage.uploading)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white70),
                    ),
                  if (_stage == _WebStage.error)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              _error ?? 'Recording failed',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            Material(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(999),
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(null),
                                borderRadius: BorderRadius.circular(999),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                  child: Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                _stage == _WebStage.recording
                    ? 'Recording… auto-stops after ${WebCameraScreen.recordDuration.inSeconds}s'
                    : _stage == _WebStage.ready
                        ? 'Tap Start to begin recording'
                        : 'Auto-records ${WebCameraScreen.recordDuration.inSeconds}s',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
