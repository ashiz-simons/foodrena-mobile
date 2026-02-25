class OrderService {
  static Future<OrderModel> fetchOrder(String orderId, String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/orders/$orderId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch order');
    }

    return OrderModel.fromJson(jsonDecode(response.body));
  }
}