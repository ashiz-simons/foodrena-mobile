import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // No need to show notification here — FCM shows it automatically
  // when app is in background/terminated
  debugPrint('📬 Background message: ${message.notification?.title}');
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  // Channel for Android
  static const _channel = AndroidNotificationChannel(
    'foodrena_default',
    'Foodrena Notifications',
    description: 'Order and delivery updates',
    importance: Importance.max,
    playSound: true,
  );

  /// Call once from main.dart after login
  static Future<void> init(BuildContext context) async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Request permission (iOS + Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('⚠️ Push notifications denied');
      return;
    }

    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Init local notifications (for foreground display)
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationTap(details.payload, context);
      },
    );

    // Get and save FCM token
    await _saveToken();

    // Token refresh — save new token when it changes
    _messaging.onTokenRefresh.listen((token) async {
      await _sendTokenToBackend(token);
    });

    // Foreground messages — show local notification
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    // App opened from notification (background state)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(
        jsonEncode(message.data),
        context,
      );
    });

    // App opened from terminated state via notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      // Small delay to let the widget tree build
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationTap(jsonEncode(initial.data), context);
      });
    }
  }

  static Future<void> _saveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }
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

      // Navigate based on notification type
      // The Navigator will be available since app is fully loaded
      switch (type) {
        case 'new_order':
          // Vendor or rider — go to orders screen
          // handled by the respective home screens listening to socket
          break;
        case 'order_status':
          if (orderId != null) {
            // Navigate to order status screen
            // You can use a global navigator key here if needed
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