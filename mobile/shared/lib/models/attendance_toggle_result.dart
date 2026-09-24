/// Result of an attendance toggle (check-in / check-out).
enum AttendanceAction { checkedIn, checkedOut }

class AttendanceToggleResult {
  /// Null when the toggle failed (see [error]).
  final AttendanceAction? action;

  /// UTC timestamp used for the DB write (and shown to the user, localized).
  final DateTime at;

  /// True when an old open session (>12h) was auto-closed at its own expiry
  /// before starting the fresh check-in.
  final bool autoClosedStaleSession;

  /// How long the just-closed session lasted (check-out only).
  final Duration? sessionDuration;

  /// Error message; null on success.
  final String? error;

  const AttendanceToggleResult({
    required this.at,
    this.action,
    this.autoClosedStaleSession = false,
    this.sessionDuration,
    this.error,
  });

  bool get isSuccess => error == null && action != null;
}
