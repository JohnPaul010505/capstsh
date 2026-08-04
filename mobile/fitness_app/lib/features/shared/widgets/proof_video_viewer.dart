import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../app/design_tokens.dart';
import 'pressable.dart';

/// Opens the proof video in a centered popup on the same screen (no
/// navigation). Pops in with a scale/fade animation, starts playback right
/// away inside the user gesture, and never blocks on initialization: a
/// spinner shows only briefly, and if the video cannot initialize within 15
/// seconds it falls back to an explicit tap-to-play button. An X button or
/// tapping outside closes it. Viewing only — no record/delete controls here.
Future<void> showProofVideoDialog(
  BuildContext context,
  String videoUrl,
) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close video',
    barrierColor: Colors.black.withAlpha(210),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) => _ProofViewerDialog(videoUrl: videoUrl),
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _ProofViewerDialog extends StatefulWidget {
  final String videoUrl;

  const _ProofViewerDialog({required this.videoUrl});

  @override
  State<_ProofViewerDialog> createState() => _ProofViewerDialogState();
}

class _ProofViewerDialogState extends State<_ProofViewerDialog> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _error = false;
  bool _waitingForTap = false;
  bool _playing = false;
  Timer? _initTimer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller!.addListener(_onTick);
    _controller!.initialize().then((_) {
      if (mounted) setState(() => _initialized = true);
    }).catchError((_) {
      if (mounted) setState(() => _error = true);
    });
    _initTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_initialized && !_error) {
        setState(() => _waitingForTap = true);
      }
    });
    _tryPlay();
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !mounted) return;
    final playing = c.value.isPlaying;
    if (playing != _playing) {
      setState(() => _playing = playing);
    }
  }

  Future<void> _tryPlay() async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.play();
      if (mounted) setState(() => _waitingForTap = false);
    } catch (_) {
      if (mounted) setState(() => _waitingForTap = true);
    }
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      _tryPlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.92,
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2A2A45)),
                gradient: RadialGradient(
                  center: const Alignment(0.9, -0.9),
                  radius: 1.3,
                  colors: [
                    const Color(0xFF7C3AED).withAlpha(50),
                    const Color(0xFF1C1C2E),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _togglePlay,
                      child: Center(
                        child: _controller == null
                            ? const SizedBox.shrink()
                            : VideoPlayer(_controller!),
                      ),
                    ),
                  ),
                  if (_error)
                    const Center(
                      child: Text(
                        'Video unavailable',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    )
                  else if (!_initialized && !_waitingForTap)
                    const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ClayColors.clayPrimaryLight,
                      ),
                    )
                  else if (_waitingForTap || !_playing)
                    Center(
                      child: GestureDetector(
                        onTap: _tryPlay,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(140),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: PressableCard(
                      onTap: () => Navigator.of(context).pop(),
                      padding: const EdgeInsets.all(7),
                      borderRadius: BorderRadius.circular(999),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(120),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
