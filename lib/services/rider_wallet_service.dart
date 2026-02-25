import 'api_service.dart';

class RiderWalletService {
  static Future<Map<String, dynamic>> getWallet() async {
    final res = await ApiService.get("/riders/me/wallet");
    return Map<String, dynamic>.from(res);
  }

  static Future<List<dynamic>> getWithdrawals() async {
    final res = await ApiService.get("/riders/withdrawals");

    if (res is List) {
      return List<dynamic>.from(res);
    }

    return [];
  }

  static Future<void> withdraw(double amount) async {
    await ApiService.post("/riders/withdrawals", {
      "amount": amount,
    });
  }
}
