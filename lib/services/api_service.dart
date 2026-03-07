import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/session.dart';

class ApiService {
  // ✅ Android emulator  → 10.0.2.2 (loopback to host machine)
  // ✅ Physical device   → your machine's local IP (e.g. 192.168.x.x)
  // ✅ iOS simulator     → localhost or 127.0.0.1
  static String baseUrl = _resolveBaseUrl();

  static String _resolveBaseUrl() {
    const envUrl = String.fromEnvironment("API_URL");
    if (envUrl.isNotEmpty) return envUrl;

    // ✅ Production — always use this when no API_URL is provided
    return "https://foodrena-backend-1.onrender.com/api";
  }

  static Future<Map<String, String>> _headers() async {
    final token = await Session.getToken();
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  static Future<dynamic> get(String path) async {
    final token = await Session.getToken();
    final response = await http.get(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );
    return jsonDecode(response.body);
  }

  static Future<dynamic> post(String path, Map body) async {
    return _request(() async {
      final headers = await _headers();
      return http.post(
        Uri.parse("$baseUrl$path"),
        headers: headers,
        body: jsonEncode(body),
      );
    });
  }

  static Future<dynamic> put(String path, Map body) async {
    return _request(() async {
      final headers = await _headers();
      return http.put(
        Uri.parse("$baseUrl$path"),
        headers: headers,
        body: jsonEncode(body),
      );
    });
  }

  static Future<dynamic> patch(String path, Map body) async {
    return _request(() async {
      final headers = await _headers();
      return http.patch(
        Uri.parse("$baseUrl$path"),
        headers: headers,
        body: jsonEncode(body),
      );
    });
  }

  static Future<dynamic> delete(String path) async {
    return _request(() async {
      final headers = await _headers();
      return http.delete(
        Uri.parse("$baseUrl$path"),
        headers: headers,
      );
    });
  }

  /// ===============================
  /// CENTRAL REQUEST HANDLER
  /// ===============================
  static Future<dynamic> _request(
    Future<http.Response> Function() request,
  ) async {
    try {
      final res = await request().timeout(const Duration(seconds: 15));

      if (res.statusCode == 401) {
        await Session.clearAll();
        throw Exception("Session expired. Please login again.");
      }

      return _decodeResponse(res);
    } on SocketException {
      throw Exception("No internet connection");
    } on HttpException {
      throw Exception("Server error");
    } on FormatException {
      throw Exception("Invalid server response");
    }
  }

  static dynamic _decodeResponse(http.Response res) {
    if (res.body.isEmpty) return null;

    final decoded = jsonDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }

    throw Exception(
      decoded is Map && decoded["message"] != null
          ? decoded["message"]
          : "API Error (${res.statusCode})",
    );
  }

  /// ===============================
  /// FILE UPLOAD
  /// ===============================
  static Future<dynamic> uploadFile(
    String path,
    File file,
    Map<String, String>? fields,
  ) async {
    final token = await Session.getToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl$path"),
    );

    if (token != null) {
      request.headers["Authorization"] = "Bearer $token";
    }

    request.files.add(await http.MultipartFile.fromPath('image', file.path));

    if (fields != null) {
      request.fields.addAll(fields);
    }

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body.isNotEmpty ? jsonDecode(body) : null;
    }

    throw Exception("Upload failed (${response.statusCode})");
  }

  /// ===============================
  /// RIDER LOCATION UPDATE
  /// ===============================
  static Future<void> sendRiderLocation(double lat, double lng) async {
    await post("/rider/location", {
      "location": {
        "type": "Point",
        "coordinates": [lng, lat]
      }
    });
  }
}