import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _instance() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<void> saveToken(String token) async {
    final prefs = await _instance();
    await prefs.setString("token", token);
  }

  static Future<String?> getToken() async {
    final prefs = await _instance();
    return prefs.getString("token");
  }

  /// Save the User object (flat, no nesting)
  static Future<void> saveUser(Map user) async {
    final prefs = await _instance();
    await prefs.setString("user", jsonEncode(user));
  }

  /// Save the Rider profile separately
  /// Backend returns rider.id (not _id) so we normalise to _id here
  static Future<void> saveRiderProfile(Map rider) async {
    final prefs = await _instance();
    // Normalise: backend sends "id", we store as "_id" for consistency
    final normalised = {
      "_id": rider["_id"] ?? rider["id"],
      ...rider,
    };
    await prefs.setString("rider", jsonEncode(normalised));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await _instance();
    final data = prefs.getString("user");
    return data == null ? null : jsonDecode(data);
  }

  static Future<Map<String, dynamic>?> getRiderProfile() async {
    final prefs = await _instance();
    final data = prefs.getString("rider");
    return data == null ? null : jsonDecode(data);
  }

  /// User._id — used for auth headers, profile, orders
  static Future<String?> getUserId() async {
    final user = await getUser();
    return user?["_id"] ?? user?["id"];
  }

  /// ✅ Rider._id — used for socket rooms (rider_<id>) and rider API calls
  /// This is different from User._id
  static Future<String?> getRiderId() async {
    final rider = await getRiderProfile();
    final riderId = rider?["_id"] ?? rider?["id"];
    if (riderId != null) return riderId;
    // Fallback: no rider profile saved yet
    return null;
  }

  static Future<void> saveLocation(double lat, double lng) async {
    final prefs = await _instance();
    await prefs.setDouble("lat", lat);
    await prefs.setDouble("lng", lng);
  }

  static Future<Map<String, double>?> getLocation() async {
    final prefs = await _instance();
    final lat = prefs.getDouble("lat");
    final lng = prefs.getDouble("lng");
    if (lat == null || lng == null) return null;
    return {"lat": lat, "lng": lng};
  }

  static Future<void> saveDeliveryMode(String mode) async {
    final prefs = await _instance();
    await prefs.setString("delivery_mode", mode);
  }

  static Future<String?> getDeliveryMode() async {
    final prefs = await _instance();
    return prefs.getString("delivery_mode");
  }

  static Future<void> clearAuth() async {
    final prefs = await _instance();
    await prefs.remove("token");
    await prefs.remove("user");
    await prefs.remove("rider");
  }

  static Future<void> clearAll() async {
    final prefs = await _instance();
    await prefs.clear();
  }

  static Future<void> clear() async => clearAll();

  static Future<String?> getUserName() async {
    final user = await getUser();
    return user?["name"];
  }
}