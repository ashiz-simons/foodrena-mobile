import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = "http://10.0.2.2:4000/api/auth";

  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", data["token"]);
        await prefs.setString("role", data["user"]["role"]);

        return data;
      }

      return {"error": data["message"] ?? "Login failed"};
    } catch (e) {
      return {"error": "Network error"};
    }
  }
}
