import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:smart_eye/models/notification.dart';
import '../services/firebase_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<NotificationItem>>(
      stream: _firebaseService.streamNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final notifications = snapshot.data ?? [];
        final unreadCount = notifications.where((n) => !n.isRead).length;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Column(
            children: [
              // Enhanced Header with animated gradient
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0D9488), // teal-600
                      Color(0xFF14B8A6), // teal-500
                      Color(0xFF06B6D4), // cyan-500
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Back button
                            IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Mark all as read button
                            if (unreadCount > 0)
                              IconButton(
                                onPressed: () {
                                  _firebaseService.markAllNotificationsAsRead();
                                },
                                icon: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.done_all,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'Notifications',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            unreadCount > 0
                                ? '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}'
                                : 'All caught up!',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFE0F2FE),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Notifications List with animation
              Expanded(
                child: notifications.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          return AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              final delay = index * 0.1;
                              final animValue = Curves.easeOut.transform(
                                math.max(
                                  0,
                                  (_animationController.value - delay) /
                                      (1 - delay),
                                ),
                              );

                              return Transform.translate(
                                offset: Offset(0, 50 * (1 - animValue)),
                                child: Opacity(
                                  opacity: animValue,
                                  child: child,
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _NotificationCard(
                                notification: notification,
                                onTap: () {
                                  if (!notification.isRead) {
                                    _firebaseService.markNotificationAsRead(
                                      notification.id,
                                    );
                                  }
                                },
                                onDelete: () {
                                  _firebaseService.deleteNotification(
                                    notification.id,
                                  );
                                },
                                onMarkUnread: () {
                                  _firebaseService.markNotificationAsUnread(
                                    notification.id,
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Notifications',
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatefulWidget {
  final NotificationItem notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onMarkUnread;

  const _NotificationCard({
    Key? key,
    required this.notification,
    required this.onTap,
    required this.onDelete,
    required this.onMarkUnread,
  }) : super(key: key);

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _isPressed = false;

  NotificationType _getDerivedType(String name) {
    final text = name.toLowerCase();
    if (text.contains('motion')) return NotificationType.motion;
    if (text.contains('alert')) return NotificationType.alert;
    if (text.contains('offline')) return NotificationType.deviceOffline;
    if (text.contains('online')) return NotificationType.deviceOnline;
    return NotificationType.info;
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.motion:
        return Icons.directions_run;
      case NotificationType.alert:
        return Icons.warning_amber_rounded;
      case NotificationType.deviceOffline:
        return Icons.cloud_off;
      case NotificationType.deviceOnline:
        return Icons.cloud_done;
      case NotificationType.info:
        return Icons.info_outline;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.motion:
        return const Color(0xFF0D9488);
      case NotificationType.alert:
        return const Color(0xFFF59E0B);
      case NotificationType.deviceOffline:
        return const Color(0xFF9CA3AF);
      case NotificationType.deviceOnline:
        return const Color(0xFF10B981);
      case NotificationType.info:
        return const Color(0xFF06B6D4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final derivedType = _getDerivedType(widget.notification.title);
    final typeColor = _getColorForType(derivedType);
    final typeIcon = _getIconForType(derivedType);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: widget.notification.isRead
              ? null
              : Border.all(
                  color: const Color(0xFF0D9488).withOpacity(0.3),
                  width: 2,
                ),
          boxShadow: [
            BoxShadow(
              color: widget.notification.isRead
                  ? Colors.black.withOpacity(0.05)
                  : const Color(0xFF0D9488).withOpacity(0.15),
              blurRadius: _isPressed ? 10 : 15,
              offset: Offset(0, _isPressed ? 4 : 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: typeColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(typeIcon, size: 28, color: typeColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.notification.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 16,
                              fontWeight: widget.notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (!widget.notification.isRead)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0D9488,
                                  ).withOpacity(0.5),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.notification.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.notification.timestamp,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: theme.iconTheme.color?.withOpacity(0.6),
                ),
                onSelected: (value) {
                  if (value == 'delete') {
                    widget.onDelete();
                  } else if (value == 'mark_unread') {
                    widget.onMarkUnread();
                  }
                },
                itemBuilder: (BuildContext context) {
                  return <PopupMenuEntry<String>>[
                    if (widget.notification.isRead)
                      const PopupMenuItem<String>(
                        value: 'mark_unread',
                        child: ListTile(
                          leading: Icon(Icons.mark_email_unread_outlined),
                          title: Text('Mark as unread'),
                        ),
                      ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
