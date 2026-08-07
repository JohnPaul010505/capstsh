import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:video_player/video_player.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/proof_camera_screen.dart';
import '../../../shared/widgets/proof_video_viewer.dart';
import '../../../shared/widgets/web_camera_screen.dart'
    if (dart.library.js_interop) '../../../shared/widgets/web_camera_screen_web.dart'
    as proof_web;

/// Proof video control for one exercise: a placeholder strip until a clip
/// exists, then a compact saved strip (no loading screen). Tapping the saved
/// strip pops up a centered player dialog (same screen, scale/fade animation)
/// that starts playback immediately; an X button closes it. A red trash icon
/// removes the proof. Native builds use [ProofCameraScreen] (3s countdown,
/// 30s auto-record); web uses [proof_web.WebCameraScreen] (getUserMedia +
/// MediaRecorder), falling back to the picker if the camera is unavailable.
class ExerciseProofTile extends StatefulWidget {
  final String? videoUrl;
  final ValueChanged<String> onRecorded;
  final VoidCallback onDone;
  final VoidCallback onRemoved;

  const ExerciseProofTile({
    super.key,
    required this.videoUrl,
    required this.onRecorded,
    required this.onDone,
    required this.onRemoved,
  });

  @override
  State<ExerciseProofTile> createState() => _ExerciseProofTileState();
}

class _ExerciseProofTileState extends State<ExerciseProofTile> {
  bool _busy = false;

  Future<void> _record() async {
    if (_busy) return;
    if (kIsWeb) {
      await _recordWeb();
      return;
    }
    final url = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ProofCameraScreen()),
    );
    if (url != null && mounted) {
      widget.onRecorded(url);
      widget.onDone();
    }
  }

  Future<void> _recordWeb() async {
    setState(() => _busy = true);
    String? uploadedPath;
    try {
      final url = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const proof_web.WebCameraScreen()),
      );
      if (url != null && mounted) {
        widget.onRecorded(url);
        widget.onDone();
        return;
      }
      if (!mounted) return;

      // Camera unavailable (denied / no device): fall back to the picker.
      final video = await ImagePicker().pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 60),
      );
      if (video == null || !mounted) return;

      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser!.id;
      uploadedPath = 'workouts/$userId/${DateTime.now().millisecondsSinceEpoch}.mp4';
      final bytes = await video.readAsBytes();
      await client.storage.from('proofs').uploadBinary(
        uploadedPath,
        bytes,
        fileOptions: const FileOptions(contentType: 'video/mp4'),
      );
      final pickerUrl = client.storage.from('proofs').getPublicUrl(uploadedPath);

      var tooShort = false;
      try {
        final controller = VideoPlayerController.networkUrl(Uri.parse(pickerUrl));
        await controller.initialize();
        tooShort = controller.value.duration.inSeconds < 30;
        await controller.dispose();
      } catch (_) {
        tooShort = false;
      }

      if (tooShort) {
        try {
          await client.storage.from('proofs').remove([uploadedPath]);
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video must be at least 30 seconds')),
          );
        }
        return;
      }

      if (!mounted) return;
      widget.onRecorded(pickerUrl);
      widget.onDone();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save proof: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRemoveProof() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Remove proof video?'),
        content: const Text(
          'The video will be permanently deleted from the storage.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Remove'),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) widget.onRemoved();
  }

  void _showProofDialog() {
    final url = widget.videoUrl;
    if (url == null) return;
    showProofVideoDialog(context, url);
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return Container(
        height: 64,
        decoration: BoxDecoration(
          color: ClayTokens.clayDarkSurfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A45)),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: ClayColors.clayPrimaryLight),
        ),
      );
    }
    if (widget.videoUrl != null) {
      return _buildSavedStrip();
    }
    return _buildPlaceholderStrip();
  }

  Widget _buildPlaceholderStrip() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ClayTokens.clayDarkSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.videocam_outlined, size: 18, color: Color(0xFF636366)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('No video proof yet', style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
          ),
          PressableCard(
            onTap: _record,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            borderRadius: BorderRadius.circular(999),
            decoration: BoxDecoration(
              color: ClayTokens.clayPrimary.withAlpha(30),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ClayTokens.clayPrimary.withAlpha(100)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fiber_manual_record, color: Color(0xFFD6A5FF), size: 12),
                SizedBox(width: 6),
                Text('Record Proof', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD6A5FF),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Compact strip shown while a proof is saved (instant — no loading).
  /// Tap opens the centered player dialog; the red trash removes the proof.
  Widget _buildSavedStrip() {
    return PressableCard(
      onTap: _showProofDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(12),
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
        child: Row(
          children: [
            const Icon(Icons.play_circle_outline, size: 26, color: Colors.white54),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Video saved · tap to view', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB4B4D0),
              )),
            ),
            Container(
              width: 5, height: 5,
              decoration: BoxDecoration(
                color: ClayTokens.clayAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Text('DONE', style: TextStyle(
              fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF6EE7B7),
            )),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _confirmRemoveProof,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Color(0xFFFF453A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
