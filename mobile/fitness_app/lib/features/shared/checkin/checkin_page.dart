import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared/models/attendance_toggle_result.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/services/attendance_service.dart';
import '../../../app/design_tokens.dart';
import '../../../features/shared/widgets/app_glow_background.dart';

class CheckinPage extends ConsumerStatefulWidget {
  final bool showBack;

  /// Where the success screen returns to. Defaults to the home screen of the
  /// logged-in role (member home / trainer dashboard).
  final String? returnRoute;
  const CheckinPage({
    super.key,
    this.showBack = true,
    this.returnRoute,
  });

  @override
  ConsumerState<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends ConsumerState<CheckinPage> {
  static const _returnDelay = Duration(seconds: 2);
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _processing = false;
  bool _showScanner = true;
  bool _showSuccess = false;
  AttendanceToggleResult? _lastResult;
  Timer? _returnTimer;
  String? _statusMessage;
  bool _isSuccess = false;

  Future<void> _toggleAttendance() async {
    final profile = ref.read(authProvider).valueOrNull;
    if (profile == null) {
      setState(() {
        _statusMessage = 'Not logged in';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _processing = true;
      _statusMessage = null;
    });

    final result =
        await AttendanceService().toggleAttendance(memberId: profile.id);

    if (!mounted) return;
    if (!result.isSuccess) {
      // Show the real error — never a fake success.
      setState(() {
        _statusMessage =
            result.error ?? 'Something went wrong. Please try again.';
        _isSuccess = false;
      });
    } else if (!widget.showBack) {
      // Full success screen (In & Out tab), then return.
      setState(() {
        _lastResult = result;
        _showSuccess = true;
      });
      final returnRoute = widget.returnRoute ??
          (profile.role == 'trainer'
              ? '/trainer/dashboard'
              : '/member/home');
      _returnTimer = Timer(_returnDelay, () {
        if (mounted) context.go(returnRoute);
      });
    } else {
      // Inline status (page opened with a back button).
      setState(() {
        _statusMessage = result.action == AttendanceAction.checkedOut
            ? 'Checked out!'
            : 'Checked in!';
        _isSuccess = true;
      });
    }

    if (mounted) setState(() => _processing = false);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == 'FITGYM:ATTENDANCE') {
      _toggleAttendance();
    }
  }

  @override
  void dispose() {
    _returnTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return _buildSuccessScreen();
    }
    return CupertinoPageScaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      child: AppGlowBackground(
        child: SafeArea(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              widget.showBack ? 'Check In / Check Out' : 'In & Out',
              showBack: widget.showBack,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                children: [
                  if (_showScanner)
                    Container(
                      height: 250,
                      decoration: BoxDecoration(
                        color: ClayTokens.clayDarkSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ClayTokens.clayDarkBorder.withAlpha(128)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: MobileScanner(
                          onDetect: _onDetect,
                          controller: _scannerController,
                        ),
                      ),
                    ),
                  if (!_showScanner)
                    GestureDetector(
                      onTap: () => setState(() => _showScanner = true),
                      child: Container(
                        height: 250,
                        decoration: BoxDecoration(
                          color: ClayTokens.clayDarkSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ClayTokens.clayDarkBorder.withAlpha(128)),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.qrcode_viewfinder,
                                size: 64,
                                color: ClayTokens.clayDarkTextTertiary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to open scanner',
                                style: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayDarkTextTertiary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_showScanner)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CupertinoButton(
                            onPressed: () => setState(() => _showScanner = false),
                            child: Text(
                              'Close Scanner',
                              style: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: CupertinoButton.filled(
                      onPressed: _processing ? null : _toggleAttendance,
                      borderRadius: BorderRadius.circular(12),
                      child: _processing
                          ? CupertinoActivityIndicator(color: ClayTokens.clayDarkTextPrimary, radius: 10)
                          : Text(
                              'Check In / Check Out',
                              style: ClayTokens.titleLarge.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: ClayTokens.clayDarkTextPrimary,
                              ),
                            ),
                    ),
                  ),
                  if (_statusMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _isSuccess
                              ? ClayTokens.clayAccent.withAlpha(26)
                              : ClayTokens.clayError.withAlpha(26),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isSuccess
                                  ? CupertinoIcons.checkmark_circle_fill
                                  : CupertinoIcons.xmark_circle_fill,
                              color: _isSuccess
                                  ? ClayTokens.clayAccent
                                  : ClayTokens.clayError,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _statusMessage!,
                                style: ClayTokens.titleLarge.copyWith(
                                  fontSize: 15,
                                  color: _isSuccess
                                      ? ClayTokens.clayAccent
                                      : ClayTokens.clayError,
                                  letterSpacing: -0.24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Scan the gym QR code or tap the button above to check in or out.',
                    style: ClayTokens.bodySmall.copyWith(color: ClayTokens.clayDarkTextTertiary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildSuccessScreen() {
    final result = _lastResult!;
    final action = result.action!;
    final isCheckedOut = action == AttendanceAction.checkedOut;
    final title = isCheckedOut ? 'Checked Out!' : 'Checked In!';
    final verb = isCheckedOut ? 'out' : 'in';
    final localTime = DateFormat('h:mm a').format(result.at.toLocal());
    final duration = result.sessionDuration == null
        ? null
        : _durationLabel(result.sessionDuration!);

    return ColoredBox(
      color: ClayTokens.clayDarkBase,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: ClayTokens.clayAccent.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(title, style: ClayTokens.darkDisplaySmall),
              const SizedBox(height: 8),
              Text(
                'You checked $verb at $localTime',
                style: ClayTokens.darkBodyMedium.copyWith(color: ClayTokens.clayDarkTextSecondary),
              ),
              if (duration != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Session length: $duration',
                  style: ClayTokens.darkBodySmall.copyWith(color: ClayTokens.clayDarkTextSecondary),
                ),
              ],
              if (result.autoClosedStaleSession) ...[
                const SizedBox(height: 6),
                Text(
                  'Your previous open session was auto-closed.',
                  style: ClayTokens.darkBodySmall.copyWith(color: ClayTokens.clayDarkTextTertiary),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'You can scan the QR again to check ${isCheckedOut ? 'in' : 'out'}.',
                style: ClayTokens.darkBodySmall.copyWith(color: ClayTokens.clayDarkTextTertiary),
              ),
              const SizedBox(height: 4),
              Text(
                'Returning...',
                style: ClayTokens.darkBodySmall.copyWith(color: ClayTokens.clayDarkTextTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _durationLabel(Duration duration) {
    if (duration.inMinutes < 1) return null;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours <= 0) return '$minutes min';
    return '$hours h ${minutes.toString().padLeft(2, '0')} m';
  }

  Widget _buildHeader(String title, {bool showBack = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          showBack
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => context.pop(),
                  child: Icon(
                    CupertinoIcons.back,
                    color: ClayTokens.clayPrimary,
                  ),
                )
              : const SizedBox(width: 32),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: ClayTokens.titleLarge.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: ClayTokens.clayDarkTextPrimary,
                letterSpacing: -0.41,
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}
