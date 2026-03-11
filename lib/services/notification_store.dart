import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? orderId;
  final String? type;
  final DateTime receivedAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.orderId,
    this.type,
    required this.receivedAt,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'orderId': orderId,
        'type': type,
        'receivedAt': receivedAt.toIso8601String(),
        'isRead': isRead,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'],
        title: j['title'],
        body: j['body'],
        orderId: j['orderId'],
        type: j['type'],
        receivedAt: DateTime.parse(j['receivedAt']),
        isRead: j['isRead'] ?? false,
      );
}

class NotificationStore extends ChangeNotifier {
  static final NotificationStore _instance = NotificationStore._();
  static NotificationStore get instance => _instance;
  NotificationStore._();

  final List<AppNotification> _notifications = [];
  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  static const _key = 'app_notifications';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    _notifications.clear();
    for (final s in raw) {
      try {
        _notifications.add(AppNotification.fromJson(jsonDecode(s)));
      } catch (_) {}
    }
    // Sort newest first
    _notifications.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    notifyListeners();
  }

  Future<void> add(AppNotification n) async {
    _notifications.insert(0, n);
    // Keep max 50
    if (_notifications.length > 50) _notifications.removeLast();
    await _persist();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    for (final n in _notifications) {
      n.isRead = true;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    final n = _notifications.firstWhere((n) => n.id == id,
        orElse: () => throw Exception('not found'));
    n.isRead = true;
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _notifications.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      _notifications.map((n) => jsonEncode(n.toJson())).toList(),
    );
  }
}