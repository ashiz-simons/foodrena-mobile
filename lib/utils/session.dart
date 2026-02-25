import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("token", token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token");
  }

  static Future<void> saveUser(Map user) async {
    final prefs = await SharedPreferences.getInstance();

    if (user.containsKey("user")) user = user["user"];
    if (user.containsKey("rider")) user = user["rider"];

    await prefs.setString("user", jsonEncode(user));
  }

  static Future<Map?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString("user");
    return data == null ? null : jsonDecode(data);
  }

  static Future<String?> getUserId() async {
    final user = await getUser();
    return user?["_id"] ?? user?["id"];
  }

  static Future<String?> getUserName() async {
    final user = await getUser();
    return user?["name"];
  }

  // ✅ LOCATION (STANDARD)
  static Future<void> saveLocation(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble("lat", lat);
    await prefs.setDouble("lng", lng);
  }

  static Future<Map<String, double>?> getLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble("lat");
    final lng = prefs.getDouble("lng");

    if (lat == null || lng == null) return null;
    return {"lat": lat, "lng": lng};
  }

  static Future<void> saveDeliveryMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("delivery_mode", mode);
  }

  static Future<String?> getDeliveryMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("delivery_mode");
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}