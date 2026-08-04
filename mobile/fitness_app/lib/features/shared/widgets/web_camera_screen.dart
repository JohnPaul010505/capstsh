import 'package:flutter/material.dart';

/// Non-web fallback: the real camera recorder lives in web_camera_screen_web.dart
/// (conditionally swapped via dart.library.js_interop in the importer). This
/// file keeps native builds importable without ever running on web.
class WebCameraScreen extends StatelessWidget {
  const WebCameraScreen({super.key});

  static const recordDuration = Duration(seconds: 30);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: const Center(
        child: Text('Camera is only available on web', style: TextStyle(color: Colors.white54)),
      ),
    );
  }
}
