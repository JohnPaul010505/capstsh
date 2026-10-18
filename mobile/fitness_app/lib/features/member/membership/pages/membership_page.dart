import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/models/membership_renewal_request.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/membership_provider.dart';
import '../widgets/membership_status_card.dart';
import '../widgets/renewal_request_sheet.dart';

class MembershipPage extends ConsumerStatefulWidget {
  const MembershipPage({super.key});

  @override
  ConsumerState<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends ConsumerState<MembershipPage> {
  bool _submitting = false;
  RealtimeChannel? _membershipChannel;

  @override
  void initState() {
    super.initState();
    final client = SupabaseClientService().client;
    final memberId = client.auth.currentUser?.id;
    if (memberId == null) return;
    _membershipChannel = client
        .channel('member_membership_updates_$memberId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'membership_renewal_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'member_id',
            value: memberId,
          ),
          callback: (_) {
            if (mounted) ref.invalidate(membershipProvider);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'memberships',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'member_id',
            value: memberId,
          ),
          callback: (_) {
            if (mounted) ref.invalidate(membershipProvider);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    final channel = _membershipChannel;
    if (channel != null) {
      SupabaseClientService().client.removeChannel(channel);
    }
    super.dispose();
  }

  /// Daily passes are re-bought daily rather than renewed, so the page needs to
  /// know which case it is showing. `plan_name` is free text in the database,
  /// hence the case-insensitive compare against the single value we write.
  static bool _isDaily(dynamic membership) =>
      membership != null &&
      (membership.planName as String).trim().toLowerCase() == 'daily';

  Future<void> _applyForRenewal() async {
    final state = ref.read(membershipProvider).valueOrNull;
    final profile = ref.read(authProvider).valueOrNull;
    if (state == null || profile == null) return;

    final result = await RenewalRequestSheet.show(
      context,
      currentPlanName: state.current?.planName ?? 'Monthly',
    );
    if (result == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      await submitRenewalRequest(
        memberId: profile.id,
        planName: result['plan_name'] as String,
        months: result['months'] as int,
        note: result['note'] as String?,
        membershipId: state.activeMembership?.id ?? state.current?.id,
        startDate: result['start_date'] as DateTime?,
        endDate: result['end_date'] as DateTime?,
      );
      if (!mounted) return;
      ref.invalidate(membershipProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Renewal request sent! The admin has been notified.'),
          backgroundColor: Color(0xFF22C55E),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send request: $e'),
          backgroundColor: const Color(0xFFFF453A),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _requestCancellation() async {
    final state = ref.read(membershipProvider).valueOrNull;
    if (state?.activeMembership == null || state?.pendingCancellation != null) {
      return;
    }
    final proceed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha(150),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              padding: EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: ClayTokens.clayDarkSurface.withAlpha(238),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: ClayTokens.hairline.withAlpha(35)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cancel membership?',
                    style: TextStyle(
                      color: ClayTokens.clayDarkTextPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your membership remains active until the admin reviews your request. Continue to the cancellation details?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ClayTokens.clayDarkTextSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          color: const Color(0xFF7C3AED),
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'No',
                            style: TextStyle(
                              color: ClayTokens.clayDarkTextPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoButton(
                          color: const Color(0xFFDC2626),
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            'Yes',
                            style: TextStyle(
                              color: ClayTokens.clayDarkTextPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (proceed == true && mounted) context.push('/member/membership/cancel');
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(membershipProvider);

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Expanded(
                child: stateAsync.when(
                  loading: () => const Center(
                    child: CupertinoActivityIndicator(color: Color(0xFFD6A5FF)),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: const TextStyle(
                        color: Color(0xFF636366),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  data: (state) => _buildContent(state),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(dynamic state) {
    // The hero card shows the newest NON-expired plan. Expired plans drop out
    // of the hero and move down into the HISTORY section instead.
    final current = state.activeMembership as dynamic;
    final pending = state.pendingRequest;
    final canApply = state.canApplyForRenewal && pending == null;
    final lastDecision = state.lastDecision;
    final expiredList = (state.expiredMemberships as List).cast<dynamic>();
    final cancellationRequests = (state.cancellationRequests as List)
        .cast<Map<String, dynamic>>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        MembershipStatusCard(
          membership: current,
          hasPendingRequest: pending != null,
          openSession: state.openSession,
        ),
        if (pending != null) ...[
          const SizedBox(height: 12),
          _infoBanner(
            icon: CupertinoIcons.hourglass,
            color: const Color(0xFFFF9F0A),
            text:
                'Your ${pending.planName} renewal request is waiting for '
                'admin approval. You will get a notification once it is decided.',
          ),
        ],
        if (state.pendingCancellation != null) ...[
          const SizedBox(height: 12),
          _infoBanner(
            icon: CupertinoIcons.hourglass,
            color: const Color(0xFFFF9F0A),
            text:
                'Your cancellation request is waiting for admin approval. Your membership remains active until it is approved.',
          ),
        ],
        if (lastDecision != null && lastDecision.isDeclined) ...[
          const SizedBox(height: 12),
          _infoBanner(
            icon: CupertinoIcons.xmark_circle,
            color: const Color(0xFFFF453A),
            text:
                'Your previous renewal request was declined. You can submit '
                'a new one or talk to the gym admin.',
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: CupertinoButton.filled(
            borderRadius: BorderRadius.circular(12),
            onPressed: canApply && !_submitting ? _applyForRenewal : null,
            child: _submitting
                ? CupertinoActivityIndicator(
                    color: ClayTokens.clayDarkTextPrimary,
                    radius: 10,
                  )
                : Text(
                    current == null
                        ? 'Apply for Membership'
                        : 'Apply for Renewal',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        if (!canApply && pending == null) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              // A daily pass has no renewal window at all, so the generic
              // "about to end" line would leave a daily member staring at a
              // disabled button with an explanation that does not apply to
              // them. Daily passes are simply re-bought each day.
              _isDaily(current)
                  ? 'Daily passes are not renewed - buy a new pass any day at the front desk.'
                  : 'Renewal opens when your membership is about to end (7 days or less).',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
            ),
          ),
        ],
        if (current != null && state.pendingCancellation == null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: CupertinoButton(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFDC2626),
              onPressed: _submitting ? null : _requestCancellation,
              child: Text(
                'Request Membership Cancellation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ClayTokens.clayDarkTextPrimary,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Text(
          'HISTORY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8E8E93),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        // Expired memberships sit at the top of HISTORY (most recent first),
        // then the member's renewal requests below them.
        if (expiredList.isNotEmpty) ...[
          ...expiredList.map(_expiredMembershipTile),
          const SizedBox(height: 8),
        ],
        if (expiredList.isEmpty &&
            state.renewalRequests.isEmpty &&
            cancellationRequests.isEmpty)
          const Text(
            'No history yet.',
            style: TextStyle(fontSize: 12, color: Color(0xFF636366)),
          ),
        if (state.renewalRequests.isNotEmpty)
          ...state.renewalRequests.map(_historyTile),
        if (cancellationRequests.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...cancellationRequests.map(_cancellationHistoryTile),
        ],
      ],
    );
  }

  /// HISTORY row for a past (expired) membership.
  Widget _expiredMembershipTile(dynamic membership) {
    final endD = DateTime.tryParse(membership.endDate as String? ?? '');
    final end = endD == null
        ? '—'
        : '${endD.year}-${endD.month.toString().padLeft(2, '0')}-${endD.day.toString().padLeft(2, '0')}';
    final cancelled = membership.status == 'cancelled';
    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          const Icon(CupertinoIcons.clock, size: 16, color: Color(0xFF8E8E93)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${membership.planName} plan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ClayTokens.clayDarkTextPrimary,
                  ),
                ),
                Text(
                  '${cancelled ? 'Cancelled' : 'Expired'} $end',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          Text(
            cancelled ? 'CANCELLED' : 'EXPIRED',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: cancelled
                  ? const Color(0xFFFF9F0A)
                  : const Color(0xFFFF453A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyTile(MembershipRenewalRequest request) {
    final isPending = request.isPending;
    final color = isPending
        ? const Color(0xFFFF9F0A)
        : request.isApproved
        ? const Color(0xFF30D158)
        : const Color(0xFFFF453A);
    final label = isPending
        ? 'PENDING'
        : request.isApproved
        ? 'APPROVED'
        : 'DECLINED';

    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request.planName} renewal'
                  '${request.months > 1 ? ' - ${request.months} months' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ClayTokens.clayDarkTextPrimary,
                  ),
                ),
                Text(
                  'Requested ${_fmtDate(request.requestedAt)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                if (request.startDate != null && request.endDate != null)
                  Text(
                    'Custom window ${_fmtDate(request.startDate!)} – ${_fmtDate(request.endDate!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFA78BFA),
                    ),
                  ),
                if (request.isApproved && request.approvedPrice != null)
                  Text(
                    'Paid ₱${request.approvedPrice!.toStringAsFixed(request.approvedPrice! % 1 == 0 ? 0 : 2)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF30D158),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cancellationHistoryTile(Map<String, dynamic> request) {
    final status = request['status'] as String? ?? 'pending';
    final color = status == 'approved'
        ? const Color(0xFF30D158)
        : status == 'declined'
        ? const Color(0xFFFF453A)
        : const Color(0xFFFF9F0A);
    final refund = (request['refund_amount'] as num?)?.toDouble();
    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membership cancellation',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ClayTokens.clayDarkTextPrimary,
                  ),
                ),
                Text(
                  'Requested ${_fmtDate(DateTime.tryParse(request['requested_at'] as String? ?? '') ?? DateTime.now())}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                if (status == 'approved' && refund != null)
                  Text(
                    'Refund recorded: ₱${refund.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF30D158),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBanner({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: ClayTokens.clayDarkTextSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Widget _buildHeader() {
    return Container(
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
              'Membership',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: ClayTokens.clayDarkTextPrimary,
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}
