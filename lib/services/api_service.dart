import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/session.dart';

class ApiService {
  static const String baseUrl = "http://10.0.2.2:4000/api";

  /// =======================
  /// POST
  /// =======================
  static Future<dynamic> post(String path, Map body) async {
    final token = await Session.getToken();

    final res = await http.post(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    return _decodeResponse(res);
  }

  /// =======================
  /// GET
  /// =======================
  static Future<dynamic> get(String path) async {
    final token = await Session.getToken();

    final res = await http.get(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    return _decodeResponse(res);
  }

  /// =======================
  /// PUT
  /// =======================
  static Future<dynamic> put(String path, Map body) async {
    final token = await Session.getToken();

    final res = await http.put(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    return _decodeResponse(res);
  }

  /// =======================
  /// PATCH
  /// =======================
  static Future<dynamic> patch(String path, Map body) async {
    final token = await Session.getToken();

    final res = await http.patch(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    return _decodeResponse(res);
  }

  /// =======================
  /// RIDER LOCATION
  /// =======================
  static Future<void> sendRiderLocation(double lat, double lng) async {
    await patch("/riders/location", {
      "lat": lat,
      "lng": lng,
    });
  }

  /// =======================
  /// RESPONSE HANDLER
  /// =======================
  static dynamic _decodeResponse(http.Response res) {
    if (res.body.isEmpty) return null;

    try {
      return jsonDecode(res.body);
    } catch (_) {
      return null;
    }
  }
}
