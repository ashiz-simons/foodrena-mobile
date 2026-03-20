import 'api_service.dart';

class VerificationService {
  /// Submit NIN or Driver's License for verification
  static Future<Map<String, dynamic>> verifyIdentity({
    required String type, // "nin" or "drivers_license"
    required String number,
  }) async {
    final res = await ApiService.post("/verification/identity", {
      "type":   type,
      "number": number,
    });
    return res is Map<String, dynamic> ? res : {};
  }

  /// Get current verification status
  static Future<Map<String, dynamic>> getStatus() async {
    final res = await ApiService.get("/verification/identity/status");
    return res is Map<String, dynamic> ? res : {};
  }
}