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

  // ── Nearby Riders ────────────────────────────────────────────
  static Future<List<dynamic>> getNearbyRiders(double lat, double lng) async {
    final res = await ApiService.get("/riders/nearby?lat=$lat&lng=$lng");
    return res is List ? res : [];
  }

  // ── Claim Order ──────────────────────────────────────────────
 static Future<Map<String, dynamic>> claimOrder(String orderId) async {
    final res = await ApiService.post("/riders/order/$orderId/claim", {});
    return res is Map<String, dynamic> ? res : {};
  }

  static Future<List<dynamic>> getAvailableOrders({double? lat, double? lng}) async {
    String path = "/orders/available";
    if (lat != null && lng != null) {
      path += "?lat=$lat&lng=$lng";
    }
    final res = await ApiService.get(path);
    return res is List ? res : [];
  }
}
