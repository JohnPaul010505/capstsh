import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/models/membership.dart';
import 'package:shared/models/membership_renewal_request.dart';
import 'package:shared/services/supabase_client.dart';

/// Loads the member's memberships (newest first) + their renewal requests.
class MemberMembershipState {
  final List<Membership> memberships;
  final List<MembershipRenewalRequest> renewalRequests;

  const MemberMembershipState({
    required this.memberships,
    required this.renewalRequests,
  });

  Membership? get current => memberships.isNotEmpty ? memberships.first : null;

  MembershipRenewalRequest? get pendingRequest {
    for (final r in renewalRequests) {
      if (r.isPending) return r;
    }
    return null;
  }

  bool get canApplyForRenewal {
    final m = current;
    if (m == null) return true;
    if (m.isExpired) return true;
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

final membershipProvider =
    FutureProvider.autoDispose<MemberMembershipState>((ref) async {
  final client = SupabaseClientService().client;
  final userId = client.auth.currentUser!.id;

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
  ]);

  return MemberMembershipState(
    memberships: (results[0] as List)
        .cast<Map<String, dynamic>>()
        .map(Membership.fromJson)
        .toList(),
    renewalRequests: (results[1] as List)
        .cast<Map<String, dynamic>>()
        .map(MembershipRenewalRequest.fromJson)
        .toList(),
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
