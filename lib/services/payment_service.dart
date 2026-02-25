import 'api_service.dart';

class PaymentService {
  static Future<Map<String, dynamic>> initiatePayment(String orderId) async {
    final res = await ApiService.post(
      "/payments/initiate",
      {"orderId": orderId},
    );

    if (res == null || res["authorization_url"] == null) {
      throw Exception("Payment initialization failed");
    }

    return res;
  }

  static Future<void> verifyPayment(String reference) async {
    await ApiService.get("/payments/verify/$reference");
  }
}