import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show ScaffoldMessenger, SnackBar, Theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/design_tokens.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../providers/membership_provider.dart';

class MembershipCancellationPage extends ConsumerStatefulWidget {
  const MembershipCancellationPage({super.key});

  @override
  ConsumerState<MembershipCancellationPage> createState() =>
      _MembershipCancellationPageState();
}

class _MembershipCancellationPageState
    extends ConsumerState<MembershipCancellationPage> {
  final _note = TextEditingController();
  bool _saving = false;
  int? _attendanceDays;
  bool _attendanceLoaded = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(dynamic membership) async {
    final profile = ref.read(authProvider).valueOrNull;
    if (profile == null) return;
    setState(() => _saving = true);
    try {
      await submitMembershipCancellation(
        memberId: profile.id,
        membershipId: membership.id as String,
        note: _note.text,
      );
      ref.invalidate(membershipProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cancellation request sent to the admin.'),
          backgroundColor: Color(0xFF7C3AED),
        ),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send request: $error'),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(membershipProvider).valueOrNull;
    final membership = state?.activeMembership;
    if (membership == null) {
      return CupertinoPageScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: Center(
                  child: Text(
                    'No active membership to cancel.',
                    style: TextStyle(color: ClayTokens.clayDarkTextPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final start = DateTime.tryParse(membership.startDate) ?? DateTime.now();
    final end = DateTime.tryParse(membership.endDate) ?? start;
    final duration = end.difference(start).inDays < 1
        ? 1
        : end.difference(start).inDays;
    final estimate = !_attendanceLoaded || _attendanceDays == null
        ? null
        : (membership.price -
                  membership.price /
                      duration *
                      (_attendanceDays! > duration
                          ? duration
                          : _attendanceDays!))
              .clamp(0, membership.price);
    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: AppGlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'CANCELLATION REQUEST',
                      style: TextStyle(
                        color: ClayTokens.clayDarkTextPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your request will be reviewed by the gym admin. Your membership stays active until it is approved.',
                      style: TextStyle(color: ClayTokens.clayDarkTextSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    _infoCard('Plan', membership.planName),
                    _infoCard(
                      'Membership price',
                      '₱${membership.price.toStringAsFixed(2)}',
                    ),
                    _infoCard(
                      'Attendance days',
                      !_attendanceLoaded
                          ? 'Calculating…'
                          : _attendanceDays?.toString() ?? 'Unavailable',
                    ),
                    _infoCard(
                      'Estimated refund',
                      estimate == null
                          ? (_attendanceLoaded
                                ? 'Unavailable'
                                : 'Calculating…')
                          : '₱${estimate.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Estimate = membership price minus the daily rate for each day attended. The admin confirms the final amount.',
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 18),
                    CupertinoTextField(
                      controller: _note,
                      placeholder: 'Reason or note (optional)',
                      minLines: 3,
                      maxLines: 5,
                      padding: EdgeInsets.all(12),
                      style: TextStyle(
                        color: ClayTokens.clayDarkTextPrimary,
                      ),
                      placeholderStyle: TextStyle(
                        color: ClayTokens.clayDarkTextTertiary,
                      ),
                      decoration: BoxDecoration(
                        color: ClayTokens.hairline.withAlpha(12),
                        border: Border.all(color: ClayTokens.hairline.withAlpha(24)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    CupertinoButton.filled(
                      onPressed: _saving || state?.pendingCancellation != null
                          ? null
                          : () => _submit(membership),
                      child: _saving
                          ? CupertinoActivityIndicator(
                              color: ClayTokens.clayDarkTextPrimary,
                            )
                          : const Text('Send Cancellation Request'),
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

  Widget _header() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Row(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: Icon(
            CupertinoIcons.back,
            color: ClayTokens.clayDarkTextPrimary,
          ),
        ),
        Expanded(
          child: Text(
            'Cancel Membership',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ClayTokens.clayDarkTextPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
        ),
        const SizedBox(width: 32),
      ],
    ),
  );

  Widget _infoCard(String label, String value) => Container(
    margin: EdgeInsets.only(bottom: 9),
    padding: EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: ClayTokens.hairline.withAlpha(10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ClayTokens.hairline.withAlpha(22)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: ClayTokens.clayDarkTextSecondary)),
        ),
        Text(
          value,
          style: TextStyle(
            color: ClayTokens.clayDarkTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAttendance());
  }

  Future<void> _loadAttendance() async {
    final membership = ref
        .read(membershipProvider)
        .valueOrNull
        ?.activeMembership;
    final userId = ref.read(activeUserIdProvider);
    if (membership == null || userId == null) return;
    try {
      final rows = await SupabaseClientService().client
          .from('attendance')
          .select('check_in_date')
          .eq('member_id', userId)
          .gte('check_in_date', membership.startDate)
          .lte('check_in_date', membership.endDate);
      if (mounted) {
        setState(() {
          _attendanceDays = (rows as List)
              .map((r) => r['check_in_date'] as String)
              .toSet()
              .length;
          _attendanceLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _attendanceLoaded = true);
    }
  }
}
