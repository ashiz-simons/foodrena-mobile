import 'api_service.dart';
import 'socket_service.dart';

class ChatService {
  // ── REST ────────────────────────────────────────────────────

  static Future<List<dynamic>> getMessages(String orderId) async {
    final res = await ApiService.get("/chat/$orderId");
    return res is List ? res : [];
  }

  static Future<Map<String, dynamic>> sendMessage({
    required String orderId,
    required String text,
    required String senderRole,
  }) async {
    final res = await ApiService.post("/chat/$orderId", {
      "text": text,
      "senderRole": senderRole,
    });
    return res is Map<String, dynamic> ? res : {};
  }

  static Future<Map<String, dynamic>> generateCallToken({
    required String orderId,
    int uid = 0,
  }) async {
    final res = await ApiService.post("/chat/calls/token", {
      "orderId": orderId,
      "uid": uid,
    });
    return res is Map<String, dynamic> ? res : {};
  }

  // ── Socket ───────────────────────────────────────────────────

  static void onMessageReceived(Function(Map<String, dynamic>) handler) {
    SocketService.on("receive_message", (data) {
      if (data is Map<String, dynamic>) handler(data);
    });
  }

  static void offMessageReceived() {
    SocketService.off("receive_message");
  }

  static void onCallInvite(Function(Map<String, dynamic>) handler) {
    SocketService.on("call_invite", (data) {
      if (data is Map<String, dynamic>) handler(data);
    });
  }

  static void offCallInvite() {
    SocketService.off("call_invite");
  }

  static void onCallAccepted(Function(Map<String, dynamic>) handler) {
    SocketService.on("call_accepted", (data) {
      if (data is Map<String, dynamic>) handler(data);
    });
  }

  static void onCallDeclined(Function(Map<String, dynamic>) handler) {
    SocketService.on("call_declined", (data) {
      if (data is Map<String, dynamic>) handler(data);
    });
  }

  static void onCallEnded(Function(Map<String, dynamic>) handler) {
    SocketService.on("call_ended", (data) {
      if (data is Map<String, dynamic>) handler(data);
    });
  }

  static void offAllCallEvents() {
    SocketService.off("call_invite");
    SocketService.off("call_accepted");
    SocketService.off("call_declined");
    SocketService.off("call_ended");
  }

  static void emitCallAccepted(String orderId, String calleeId) {
    SocketService.emit("call_accepted", {
      "orderId": orderId,
      "calleeId": calleeId,
    });
  }

  static void emitCallDeclined(String orderId) {
    SocketService.emit("call_declined", {"orderId": orderId});
  }

  static void emitCallEnded(String orderId) {
    SocketService.emit("call_ended", {"orderId": orderId});
  }
}