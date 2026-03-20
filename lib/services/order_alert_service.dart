import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

class OrderAlertService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _alertActive = false;
  static Timer? _vibrationTimer;

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _notifications.initialize(settings);
  }

  /// Start looping alarm sound + vibration
  static Future<void> startAlert() async {
    if (_alertActive) return;
    _alertActive = true;

    // Show a high-priority notification with alarm sound
    const androidDetails = AndroidNotificationDetails(
      'order_alert_channel',
      'Order Alerts',
      channelDescription: 'Alerts for new incoming orders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('notification'),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      ongoing: true,
      autoCancel: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentBadge: true,
      presentAlert: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999,
      '🛵 New Order!',
      'You have a new delivery request. Tap to respond.',
      details,
    );

    // Start vibration loop
    _startVibrationLoop();
  }

  static void _startVibrationLoop() async {
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (!hasVibrator) return;

    _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_alertActive) return;
      await Vibration.vibrate(
        pattern: [0, 500, 200, 500, 200, 500],
        intensities: [0, 255, 0, 255, 0, 255],
      );
    });

    // Start immediately
    await Vibration.vibrate(
      pattern: [0, 500, 200, 500, 200, 500],
      intensities: [0, 255, 0, 255, 0, 255],
    );
  }

  /// Stop sound + vibration
  static Future<void> stopAlert() async {
    if (!_alertActive) return;
    _alertActive = false;

    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    await Vibration.cancel();
    await _notifications.cancel(999);
  }

  static bool get isActive => _alertActive;
}