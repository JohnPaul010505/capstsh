import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:shared/models/membership.dart';

import '../../../../app/design_tokens.dart';

/// Hero card on the Membership screen: plan, status chip, dates, price.
class MembershipStatusCard extends StatelessWidget {
  final Membership? membership;
  final bool hasPendingRequest;

  const MembershipStatusCard({
    super.key,
    required this.membership,
    required this.hasPendingRequest,
  });

  @override
  Widget build(BuildContext context) {
    final m = membership;

    if (m == null) {
      return _card(
        statusLabel: 'NO MEMBERSHIP',
        statusActive: false,
        title: 'No membership yet',
        subtitle: 'Ask the gym admin to activate a plan for you, or apply for '
            'a renewal below once you\u2019ve been enrolled.',
      );
    }

    final expired = m.isExpired;
    final active = m.status == 'active' && !expired;
    final days = m.daysRemaining;

    String subtitle;
    if (expired) {
      subtitle = 'Expired on ${_fmt(m.endDate)}';
    } else if (days != null && days <= 7) {
      subtitle = days <= 0 ? 'Ends today' : 'Expires in $days day${days == 1 ? '' : 's'}';
    } else {
      subtitle = 'Valid until ${_fmt(m.endDate)}';
    }

    return _card(
      statusLabel: hasPendingRequest
          ? 'PENDING APPROVAL'
          : active
              ? 'ACTIVE'
              : expired
                  ? 'EXPIRED'
                  : m.status.toUpperCase(),
      statusActive: active && !hasPendingRequest,
      title: m.planName,
      subtitle: subtitle,
      details: '₱${m.price.toStringAsFixed(m.price.truncateToDouble() == m.price ? 0 : 2)} · '
          'Started ${_fmt(m.startDate)}',
    );
  }

  Widget _card({
    required String statusLabel,
    required bool statusActive,
    required String title,
    required String subtitle,
    String? details,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClayTokens.clayPrimaryLight.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MEMBERSHIP', style: ClayTokens.labelSmall.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text(title, style: ClayTokens.titleLarge.copyWith(color: ClayTokens.clayDarkTextPrimary)),
          const SizedBox(height: 4),
          Text(subtitle, style: ClayTokens.bodySmall.copyWith(
            color: statusActive ? ClayTokens.clayAccent : ClayTokens.clayWarning,
          )),
          if (details != null) ...[
            const SizedBox(height: 2),
            Text(details, style: ClayTokens.bodySmall.copyWith(
              color: ClayTokens.clayDarkTextTertiary,
            )),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusActive
                  ? ClayTokens.clayAccent.withAlpha(25)
                  : ClayTokens.clayWarning.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusActive
                    ? ClayTokens.clayAccent.withAlpha(60)
                    : ClayTokens.clayWarning.withAlpha(60),
              ),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusActive ? Colors.white : ClayTokens.clayWarning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    if (d == null) return isoDate.isEmpty ? '—' : isoDate.substring(0, isoDate.length.clamp(0, 10));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
