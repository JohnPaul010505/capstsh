import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Base URL of the AI service (FastAPI, `ai-service/main.py`).
///
/// Falls back to `http://localhost:3001`, which matches the admin Vite proxy
/// (`'/api' -> localhost:3001`) and the service's default `PORT`. Android
/// emulators map `localhost` to `10.0.2.2`; physical phones need the PC's
/// LAN IP in `API_BASE_URL`.
String aiApiBaseUrl() {
  final envUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3001';
  if (kIsWeb) return envUrl;
  if (Platform.isAndroid && envUrl.contains('localhost')) {
    return envUrl.replaceFirst('localhost', '10.0.2.2');
  }
  return envUrl;
}
