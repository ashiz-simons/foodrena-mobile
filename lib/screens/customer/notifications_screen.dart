import 'package:flutter/material.dart';
import '../../core/theme/customer_theme.dart';
import '../../services/notification_store.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final store = NotificationStore.instance;

  @override
  void initState() {
    super.initState();
    // Mark all as read when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await store.markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          if (store.notifications.isNotEmpty)
            TextButton(
              onPressed: () async {
                await store.clear();
                setState(() {});
              },
              child: const Text("Clear all",
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final notifications = store.notifications;

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("No notifications yet",
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _notifTile(notifications[i]),
          );
        },
      ),
    );
  }

  Widget _notifTile(AppNotification n) {
    final timeStr = _formatTime(n.receivedAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: n.isRead ? Colors.white : CustomerColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: n.isRead
              ? Colors.grey.shade200
              : CustomerColors.primary.withOpacity(0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _iconColor(n.type).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconFor(n.type), color: _iconColor(n.type), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(n.title,
                          style: TextStyle(
                              fontWeight: n.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              fontSize: 14)),
                    ),
                    if (!n.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: CustomerColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(n.body,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                Text(timeStr,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'new_order':
        return Icons.receipt_long;
      case 'order_status':
        return Icons.local_shipping_outlined;
      case 'rider_assigned':
        return Icons.delivery_dining;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _iconColor(String? type) {
    switch (type) {
      case 'new_order':
        return Colors.orange;
      case 'order_status':
        return Colors.blue;
      case 'rider_assigned':
        return Colors.green;
      default:
        return CustomerColors.primary;
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