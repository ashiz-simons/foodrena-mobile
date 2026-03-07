import '../services/api_service.dart';
import '../models/order_model.dart';

class OrderService {
  static Future<OrderModel> fetchOrder(
      String orderId) async {
    final res =
        await ApiService.get("/orders/$orderId");
    return OrderModel.fromJson(res);
  }

  static Future<List<Map<String, dynamic>>>
      fetchMyOrders() async {
    final res =
        await ApiService.get("/orders/my");

    if (res is! List) return [];

    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>>
      fetchActiveOrders() async {
    final orders = await fetchMyOrders();

    return orders.where((o) {
      final status = o["status"];
      return status != "delivered" &&
          status != "cancelled" &&
          status != "refunded";
    }).toList();
  }

  static Future<List<Map<String, dynamic>>>
      fetchOrderHistory() async {
    final orders = await fetchMyOrders();

    return orders.where((o) {
      final status = o["status"];
      return status == "delivered" ||
          status == "cancelled" ||
          status == "refunded";
    }).toList();
  }
}