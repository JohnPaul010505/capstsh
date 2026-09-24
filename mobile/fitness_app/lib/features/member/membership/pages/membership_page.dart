import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, ScaffoldMessenger, SnackBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/models/membership_renewal_request.dart';
import 'package:shared/providers/auth_provider.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';
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
        membershipId: state.current?.id,
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

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(membershipProvider);

    return CupertinoPageScaffold(
      backgroundColor: ClayTokens.clayDarkBase,
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
                      style: const TextStyle(color: Color(0xFF636366), fontSize: 13),
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
    final current = state.current;
    final pending = state.pendingRequest;
    final canApply = state.canApplyForRenewal && pending == null;
    final lastDecision = state.lastDecision;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        MembershipStatusCard(
          membership: current,
          hasPendingRequest: pending != null,
        ),
        if (pending != null) ...[
          const SizedBox(height: 12),
          _infoBanner(
            icon: CupertinoIcons.hourglass,
            color: const Color(0xFFFF9F0A),
            text: 'Your ${pending.planName} renewal request is waiting for '
                'admin approval. You will get a notification once it is decided.',
          ),
        ],
        if (lastDecision != null && lastDecision.isDeclined) ...[
          const SizedBox(height: 12),
          _infoBanner(
            icon: CupertinoIcons.xmark_circle,
            color: const Color(0xFFFF453A),
            text: 'Your previous renewal request was declined. You can submit '
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
                ? const CupertinoActivityIndicator(color: Colors.white, radius: 10)
                : Text(
                    current == null ? 'Apply for Membership' : 'Apply for Renewal',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        if (!canApply && pending == null) ...[
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Renewal opens when your membership is about to end (7 days or less).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Text('HISTORY', style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF8E8E93),
          letterSpacing: 0.5,
        )),
        const SizedBox(height: 8),
        if (state.renewalRequests.isEmpty)
          const Text(
            'No renewal requests yet.',
            style: TextStyle(fontSize: 12, color: Color(0xFF636366)),
          )
        else
          ...state.renewalRequests.map(_historyTile),
      ],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withAlpha(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request.planName} renewal'
                  '${request.months > 1 ? ' - ${request.months} months' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Requested ${_fmtDate(request.requestedAt)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
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
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFFD8D8DE), height: 1.35),
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
            child: const Icon(CupertinoIcons.back, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              'Membership',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}
