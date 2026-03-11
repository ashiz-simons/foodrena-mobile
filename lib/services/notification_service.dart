import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'notification_store.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background message: ${message.notification?.title}');
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'foodrena_default',
    'Foodrena Notifications',
    description: 'Order and delivery updates',
    importance: Importance.max,
    playSound: true,
  );

  static Future<void> init(BuildContext context) async {
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('⚠️ Push notifications denied');
      return;
    }

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationTap(details.payload, context);
      },
    );

    // Load persisted notifications on start
    await NotificationStore.instance.load();

    await _saveToken();

    _messaging.onTokenRefresh.listen((token) async {
      await _sendTokenToBackend(token);
    });

    // Foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
      _saveToStore(message);
    });

    // App opened from background notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _saveToStore(message);
      _handleNotificationTap(jsonEncode(message.data), context);
    });

    // App opened from terminated state
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _saveToStore(initial);
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationTap(jsonEncode(initial.data), context);
      });
    }
  }

  static void _saveToStore(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    NotificationStore.instance.add(AppNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: notification.title ?? '',
      body: notification.body ?? '',
      orderId: message.data['orderId'],
      type: message.data['type'],
      receivedAt: DateTime.now(),
      isRead: false,
    ));
  }

  static Future<void> _saveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _sendTokenToBackend(token);
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
  }

  static Future<void> _sendTokenToBackend(String token) async {
    try {
      await ApiService.post('/users/fcm-token', {'token': token});
      debugPrint('✅ FCM token saved to backend');
    } catch (e) {
      debugPrint('FCM token backend save failed: $e');
    }
  }

  static void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static void _handleNotificationTap(String? payload, BuildContext context) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final orderId = data['orderId'] as String?;

      switch (type) {
        case 'order_status':
          if (orderId != null) {
            // Navigate to order status screen
          }
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('Notification tap parse error: $e');
    }
  }
}