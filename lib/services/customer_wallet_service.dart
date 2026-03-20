import 'api_service.dart';

class CustomerWalletService {
  static Future<double> getBalance() async {
    final res = await ApiService.get("/customer-wallet");
    return ((res['balance'] ?? 0) as num).toDouble();
  }

  static Future<List<Map<String, dynamic>>> getTransactions() async {
    final res = await ApiService.get("/customer-wallet/transactions");
    if (res is! List) return [];
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    final res = await ApiService.patch("/orders/$orderId/cancel", {});
    return Map<String, dynamic>.from(res);
  }

  static Future<Map<String, dynamic>> payWithWallet(String orderId) async {
    final res = await ApiService.post("/customer-wallet/pay", {"orderId": orderId});
    return Map<String, dynamic>.from(res);
  }
}