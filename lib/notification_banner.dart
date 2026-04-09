import 'package:flutter/material.dart';
import 'theme.dart';

enum NotificationBannerType {
  success,
  error,
  warning,
  info,
  sos,
  fall,
}

class NotificationBanner extends StatefulWidget {
  final String title;
  final String message;
  final NotificationBannerType type;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final Duration duration;

  const NotificationBanner({
    super.key,
    required this.title,
    required this.message,
    this.type = NotificationBannerType.info,
    this.onTap,
    this.onDismiss,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();

    if (widget.duration.inMilliseconds > 0) {
      Future.delayed(widget.duration, () {
        if (mounted) _dismiss();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  Color get _backgroundColor {
    switch (widget.type) {
      case NotificationBannerType.success:
        return const Color(0xFF43A047);
      case NotificationBannerType.error:
        return const Color(0xFFE53935);
      case NotificationBannerType.warning:
        return const Color(0xFFFFA726);
      case NotificationBannerType.info:
        return const Color(0xFF4A90E2);
      case NotificationBannerType.sos:
        return const Color(0xFFFF2E63);
      case NotificationBannerType.fall:
        return const Color(0xFFFF5722);
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case NotificationBannerType.success:
        return Icons.check_circle_rounded;
      case NotificationBannerType.error:
        return Icons.error_rounded;
      case NotificationBannerType.warning:
        return Icons.warning_rounded;
      case NotificationBannerType.info:
        return Icons.info_rounded;
      case NotificationBannerType.sos:
        return Icons.emergency_rounded;
      case NotificationBannerType.fall:
        return Icons.accessibility_new_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: widget.onTap,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
                _dismiss();
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _backgroundColor,
                    _backgroundColor.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _backgroundColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.message,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (widget.onDismiss != null)
                    GestureDetector(
                      onTap: _dismiss,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 22,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationBannerQueue extends StatelessWidget {
  final List<Widget> banners;

  NotificationBannerQueue({super.key, required this.banners});

  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    NotificationBannerType type = NotificationBannerType.info,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.of(context);
    _currentEntry?.remove();

    _currentEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 50,
        left: 0,
        right: 0,
        child: NotificationBanner(
          title: title,
          message: message,
          type: type,
          onTap: onTap,
          onDismiss: () {
            _currentEntry?.remove();
            _currentEntry = null;
          },
          duration: duration,
        ),
      ),
    );

    overlay.insert(_currentEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class AnimatedNotificationList extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;
  final Function(Map<String, dynamic>)? onTap;

  const AnimatedNotificationList({
    super.key,
    required this.notifications,
    this.onTap,
  });

  @override
  State<AnimatedNotificationList> createState() => _AnimatedNotificationListState();
}

class _AnimatedNotificationListState extends State<AnimatedNotificationList> {
  final List<Map<String, dynamic>> _displayedNotifications = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void didUpdateWidget(AnimatedNotificationList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncNotifications();
  }

  void _syncNotifications() {
    for (final notif in widget.notifications) {
      if (!_displayedNotifications.any((n) => n['id'] == notif['id'])) {
        _displayedNotifications.insert(0, notif);
        _listKey.currentState?.insertItem(0);
      }
    }
  }

  void _removeNotification(String id) {
    final index = _displayedNotifications.indexWhere((n) => n['id'] == id);
    if (index != -1) {
      final removed = _displayedNotifications.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => _buildNotificationItem(removed, animation),
      );
    }
  }

  Widget _buildNotificationItem(Map<String, dynamic> notif, Animation<double> animation) {
    final type = (notif['type'] as String? ?? '').toLowerCase();
    NotificationBannerType bannerType = NotificationBannerType.info;
    if (type == 'sos') bannerType = NotificationBannerType.sos;
    else if (type == 'fall' || type == 'chute') bannerType = NotificationBannerType.fall;

    return SlideTransition(
      position: animation.drive(
        Tween(begin: const Offset(1, 0), end: Offset.zero).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
      ),
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: NotificationBanner(
            title: type == 'sos' ? 'ALERTE SOS!' : type == 'fall' || type == 'chute' ? 'CHUTE DÉTECTÉE!' : 'Nouvelle alerte',
            message: notif['message'] ?? notif['type'] ?? 'Notification',
            type: bannerType,
            onTap: () => widget.onTap?.call(notif),
            onDismiss: () => _removeNotification(notif['id']),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      initialItemCount: _displayedNotifications.length,
      itemBuilder: (context, index, animation) {
        if (index >= _displayedNotifications.length) return const SizedBox.shrink();
        return _buildNotificationItem(_displayedNotifications[index], animation);
      },
    );
  }
}
