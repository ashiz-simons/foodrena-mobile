import '../services/api_service.dart';

class RiderService {

 static Future<List<dynamic>> getMyOrders() async {
    final res = await ApiService.get("/riders/me/orders");

    if (res is List) {
      return List<dynamic>.from(res);
    }

    if (res is Map && res["orders"] is List) {
      return List<dynamic>.from(res["orders"]);
    }

    return [];
  }


  static Future toggleAvailability(bool status) async {
    await ApiService.patch("/riders/availability", {
      "isAvailable": status
    });
  }

  static Future accept(String id) async {
    await ApiService.post("/riders/order/$id/accept", {});
  }

  static Future reject(String id) async {
    await ApiService.post("/riders/order/$id/reject", {});
  }

  static Future arrived(String id) async {
    await ApiService.post("/riders/order/$id/arrived", {});
  }

  static Future startTrip(String id) async {
    await ApiService.post("/riders/order/$id/start-trip", {});
  }

  static Future complete(String id) async {
    await ApiService.post("/riders/order/$id/complete", {});
  }

  static Future<Map<String, dynamic>> getWallet() async {
    final res = await ApiService.get("/riders/me/wallet");
    return Map<String, dynamic>.from(res);
  }

  static Future<List<dynamic>> getWithdrawals() async {
    final res = await ApiService.get("/riders/withdrawals");
    return res is List ? res : [];
  }

  static Future<void> withdraw(double amount) async {
    await ApiService.post("/riders/withdrawals", {
      "amount": amount,
    });
  }
}
