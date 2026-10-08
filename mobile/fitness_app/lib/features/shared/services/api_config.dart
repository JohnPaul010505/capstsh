import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Base URL of the AI service (FastAPI, `ai-service/main.py`) or the admin
/// Express proxy that fronts it (`admin/server/index.js`, port 3001).
///
/// `localhost` is deliberately left alone on every target:
///   * web / desktop on the PC  -> the PC's own services;
///   * Android over USB debug   -> `adb reverse tcp:3001 tcp:3001` tunnels the
///     phone's `localhost` straight to the PC, which sidesteps Windows
///     Firewall entirely (no admin rights needed to open a port).
///
/// It used to be rewritten to the emulator-only alias `10.0.2.2` on Android,
/// which silently broke that tunnel. `10.0.2.2` still lives in
/// `PredictionService._fallbackHosts` so emulators keep working.
String aiApiBaseUrl() =>
    dotenv.env['API_BASE_URL'] ?? 'http://localhost:3001';
