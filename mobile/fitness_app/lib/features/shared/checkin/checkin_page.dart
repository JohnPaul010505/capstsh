import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../app/design_tokens.dart';
import '../../../features/shared/widgets/app_glow_background.dart';

class CheckinPage extends ConsumerStatefulWidget {
  final bool showBack;
  const CheckinPage({super.key, this.showBack = true});

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
  String? _successTitle;
  String? _successVerb;
  String? _successTime;
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

    try {
      final client = SupabaseClientService().client;
      final now = DateTime.now().toUtc().toIso8601String();
      final today = now.split('T')[0];

      final rows = await client
          .from('attendance')
          .select('id')
          .eq('member_id', profile.id)
          .eq('check_in_date', today)
          .isFilter('check_out_time', null);

      final open = (rows as List).isNotEmpty;
      if (open) {
        await client
            .from('attendance')
            .update({'check_out_time': now})
            .eq('member_id', profile.id)
            .eq('check_in_date', today)
            .isFilter('check_out_time', null);
      } else {
        await client.from('attendance').insert({
          'member_id': profile.id,
          'check_in_time': now,
          'check_in_date': today,
          'expires_at': DateTime.now().add(const Duration(hours: 12)).toUtc().toIso8601String(),
        });
      }

      if (!mounted) return;
      final localTime = DateFormat('h:mm a').format(DateTime.now());
      if (!widget.showBack) {
        setState(() {
          _showSuccess = true;
          _successTitle = open ? 'Checked Out!' : 'Checked In!';
          _successVerb = open ? 'out' : 'in';
          _successTime = localTime;
        });
        _returnTimer = Timer(_returnDelay, () {
          if (mounted) context.go('/member/home');
        });
      } else {
        setState(() {
          _statusMessage = open ? 'Checked out!' : 'Checked in!';
          _isSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: $e';
          _isSuccess = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
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
              Text(_successTitle!, style: ClayTokens.darkDisplaySmall),
              const SizedBox(height: 8),
              Text(
                'You checked $_successVerb at $_successTime',
                style: ClayTokens.darkBodyMedium.copyWith(color: ClayTokens.clayDarkTextSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                'Returning to Home...',
                style: ClayTokens.darkBodySmall.copyWith(color: ClayTokens.clayDarkTextTertiary),
              ),
            ],
          ),
        ),
      ),
    );
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
