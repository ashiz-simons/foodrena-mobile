import 'api_service.dart';

class VendorWalletService {
  static Future<Map<String, dynamic>> getWallet() async {
    final res = await ApiService.get('/wallet');
    return Map<String, dynamic>.from(res);
  }

  static Future<List<dynamic>> getWithdrawals() async {
    final res = await ApiService.get('/vendor-wallet/withdrawals');
    return res is List ? res : [];
  }

  static Future<void> withdraw(double amount) async {
    await ApiService.post('/wallet/withdraw', {
      "amount": amount,
    });
  }
}
