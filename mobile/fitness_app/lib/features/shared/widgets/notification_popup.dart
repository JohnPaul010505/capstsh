import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/notification_service.dart';
import 'package:shared/models/notification_model.dart';
import 'package:shared/providers/auth_provider.dart';
import '../../../../app/design_tokens.dart';
import '../../member/notifications/providers/notifications_provider.dart';
import '../../trainer/notifications/providers/notifications_provider.dart';

class NotificationBell extends ConsumerWidget {
  final bool isMember;
  final VoidCallback onTap;
  final bool isActive;

  const NotificationBell({
    super.key,
    required this.isMember,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = isMember
        ? ref.watch(memberUnreadCountStreamProvider)
        : ref.watch(trainerUnreadCountStreamProvider);

    return unreadAsync.when(
      data: (count) => GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              isActive ? Icons.notifications : Icons.notifications_outlined,
              color: isActive ? ClayTokens.clayPrimary : ClayTokens.clayDarkTextPrimary,
              size: 22,
            ),
            if (count > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: ClayTokens.clayError,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
      loading: () => const SizedBox(width: 22, height: 22),
      error: (_, __) => Icon(Icons.notifications_outlined, color: ClayTokens.clayDarkTextPrimary, size: 22),
    );
  }
}

class NotificationPopup extends ConsumerStatefulWidget {
  final bool isOpen;
  final bool isMember;
  final VoidCallback onClose;
  final GlobalKey bellKey;

  const NotificationPopup({
    super.key,
    required this.isOpen,
    required this.isMember,
    required this.onClose,
    required this.bellKey,
  });

  @override
  ConsumerState<NotificationPopup> createState() => _NotificationPopupState();
}

class _NotificationPopupState extends ConsumerState<NotificationPopup> {
  OverlayEntry? _overlayEntry;
  late String _userId;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    _userId = authState.valueOrNull?.id ?? '';
  }

  @override
  void didUpdateWidget(covariant NotificationPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _openPopup();
    } else if (!widget.isOpen && oldWidget.isOpen) {
      _closePopup();
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _openPopup() {
    if (_overlayEntry != null) return;

    final bellContext = widget.bellKey.currentContext;
    if (bellContext == null) return;

    final renderBox = bellContext.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => _PopupOverlay(
        position: position,
        size: size,
        isMember: widget.isMember,
        userId: _userId,
        onClose: widget.onClose,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _overlayEntry != null) {
        Overlay.of(context).insert(_overlayEntry!);
      }
    });
  }

  void _closePopup() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;
  _ArrowPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) => oldDelegate.color != color;
}

class _PopupOverlay extends ConsumerStatefulWidget {
  final Offset position;
  final Size size;
  final bool isMember;
  final String userId;
  final VoidCallback onClose;

  const _PopupOverlay({
    required this.position,
    required this.size,
    required this.isMember,
    required this.userId,
    required this.onClose,
  });

  @override
  ConsumerState<_PopupOverlay> createState() => _PopupOverlayState();
}

class _PopupOverlayState extends ConsumerState<_PopupOverlay> {
  List<AppNotification> _notifications = [];
  bool _loading = true;
  AppNotification? _selected;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final service = NotificationService();
      final notifs = await service.fetchNotifications(widget.userId);
      if (mounted) {
        setState(() {
          _notifications = notifs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetail(AppNotification notification) async {
    if (!notification.read) {
      try {
        await NotificationService().markAsRead(notification.id);
      } catch (_) {}
      setState(() {
        final i = _notifications.indexWhere((n) => n.id == notification.id);
        if (i != -1) {
          _notifications[i] = notification.copyWith(read: true);
        }
      });
    }
    setState(() => _selected = notification);
  }

  void _backToList() => setState(() => _selected = null);

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    const arrowWidth = 16.0;
    const arrowHeight = 8.0;

    // Fixed card width
    const cardWidth = 340.0;
    final cardLeft = (widget.position.dx + widget.size.width / 2) - (cardWidth / 2);
    final clampedCardLeft = cardLeft.clamp(8.0, screenWidth - cardWidth - 8);

    // Arrow's x-center tracks the bell icon's actual center, clamped inside card bounds
    final bellCenterX = widget.position.dx + widget.size.width / 2;
    final arrowLeft = (bellCenterX - arrowWidth / 2)
        .clamp(clampedCardLeft + 12, clampedCardLeft + cardWidth - arrowWidth - 12);

    final cardTop = widget.position.dy + widget.size.height + 4;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.transparent),
          ),
        ),
        // Arrow — flush against card's top edge, no gap
        Positioned(
          top: cardTop,
          left: arrowLeft,
          child: CustomPaint(
            size: const Size(arrowWidth, arrowHeight),
            painter: _ArrowPainter(ClayTokens.clayDarkBase), // same as header
          ),
        ),
        Positioned(
          top: cardTop + arrowHeight,
          left: clampedCardLeft,
          width: cardWidth,
          child: Material(
            color: Colors.transparent,
            child: Container(
              height: 500,
              decoration: BoxDecoration(
                color: ClayTokens.clayDarkSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClayTokens.clayDarkBorder.withAlpha(50)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(100),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header — swaps between plain title and back+title
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: ClayTokens.clayDarkBase,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      border: Border(
                        bottom: BorderSide(color: ClayTokens.clayDarkBorder.withAlpha(50)),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: _selected != null
                              ? GestureDetector(
                                  onTap: _backToList,
                                  child: Icon(
                                    CupertinoIcons.chevron_left,
                                    size: 20,
                                    color: ClayTokens.clayDarkTextPrimary,
                                  ),
                                )
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            'Notifications',
                            textAlign: TextAlign.center,
                            style: ClayTokens.titleLarge.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: ClayTokens.clayDarkTextPrimary,
                              letterSpacing: -0.41,
                            ),
                          ),
                        ),
                        const SizedBox(width: 32), // balances the back button width
                      ],
                    ),
                  ),
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                      child: _selected != null
                          ? SingleChildScrollView(
                              key: const ValueKey('detail'),
                              child: _NotificationDetail(
                                notification: _selected!,
                                formatDate: _formatDate,
                              ),
                            )
                          : _buildList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Padding(
        key: ValueKey('list'),
        padding: EdgeInsets.all(24),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (_notifications.isEmpty) {
      return Padding(
        key: const ValueKey('list'),
        padding: const EdgeInsets.all(24),
        child: Text(
          'No notifications',
          style: TextStyle(fontSize: 17, color: ClayTokens.clayDarkTextTertiary),
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey('list'),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final n = _notifications[index];
        return _NotificationItem(
          notification: n,
          onTap: () => _openDetail(n),
        );
      },
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: notification.read
              ? Colors.transparent
              : ClayTokens.clayDarkSurfaceElevated,
          border: Border(
            bottom: BorderSide(
              color: ClayTokens.clayDarkBorder.withAlpha(100),
              width: 1.0,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: notification.read
                    ? Colors.transparent
                    : ClayTokens.clayPrimary,
              ),
            ),
            Expanded(
              child: Text(
                notification.title,
                style: ClayTokens.titleLarge.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ClayTokens.clayDarkTextPrimary,
                  letterSpacing: -0.41,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationDetail extends StatelessWidget {
  final AppNotification notification;
  final String Function(DateTime) formatDate;

  const _NotificationDetail({
    required this.notification,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ClayTokens.clayDarkSurface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            notification.title,
            style: ClayTokens.titleLarge.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: ClayTokens.clayDarkTextPrimary,
              letterSpacing: -0.41,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatDate(notification.createdAt),
            style: TextStyle(
              fontSize: 12,
              color: ClayTokens.clayDarkTextTertiary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            notification.body ?? '',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: ClayTokens.clayDarkTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '- Admin',
              style: TextStyle(
                fontSize: 12,
                color: ClayTokens.clayDarkTextTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}