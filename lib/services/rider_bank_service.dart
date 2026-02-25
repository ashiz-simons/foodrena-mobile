import '../services/api_service.dart';

class RiderBankService {
  /// Get rider bank details
  static Future<Map<String, dynamic>?> getMyBank() async {
    final res = await ApiService.get("/riders/me/bank");

    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }

    return null;
  }

  /// Create or update rider bank details
  static Future<Map<String, dynamic>?> saveBank({
    required String accountName,
    required String accountNumber,
    required String bankName,
  }) async {
    final res = await ApiService.post("/riders/me/bank", {
      "accountName": accountName,
      "accountNumber": accountNumber,
      "bankName": bankName,
    });

    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }

    return null;
  }
}
