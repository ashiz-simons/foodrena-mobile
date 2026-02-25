import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/session.dart';

class SocketService {
  static IO.Socket? socket;

  static Future<void> connect(String riderId) async {
    if (socket != null && socket!.connected) return;

    final token = await Session.getToken();

    socket = IO.io(
      "http://10.0.2.2:4000",
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({"token": token})
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );

    socket!.connect();

    socket!.onConnect((_) {
      print("🟢 Rider socket connected");
      socket!.emit("joinRoom", "rider_$riderId");
    });
  }

  static Future<void> connectVendor(String vendorId) async {
    if (socket != null && socket!.connected) return;

    final token = await Session.getToken();

    socket = IO.io(
      "http://10.0.2.2:4000",
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({"token": token})
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );

    socket!.connect();

    socket!.onConnect((_) {
      print("🟢 Vendor socket connected");
      socket!.emit("joinRoom", "vendor_$vendorId");
    });
  }

  static void on(String event, Function(dynamic) handler) {
    if (socket == null) return;
    socket!.on(event, handler);
  }

  static void disconnect() {
    socket?.disconnect();
    socket = null;
  }

  static void sendLocation({
    required String riderId,
    required double lat,
    required double lng,
  }) {
    if (socket == null || !socket!.connected) return;

    socket!.emit("rider_location_update", {
      "riderId": riderId,
      "lat": lat,
      "lng": lng,
    });
  }

}
