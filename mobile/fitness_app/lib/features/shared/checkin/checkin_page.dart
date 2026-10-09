import 'dart:async';
import 'dart:ui' show ImageFilter;

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
  static const _returnDelay = Duration(seconds: 3);
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _processing = false;
  bool _showScanner = true;
  DateTime? _lastScanAt;
  bool _showSuccess = false;
  AttendanceToggleResult? _lastResult;
  Timer? _returnTimer;
  String? _statusMessage;
  bool _isSuccess = false;
  // Today's sessions (check-in / check-out times) for the status card.
  List<Map<String, dynamic>> _todaySessions = const [];
  bool _sessionsLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSessions());
  }

  Future<void> _loadSessions() async {
    final profile = ref.read(authProvider).valueOrNull;
    if (profile == null) return;
    try {
      final sessions =
          await AttendanceService().todaySessions(memberId: profile.id);
      if (mounted) {
        setState(() {
          _todaySessions = sessions;
          _sessionsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _sessionsLoading = false);
    }
  }

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
    } else {
      // Full-screen confirmation for 3 seconds, then back to the status
      // page with the fresh check-in / check-out times — same flow for
      // member and trainer, check-in and check-out.
      setState(() {
        _lastResult = result;
        _showSuccess = true;
        // Check-in AND check-out both close the scanner: the camera did its
        // job, so shut it off instead of leaving it running behind the
        // confirmation. The user reopens it deliberately for the next scan.
        _showScanner = false;
      });
      unawaited(_scannerController.stop());
      _returnTimer = Timer(_returnDelay, () {
        if (mounted) {
          setState(() => _showSuccess = false);
          _loadSessions();
        }
      });
    }

    if (mounted) setState(() => _processing = false);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;
    final now = DateTime.now();
    if (_lastScanAt != null &&
        now.difference(_lastScanAt!) < const Duration(seconds: 1)) {
      return;
    }
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == 'FITGYM:ATTENDANCE') {
      _lastScanAt = now;
      _toggleAttendance();
    }
  }

  @override
  void dispose() {
    _returnTimer?.cancel();
    // Stop the camera first, then release it — the scanner screen is gone.
    unawaited(_scannerController.stop());
    unawaited(_scannerController.dispose());
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
              'In & Out',
              showBack: widget.showBack,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                children: [
                  if (_showScanner)
                    // Glass frame — purple-tinted ring with a soft glow so
                    // the scanner reads as liquid glass over the camera feed.
                    Container(
                      height: 250,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withAlpha(120),
                            ClayTokens.clayPrimary.withAlpha(150),
                            Colors.white.withAlpha(60),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: ClayTokens.clayPrimary.withAlpha(60),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15.5),
                        child: Container(
                          color: Colors.black,
                          child: MobileScanner(
                            onDetect: _onDetect,
                            controller: _scannerController,
                          ),
                        ),
                      ),
                    ),
                  if (!_showScanner)
                    GestureDetector(
                      onTap: () => setState(() => _showScanner = true),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            height: 250,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withAlpha(21),
                                  ClayTokens.clayPrimaryLight.withAlpha(20),
                                  ClayTokens.clayPrimary.withAlpha(24),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withAlpha(38)),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.qrcode_viewfinder,
                                    size: 64,
                                    color: ClayTokens.clayPrimary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to open scanner',
                                    style: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayDarkTextPrimary),
                                  ),
                                ],
                              ),
                            ),
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
                            onPressed: () {
                              // Close Scanner shuts the camera off right away
                              // (unmount would stop it anyway — explicit so
                              // the intent survives refactors).
                              unawaited(_scannerController.stop());
                              setState(() => _showScanner = false);
                            },
                            child: Text(
                              'Close Scanner',
                              style: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  _buildStatusCard(),
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
                    'Scan the gym QR code to check in or out. You get one check-in and one check-out per day.',
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

  /// Glass card showing today's check-in / check-out times so the trainer
  /// (or member) can see at a glance whether they are checked in or out.
  Widget _buildStatusCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withAlpha(21),
                ClayTokens.clayPrimaryLight.withAlpha(20),
                ClayTokens.clayPrimary.withAlpha(24),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(38)),
          ),
          child: _sessionsLoading
              ? const Center(child: CupertinoActivityIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.clock_fill,
                          size: 16,
                          color: ClayTokens.clayPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Today's Attendance",
                          style: ClayTokens.titleLarge.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ClayTokens.clayDarkTextPrimary,
                            letterSpacing: -0.41,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_todaySessions.isEmpty)
                      Text(
                        "You haven't checked in yet today.",
                        style: ClayTokens.bodyMedium.copyWith(
                          color: ClayTokens.clayDarkTextTertiary,
                        ),
                      )
                    else
                      for (final session in _todaySessions) ...[
                        _statusRow(
                          icon: CupertinoIcons.checkmark_circle_fill,
                          label: 'Checked in',
                          time: _formatSessionTime(
                            session['check_in_time'] as String?,
                          ),
                          color: ClayTokens.clayAccent,
                        ),
                        const SizedBox(height: 8),
                        if (session['check_out_time'] != null)
                          _statusRow(
                            icon: CupertinoIcons.checkmark_circle_fill,
                            label: 'Checked out',
                            time: _formatSessionTime(
                              session['check_out_time'] as String?,
                            ),
                            color: ClayTokens.clayAccent,
                          )
                        else
                          _statusRow(
                            icon: CupertinoIcons.person_fill,
                            label: 'Still checked in',
                            time: null,
                            color: ClayTokens.clayPrimary,
                          ),
                        if (session != _todaySessions.last)
                          const SizedBox(height: 14),
                      ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required String label,
    required String? time,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: ClayTokens.bodyMedium.copyWith(
              color: ClayTokens.clayDarkTextPrimary,
            ),
          ),
        ),
        if (time != null)
          Text(
            time,
            style: ClayTokens.titleLarge.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ClayTokens.clayDarkTextPrimary,
            ),
          ),
      ],
    );
  }

  String _formatSessionTime(String? iso) {
    final time = DateTime.tryParse(iso ?? '');
    if (time == null) return '--';
    return DateFormat('h:mm a').format(time.toLocal());
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
                isCheckedOut
                    ? "You're done for today. See you tomorrow!"
                    : 'Scan the QR again when you leave to check out.',
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
                  onPressed: () {
                    // White "<" — leaves In & Out. This screen is a pushed
                    // full-screen route (nav bar hidden), so pop back to the
                    // previous screen; fall back to the role home tab when
                    // there is nothing to pop.
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      final role =
                          ref.read(authProvider).valueOrNull?.role;
                      context.go(
                        widget.returnRoute ??
                            (role == 'trainer'
                                ? '/trainer/dashboard'
                                : '/member/home'),
                      );
                    }
                  },
                  child: const Icon(
                    CupertinoIcons.back,
                    color: Colors.white,
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
