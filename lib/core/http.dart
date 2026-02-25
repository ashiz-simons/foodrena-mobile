import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'storage.dart';

class Api {
  static Future<http.Response> get(String path) async {
    final token = await Storage.getToken();
    return http.get(
      Uri.parse("${AppConfig.baseUrl}$path"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
  }

  static Future<http.Response> post(String path, Map body) async {
    final token = await Storage.getToken();
    return http.post(
      Uri.parse("${AppConfig.baseUrl}$path"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> patch(String path, Map body) async {
    final token = await Storage.getToken();
    return http.patch(
      Uri.parse("${AppConfig.baseUrl}$path"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );
  }
}
