import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// App-wide interaction tracker used for idle detection in workout sessions.
///
/// Hooks global pointer events (tap, drag, scroll, hover) and key events so
/// ANY touch/click/keypress resets the idle clock — no per-screen listeners
/// needed. Start it once from the app root or the session provider.
class InteractionMonitor {
  InteractionMonitor._();

  static final InteractionMonitor instance = InteractionMonitor._();

  final ValueNotifier<DateTime> lastInteractionAt =
      ValueNotifier<DateTime>(DateTime.now());

  bool _started = false;

  void ensureStarted() {
    if (_started) return;
    _started = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  void _onPointerEvent(PointerEvent event) {
    // Ignore pure hover so mouse movement alone doesn't keep a session alive.
    if (event is PointerDownEvent ||
        event is PointerMoveEvent ||
        event is PointerScrollEvent) {
      lastInteractionAt.value = DateTime.now();
    }
  }

  bool _onKeyEvent(KeyEvent event) {
    lastInteractionAt.value = DateTime.now();
    return false;
  }
}
