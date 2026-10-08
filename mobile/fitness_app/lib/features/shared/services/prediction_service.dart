import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

/// One forecast line returned by `POST /api/ai/predictions`
/// (ai-service/routers/predictions.py, local scikit-learn - no Gemini needed).
class PredictionResult {
  final String predictionType;
  final double currentValue;
  final double predictedValue;
  final String unit;
  final int daysAhead;
  final double confidence;

  const PredictionResult({
    required this.predictionType,
    required this.currentValue,
    required this.predictedValue,
    required this.unit,
    required this.daysAhead,
    required this.confidence,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) =>
      PredictionResult(
        predictionType: json['prediction_type'] as String? ?? '',
        currentValue: (json['current_value'] as num?)?.toDouble() ?? 0,
        predictedValue: (json['predicted_value'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? '',
        daysAhead: (json['days_ahead'] as num?)?.toInt() ?? 30,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      );

  bool get isRetention => predictionType == 'retention_risk';

  /// high / medium / low - mirrors services/ml.py retention_risk() thresholds.
  String get riskLabel {
    if (!isRetention) return '';
    if (predictedValue > 0.7) return 'high';
    if (predictedValue > 0.4) return 'medium';
    return 'low';
  }
}

/// Outcome of one forecast request. A 404 ("Not enough data") is a normal
/// outcome for new members, not an error.
class MemberForecast {
  final List<PredictionResult> results;
  final bool notEnoughData;
  final String? error;

  const MemberForecast({
    required this.results,
    this.notEnoughData = false,
    this.error,
  });

  PredictionResult? byType(String type) {
    for (final r in results) {
      if (r.predictionType == type) return r;
    }
    return null;
  }

  PredictionResult? get retention {
    for (final r in results) {
      if (r.isRetention) return r;
    }
    return null;
  }
}

class PredictionService {
  /// Base URLs tried in order. `API_BASE_URL` comes from assets/.env and is
  /// the primary one; the extras keep one dev build working from every target
  /// (physical phone on the same Wi-Fi -> PC LAN IP, Android emulator ->
  /// 10.0.2.2, web/desktop on the PC -> localhost).
  ///
  /// Port note: the AI service (FastAPI) listens on **8001** while the admin
  /// Express proxy listens on **3001** (`/api/ai/predictions` -> AI service).
  /// Either endpoint serves forecasts, so every host is tried on BOTH ports —
  /// a stale `.env` port or a stopped proxy no longer kills the card.
  /// `localhost` is tried FIRST: with `adb reverse` (USB debug) it reaches the
  /// PC in milliseconds, and without the tunnel the phone refuses it just as
  /// fast — so it never costs the member a timeout. The PC's LAN IP only
  /// answers once Windows Firewall allows inbound (see
  /// `admin/scripts/open-firewall-lan.bat`); `10.0.2.2` is the emulator's
  /// alias for the host loopback.
  static const _fallbackHosts = ['localhost', '10.0.2.2', '192.168.100.181'];
  static const _fallbackPorts = [3001, 8001];

  /// Short-lived cache: one forecast per member for 2 minutes. The trainer
  /// members list fires up to 30 forecasts in parallel; without this every
  /// tab visit re-hammers all hosts and spams logcat with timeouts.
  static final Map<String, _CachedForecast> _cache = {};

  /// Probe order: `localhost` first (instant win over the `adb reverse` USB
  /// tunnel, instant refusal without it), then the URL from `.env`, then every
  /// other host/port pair. Probing sequentially costs one timeout per dead
  /// host, so the fast path has to come first — otherwise a firewall-blocked
  /// LAN IP stalls the card for seconds on every open.
  List<String> _candidateUrls() {
    final configured = aiApiBaseUrl();
    final parsed = Uri.tryParse(configured);
    if (parsed == null || !parsed.hasAuthority) return [configured];

    final candidates = <String>[];
    void add(Uri uri) {
      final url = uri.toString();
      if (!candidates.contains(url)) candidates.add(url);
    }

    final ports = <int>[
      if (parsed.hasPort) parsed.port,
      ..._fallbackPorts,
    ];

    // 1. localhost on every port — the USB-tunnel / PC-dev path.
    for (final port in ports) {
      add(parsed.replace(host: 'localhost', port: port));
    }
    // 2. Whatever `.env` actually points at (LAN IP in dev builds).
    add(parsed);
    // 3. Remaining fallbacks: emulator alias, then the PC's LAN IP.
    final hosts = <String>[
      parsed.host,
      ..._fallbackHosts.where((h) => h != 'localhost'),
    ];
    for (final host in hosts) {
      for (final port in ports) {
        add(parsed.replace(host: host, port: port));
      }
    }
    return candidates;
  }

  Future<MemberForecast> getForecast(
    String memberId, {
    int daysAhead = 30,
  }) async {
    // Serve repeats (trainer N+1 fan-out, home rebuilds) from the short cache.
    final cached = _cache[memberId];
    if (cached != null &&
        cached.daysAhead == daysAhead &&
        DateTime.now().difference(cached.at).inMinutes < 2) {
      return cached.forecast;
    }
    final candidates = _candidateUrls();

    for (var i = 0; i < candidates.length; i++) {
      try {
        final resp = await http
            .post(
              Uri.parse('${candidates[i]}/api/ai/predictions'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'member_id': memberId,
                'days_ahead': daysAhead,
              }),
            )
            // Every attempt is short: hosts that are down (emulator-only /
            // PC-only addresses from the wrong target) fail fast instead of
            // hanging the card for 20s each and spamming logcat.
            .timeout(const Duration(seconds: 4));

        if (resp.statusCode == 200) {
          final list = (jsonDecode(resp.body) as List)
              .map((e) => PredictionResult.fromJson(e as Map<String, dynamic>))
              .toList();
          final forecast = MemberForecast(results: list);
          _cache[memberId] = _CachedForecast(
            forecast: forecast,
            daysAhead: daysAhead,
            at: DateTime.now(),
          );
          return forecast;
        }
        if (resp.statusCode == 404) {
          String? detail;
          try {
            detail =
                (jsonDecode(resp.body) as Map<String, dynamic>)['detail']
                    as String?;
          } catch (_) {}
          // 404 = definitive "not enough data" from a REACHABLE server:
          // cache it too so the next 30 members don't re-probe dead hosts.
          const empty = MemberForecast(
            results: [],
            notEnoughData: true,
          );
          _cache[memberId] = _CachedForecast(
            forecast: empty,
            daysAhead: daysAhead,
            at: DateTime.now(),
          );
          return detail == null
              ? empty
              : MemberForecast(
                  results: const [],
                  notEnoughData: true,
                  error: detail,
                );
        }
        return MemberForecast(
          results: const [],
          error: 'Prediction service error (${resp.statusCode})',
        );
      } catch (e) {
        // Only the last candidate logs: intermediate fallbacks are expected
        // misses (emulator vs phone addresses), not spam-worthy.
        if (i == candidates.length - 1) {
          debugPrint('PREDICTION SERVICE unreachable ($memberId): $e');
        }
      }
    }

    return MemberForecast(
      results: const [],
      error: 'Could not reach the prediction service',
    );
  }
}

/// Cache entry for [PredictionService._cache].
class _CachedForecast {
  final MemberForecast forecast;
  final int daysAhead;
  final DateTime at;

  const _CachedForecast({
    required this.forecast,
    required this.daysAhead,
    required this.at,
  });
}
