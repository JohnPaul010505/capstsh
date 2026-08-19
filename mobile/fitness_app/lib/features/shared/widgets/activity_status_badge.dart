import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/providers/activity_status_provider.dart';
import 'package:fitness_app/app/design_tokens.dart';

class _ImageAssetLoader extends StatefulWidget {
  final String assetPath;
  final double size;
  final bool isActive;

  const _ImageAssetLoader({
    required this.assetPath,
    required this.size,
    required this.isActive,
  });

  @override
  State<_ImageAssetLoader> createState() => _ImageAssetLoaderState();
}

class _ImageAssetLoaderState extends State<_ImageAssetLoader> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadAsset();
  }

  Future<void> _loadAsset() async {
    try {
      final data = await rootBundle.load(widget.assetPath);
      if (mounted) {
        setState(() {
          _bytes = data.buffer.asUint8List();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }
    if (_failed) {
      return _FallbackBadge(size: widget.size, isActive: widget.isActive);
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 1, valueColor: AlwaysStoppedAnimation(ClayTokens.clayPrimary)),
      ),
    );
  }
}

class _FallbackBadge extends StatelessWidget {
  final double size;
  final bool isActive;

  const _FallbackBadge({required this.size, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? ClayTokens.clayPrimary.withAlpha(30) : ClayTokens.clayDarkTextTertiary.withAlpha(30),
      ),
      child: Center(
        child: Icon(
          isActive ? Icons.local_fire_department : Icons.local_fire_department_outlined,
          size: size * 0.6,
          color: isActive ? ClayTokens.clayPrimary : ClayTokens.clayDarkTextTertiary,
        ),
      ),
    );
  }
}

class ActivityStatusBadge extends ConsumerWidget {
  final String memberId;
  final double size;

  const ActivityStatusBadge({
    super.key,
    required this.memberId,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(memberActivityStatusProvider(memberId));

    return activityAsync.when(
      data: (isActive) => _ImageAssetLoader(
        assetPath: isActive ? 'assets/animations/fire.gif' : 'assets/animations/unfire.png',
        size: size,
        isActive: isActive,
      ),
      loading: () => SizedBox(
        width: size,
        height: size,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation(ClayTokens.clayPrimary)),
        ),
      ),
      error: (_, __) => _FallbackBadge(size: size, isActive: false),
    );
  }
}

class ActivityStatusBadgeCompact extends ConsumerWidget {
  final String memberId;
  final double size;

  const ActivityStatusBadgeCompact({
    super.key,
    required this.memberId,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(memberActivityStatusProvider(memberId));

    return activityAsync.when(
      data: (isActive) => _ImageAssetLoader(
        assetPath: isActive ? 'assets/animations/fire.gif' : 'assets/animations/unfire.png',
        size: size,
        isActive: isActive,
      ),
      loading: () => SizedBox(
        width: size,
        height: size,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 1, valueColor: AlwaysStoppedAnimation(ClayTokens.clayPrimary)),
        ),
      ),
      error: (_, __) => _FallbackBadge(size: size, isActive: false),
    );
  }
}

class ActivityStatusBadgeSmall extends ConsumerWidget {
  final String memberId;
  final double size;

  const ActivityStatusBadgeSmall({
    super.key,
    required this.memberId,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(memberActivityStatusProvider(memberId));

    return activityAsync.when(
      data: (isActive) => _ImageAssetLoader(
        assetPath: isActive ? 'assets/animations/fire.gif' : 'assets/animations/unfire.png',
        size: size,
        isActive: isActive,
      ),
      loading: () => SizedBox(
        width: size,
        height: size,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 1, valueColor: AlwaysStoppedAnimation(ClayTokens.clayPrimary)),
        ),
      ),
      error: (_, __) => _FallbackBadge(size: size, isActive: false),
    );
  }
}