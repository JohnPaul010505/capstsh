import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/design_tokens.dart';
import '../widgets/pressable.dart';

enum _ProofStage { initializing, ready, countdown, recording, uploading, error }

/// Full-screen workout proof recorder: 3-2-1 countdown, auto 30s video capture,
/// upload to the `proofs` bucket and pop the public URL.
/// Native camera only — web callers must use the picker fallback.
class ProofCameraScreen extends StatefulWidget {
  const ProofCameraScreen({super.key});

  static const recordDuration = Duration(seconds: 30);

  @override
  State<ProofCameraScreen> createState() => _ProofCameraScreenState();
}

class _ProofCameraScreenState extends State<ProofCameraScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _camera;
  AnimationController? _progress;
  Timer? _countdownTimer;
  _ProofStage _stage = _ProofStage.initializing;
  int _countdownLeft = 3;
  bool _uploading = false;
  String? _tempPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      _stage = _ProofStage.error;
      return;
    }
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _progress?.dispose();
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive && _stage == _ProofStage.recording) {
      _cancelRecording();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera found on this device');
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _camera = CameraController(camera, ResolutionPreset.high, enableAudio: true);
      await _camera!.initialize();
      if (!mounted) return;
      setState(() => _stage = _ProofStage.ready);
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = _ProofStage.error);
    }
  }

  /// "Ready?" gate — recording only starts after the member taps Start.
  void _startFromReady() {
    if (_stage != _ProofStage.ready) return;
    _startCountdown();
  }

  void _startCountdown() {
    setState(() {
      _stage = _ProofStage.countdown;
      _countdownLeft = 3;
    });
    _countdownTimer?.cancel();
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _stage != _ProofStage.countdown) return;
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        if (_countdownLeft <= 1) {
          t.cancel();
          _startRecording();
        } else {
          setState(() => _countdownLeft--);
        }
      });
    });
  }

  Future<void> _startRecording() async {
    setState(() => _stage = _ProofStage.recording);
    _progress = AnimationController(
      vsync: this,
      duration: ProofCameraScreen.recordDuration,
    );
    _progress!.addListener(() {
      if (mounted) setState(() {});
    });
    _progress!.forward().then(
      (_) => _stopRecording(),
      onError: (_) => _stopRecording(),
    );
    try {
      await _camera!.startVideoRecording();
    } catch (_) {
      _progress!.stop();
      if (!mounted) return;
      setState(() => _stage = _ProofStage.error);
    }
  }

  Future<void> _stopRecording() async {
    if (_camera == null || !_camera!.value.isRecordingVideo) return;
    try {
      final file = await _camera!.stopVideoRecording();
      _tempPath = file.path;
      if (!mounted) return;
      setState(() => _stage = _ProofStage.uploading);
      await _keep();
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = _ProofStage.error);
    }
  }

  Future<void> _cancelRecording() async {
    _progress?.stop();
    try {
      await _camera?.stopVideoRecording();
    } catch (_) {}
    _deleteTemp();
    if (mounted) Navigator.of(context).pop(null);
  }

  void _deleteTemp() {
    if (_tempPath != null) {
      try {
        File(_tempPath!).deleteSync();
      } catch (_) {}
      _tempPath = null;
    }
  }

  Future<void> _keep() async {
    if (_uploading || _tempPath == null) return;
    setState(() => _uploading = true);
    try {
      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser!.id;
      final path = 'workouts/$userId/${DateTime.now().millisecondsSinceEpoch}.mp4';
      final bytes = await File(_tempPath!).readAsBytes();
      await client.storage.from('proofs').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'video/mp4'),
      );
      final url = client.storage.from('proofs').getPublicUrl(path);
      if (!mounted) return;
      Navigator.of(context).pop(url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save proof: $e')),
      );
      setState(() => _stage = _ProofStage.error);
    }
  }

  void _close() {
    if (_stage == _ProofStage.recording) {
      _cancelRecording();
    } else {
      _deleteTemp();
      Navigator.of(context).pop(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stage != _ProofStage.uploading,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_stage == _ProofStage.error)
              const _ErrorView()
            else if (_camera != null && _stage != _ProofStage.initializing)
              CameraPreview(_camera!)
            else
              const Center(
                child: CircularProgressIndicator(color: ClayColors.clayPrimaryLight),
              ),
            if (_stage == _ProofStage.countdown) _buildCountdown(),
            if (_stage == _ProofStage.ready) _buildReady(),
            if (_stage == _ProofStage.recording) _buildRecordingOverlay(),
            if (_stage == _ProofStage.uploading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),
            _buildTopBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              PressableCard(
                onTap: _stage == _ProofStage.error
                    ? () => Navigator.of(context).pop(null)
                    : _stage == _ProofStage.uploading
                        ? null
                        : _close,
                padding: const EdgeInsets.all(10),
                borderRadius: BorderRadius.circular(999),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
              const Spacer(),
              const Text(
                'Proof Video',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReady() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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
                  PressableCard(
                    onTap: _startFromReady,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    borderRadius: BorderRadius.circular(999),
                    decoration: BoxDecoration(
                      color: ClayTokens.clayAccent.withAlpha(40),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: ClayTokens.clayAccent.withAlpha(140)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Start',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: Text(
              '$_countdownLeft',
              key: ValueKey(_countdownLeft),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 96,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Get ready to record',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingOverlay() {
    final seconds = ProofCameraScreen.recordDuration.inSeconds;
    final elapsed = (_progress?.value ?? 0) * seconds;
    return Column(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(color: ClayColors.clayError, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  'REC ${elapsed.floor() < 10 ? '0${elapsed.floor()}' : elapsed.floor()}/$seconds s',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        LinearProgressIndicator(
          value: _progress?.value ?? 0,
          minHeight: 4,
          backgroundColor: Colors.white24,
          color: ClayTokens.clayError,
        ),
        const Spacer(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: PressableCard(
              onTap: _cancelRecording,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              borderRadius: BorderRadius.circular(999),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Camera unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Video proof needs camera access on the phone app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            PressableCard(
              onTap: () => Navigator.of(context).pop(null),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              borderRadius: BorderRadius.circular(999),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
