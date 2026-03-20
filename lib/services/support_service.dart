import 'api_service.dart';

class SupportService {
  // ── Tickets ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> createTicket({
    required String category,
    required String subject,
    required String description,
    String? orderId,
  }) async {
    final res = await ApiService.post("/support", {
      "category":    category,
      "subject":     subject,
      "description": description,
      if (orderId != null) "orderId": orderId,
    });
    return res["ticket"] as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> myTickets() async {
    final res = await ApiService.get("/support/mine");
    return List<Map<String, dynamic>>.from(res["tickets"] ?? []);
  }

  static Future<Map<String, dynamic>> getTicket(String id) async {
    final res = await ApiService.get("/support/$id");
    return res["ticket"] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> sendMessage(String ticketId, String text) async {
    final res = await ApiService.post("/support/$ticketId/message", {"text": text});
    return res["ticket"] as Map<String, dynamic>;
  }
}