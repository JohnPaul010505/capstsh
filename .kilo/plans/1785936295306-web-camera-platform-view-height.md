# Fix Platform View Height Warning in Web Camera Screen

## Goal
Fix the Flutter Web platform view height warning for `web-proof-camera-{timestamp}` by explicitly setting the HTML video element's height style when registering the view factory.

## Context
When the web camera screen initializes, it creates an `HTMLVideoElement` and registers it with `ui_web.platformViewRegistry.registerViewFactory`. The element is wrapped in a `SizedBox.expand` in the Flutter widget tree, but the underlying HTML element has no explicit height set, triggering the warning:
> Platform View type [web-proof-camera-1785935734426000] height not set; defaulted to height: 100%

## Change
In `mobile/fitness_app/lib/features/shared/widgets/web_camera_screen_web.dart`, after creating the `HTMLVideoElement`, explicitly set its height style to `100%` so the platform view has a deterministic size and the warning is suppressed.

### Before (lines 66-73)
```dart
final video = web.HTMLVideoElement()..muted = true
  ..playsInline = true
  ..autoplay = true;
video.srcObject = stream;
ui_web.platformViewRegistry.registerViewFactory(
  _viewType,
  (int viewId) => video,
);
```

### After
```dart
final video = web.HTMLVideoElement()..muted = true
  ..playsInline = true
  ..autoplay = true
  ..style.height = '100%';
video.srcObject = stream;
ui_web.platformViewRegistry.registerViewFactory(
  _viewType,
  (int viewId) => video,
);
```

## Validation
1. Run the Flutter web app (`flutter run -d chrome` or equivalent).
2. Navigate to the proof camera screen.
3. Verify the console no longer shows the platform view height warning for `web-proof-camera-*`.
4. Confirm the camera preview still fills the available space as before.

## Risks / Notes
- Minimal risk: only adds an inline style to the existing video element.
- `SizedBox.expand` already constrains the Flutter side; setting `height: 100%` on the HTML element aligns with that constraint.
- No other files need changes.
