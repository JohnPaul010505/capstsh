import 'package:intl/intl.dart';

import '../models/attendance_toggle_result.dart';
import 'supabase_client.dart';

/// Single source of truth for QR / button check-in and check-out.
///
/// Rules:
/// - An "open" session is the member's latest attendance row whose
///   `check_out_time` is null (regardless of which calendar day it was opened
///   on — that date scoping is exactly what used to break check-out after
///   local midnight).
/// - Scanning again closes the open session ("Checked Out").
/// - An open session older than its 12h expiry is auto-closed at its own
///   expiry, and the current scan starts a fresh check-in.
class AttendanceService {
  static const _sessionDuration = Duration(hours: 12);

  Future<AttendanceToggleResult> toggleAttendance({
    required String memberId,
  }) async {
    final now = DateTime.now().toUtc();
    try {
      final client = SupabaseClientService().client;
      final nowIso = now.toIso8601String();
      // The date column is a calendar date — use the LOCAL day so check-ins
      // between midnight and 8 AM (PH) don't land on the previous day.
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final openRows = await client
          .from('attendance')
          .select('id, check_in_time, expires_at')
          .eq('member_id', memberId)
          .isFilter('check_out_time', null)
          .order('check_in_time', ascending: false)
          .limit(1);

      final open = (openRows as List)
          .cast<Map<String, dynamic>>()
          .firstOrNull;

      // --- No open session: check in ---
      if (open == null) {
        await client.from('attendance').insert({
          'member_id': memberId,
          'check_in_time': nowIso,
          'check_in_date': today,
          'expires_at': now.add(_sessionDuration).toIso8601String(),
        });
        return AttendanceToggleResult(
          action: AttendanceAction.checkedIn,
          at: now,
        );
      }

      final checkInAt =
          DateTime.tryParse(open['check_in_time'] as String? ?? '');
      final expiresAt =
          DateTime.tryParse(open['expires_at'] as String? ?? '');
      final rowId = open['id'] as String;
      final isStale = expiresAt != null && expiresAt.isBefore(now);

      // --- Open session, still fresh: check out ---
      if (!isStale) {
        final updated = await client
            .from('attendance')
            .update({'check_out_time': nowIso})
            .eq('id', rowId)
            .select('id');
        if ((updated as List).isEmpty) {
          // Never report success for a write that matched nothing.
          return AttendanceToggleResult(
            at: now,
            error: 'Could not close your session. Please try again.',
          );
        }
        return AttendanceToggleResult(
          action: AttendanceAction.checkedOut,
          at: now,
          sessionDuration:
              checkInAt == null ? null : now.difference(checkInAt),
        );
      }

      // --- Stale open session (> 12h): auto-close it at its own expiry ---
      // and treat this scan as a brand-new check-in.
      // (expiresAt is non-null here: isStale requires it.)
      final staleExpiry = expiresAt;
      await client
          .from('attendance')
          .update({'check_out_time': staleExpiry.toUtc().toIso8601String()})
          .eq('id', rowId);

      await client.from('attendance').insert({
        'member_id': memberId,
        'check_in_time': nowIso,
        'check_in_date': today,
        'expires_at': now.add(_sessionDuration).toIso8601String(),
      });

      return AttendanceToggleResult(
        action: AttendanceAction.checkedIn,
        at: now,
        autoClosedStaleSession: true,
      );
    } catch (e) {
      return AttendanceToggleResult(at: now, error: e.toString());
    }
  }
}
