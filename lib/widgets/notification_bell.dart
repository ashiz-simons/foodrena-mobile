import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/notification_store.dart';
import '../screens/customer/notifications_screen.dart';

class NotificationBell extends StatelessWidget {
  final Color color;
  final Color? badgeColor;
  final bool fullScreen; // true = customer (push screen), false = bottom sheet

  const NotificationBell({
    super.key,
    required this.color,
    this.badgeColor,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationStore.instance,
      builder: (context, _) {
        final unread = NotificationStore.instance.unreadCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => _onTap(context),
              icon: Icon(Icons.notifications_outlined, color: color, size: 22),
            ),
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: badgeColor ?? Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _onTap(BuildContext context) async {
    await NotificationStore.instance.markAllRead();
    if (!context.mounted) return;

    if (fullScreen) {
        Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NotificationsScreen()),
        );
        return;
    }

    _showBottomSheet(context);
    }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NotificationsSheet(),
    );
  }
}

// ── Bottom sheet (vendor + rider) ──────────────────────────────────────────

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet();

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  final store = NotificationStore.instance;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final bg = _dark ? const Color(0xFF1A1A1A) : Colors.white;
    final handleColor = _dark ? Colors.grey.shade700 : Colors.grey.shade300;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
              child: Row(
                children: [
                  Text(
                    "Notifications",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _dark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  ListenableBuilder(
                    listenable: store,
                    builder: (_, __) => store.notifications.isEmpty
                        ? const SizedBox()
                        : TextButton(
                            onPressed: () async {
                              await store.clear();
                              if (mounted) setState(() {});
                            },
                            child: Text(
                              "Clear all",
                              style: TextStyle(
                                color: _dark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: ListenableBuilder(
                listenable: store,
                builder: (_, __) {
                  final notifications = store.notifications;
                  if (notifications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            "No notifications yet",
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _tile(notifications[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(AppNotification n) {
    final dark = _dark;
    final cardBg = dark ? const Color(0xFF2A2A2A) : Colors.grey.shade50;
    final unreadBorder = dark ? Colors.blue.shade700 : Colors.blue.shade200;
    final readBorder = dark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: n.isRead ? cardBg : (dark ? const Color(0xFF1E2A3A) : Colors.blue.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: n.isRead ? readBorder : unreadBorder.withOpacity(0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _iconColor(n.type).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_iconFor(n.type), color: _iconColor(n.type), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: TextStyle(
                    fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                    fontSize: 13,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  n.body,
                  style: TextStyle(
                      fontSize: 12,
                      color: dark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatTime(n.receivedAt),
                  style: TextStyle(
                      fontSize: 10,
                      color: dark ? Colors.grey.shade600 : Colors.grey.shade400),
                ),
              ],
            ),
          ),
          if (!n.isRead)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(top: 3),
              decoration: BoxDecoration(
                color: _iconColor(n.type),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'new_order': return Icons.receipt_long;
      case 'order_status': return Icons.local_shipping_outlined;
      case 'rider_assigned': return Icons.delivery_dining;
      case 'payment': return Icons.payments_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  Color _iconColor(String? type) {
    switch (type) {
      case 'new_order': return Colors.orange;
      case 'order_status': return Colors.blue;
      case 'rider_assigned': return Colors.green;
      case 'payment': return Colors.purple;
      default: return Colors.blueGrey;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }
}