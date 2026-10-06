import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/models/membership.dart';
import 'package:shared/models/membership_renewal_request.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/services/supabase_client.dart';

/// Loads the member's memberships (newest first) + their renewal requests.
class MemberMembershipState {
  final List<Membership> memberships;
  final List<MembershipRenewalRequest> renewalRequests;

  /// Today's open check-in row (null when the member is not checked in).
  /// Drives the Daily ACTIVE/INACTIVE badge on the Membership screen.
  final Map<String, dynamic>? openSession;

  const MemberMembershipState({
    required this.memberships,
    required this.renewalRequests,
    this.openSession,
  });

  Membership? get current => memberships.isNotEmpty ? memberships.first : null;

  MembershipRenewalRequest? get pendingRequest {
    for (final r in renewalRequests) {
      if (r.isPending) return r;
    }
    return null;
  }

  /// Whether the member may submit a renewal request right now.
  ///
  /// A daily pass is not renewed - it is bought the day it is used, so a member
  /// on one buys the next day's pass instead of renewing. That mirrors the admin
  /// side, where the Memberships page only carries the RENEWAL REQUESTED badge
  /// and Renew button on monthly rows. An EXPIRED daily membership still lets
  /// them apply, because at that point they are buying membership again rather
  /// than renewing one, and blocking it would strand them with no way back in.
  bool get canApplyForRenewal {
    final m = current;
    if (m == null) return true;
    if (m.isExpired) return true;
    if (m.planName.trim().toLowerCase() == 'daily') return false;
    final days = m.daysRemaining;
    return days != null && days <= 7;
  }

  MembershipRenewalRequest? get lastDecision {
    for (final r in renewalRequests) {
      if (!r.isPending) return r;
    }
    return null;
  }
}

final membershipProvider = FutureProvider.autoDispose<MemberMembershipState>((
  ref,
) async {
  final client = SupabaseClientService().client;
  final userId = ref.watch(activeUserIdProvider);
  final authUid = client.auth.currentUser?.id;
  if (userId == null || authUid == null || userId != authUid) {
    throw Exception('Signed out — please log in again.');
  }

  final now = DateTime.now();
  final todayStr =
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  final results = await Future.wait<dynamic>([
    client
        .from('memberships')
        .select()
        .eq('member_id', userId)
        .order('created_at', ascending: false),
    client
        .from('membership_renewal_requests')
        .select()
        .eq('member_id', userId)
        .order('requested_at', ascending: false),
    // Today's open check-in (drives the Daily ACTIVE/INACTIVE badge — a
    // trainer scanning on this device writes the trainer's own row, so it
    // can never flip a member's card).
    client
        .from('attendance')
        .select('check_in_time, check_out_time, expires_at')
        .eq('member_id', userId)
        .eq('check_in_date', todayStr)
        .isFilter('check_out_time', null)
        .order('check_in_time', ascending: false)
        .limit(1),
  ]);

  // Fresh session only: an unchecked-out row whose 12h expiry already passed
  // is a stale leftover and must read as INACTIVE.
  Map<String, dynamic>? openSession;
  final nowUtc = DateTime.now().toUtc();
  for (final row in (results[2] as List).cast<Map<String, dynamic>>()) {
    final expires = DateTime.tryParse(row['expires_at'] as String? ?? '');
    if (expires == null || expires.isAfter(nowUtc)) {
      openSession = row;
      break;
    }
  }

  return MemberMembershipState(
    memberships: (results[0] as List)
        .cast<Map<String, dynamic>>()
        .map(Membership.fromJson)
        .toList(),
    renewalRequests: (results[1] as List)
        .cast<Map<String, dynamic>>()
        .map(MembershipRenewalRequest.fromJson)
        .toList(),
    openSession: openSession,
  );
});

/// Submits a renewal application. Throws on failure.
Future<void> submitRenewalRequest({
  required String memberId,
  required String planName,
  required int months,
  String? note,
  String? membershipId,
}) async {
  await SupabaseClientService().client
      .from('membership_renewal_requests')
      .insert({
        'member_id': memberId,
        if (membershipId != null) 'membership_id': membershipId,
        'plan_name': planName,
        'months': months,
        'status': 'pending',
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });
}
