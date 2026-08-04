import 'package:flutter/material.dart';

/// Swipe-left-to-reveal delete action. The child content slides left to expose
/// a red trash icon; tapping it fires [onDelete]. Animation uses only
/// [Transform] (GPU-friendly) per animation best practices.
class SwipeRevealDelete extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  final double actionWidth;

  const SwipeRevealDelete({
    super.key,
    required this.child,
    required this.onDelete,
    this.actionWidth = 56,
  });

  @override
  State<SwipeRevealDelete> createState() => _SwipeRevealDeleteState();
}

class _SwipeRevealDeleteState extends State<SwipeRevealDelete> {
  double _offset = 0;
  bool _open = false;

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _offset = (_offset + details.delta.dx).clamp(-widget.actionWidth, 0.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final shouldOpen = _offset < -widget.actionWidth / 2;
    setState(() {
      _open = shouldOpen;
      _offset = shouldOpen ? -widget.actionWidth : 0;
    });
  }

  void _close() {
    if (!_open) return;
    setState(() {
      _open = false;
      _offset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(
            right: 0,
            child: Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () {
                  _close();
                  widget.onDelete();
                },
                child: Container(
                  width: widget.actionWidth,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFFF453A),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: Transform.translate(
              offset: Offset(_offset, 0),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
