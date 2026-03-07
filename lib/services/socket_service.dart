import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/session.dart';

class SocketService {
  // ✅ Fixed: points to Render backend, no longer uses local IP
  static const String socketUrl = String.fromEnvironment(
    "SOCKET_URL",
    defaultValue: "https://foodrena-backend-1.onrender.com",
  );

  static IO.Socket? _socket;
  static bool _isConnecting = false;
  static String? _currentRoom;

  static bool get isConnected => _socket?.connected ?? false;

  /// ===============================
  /// CONNECT GENERIC
  /// ===============================
  static Future<void> connectToRoom(String room) async {
    if (_socket != null && _socket!.connected) {
      _joinRoom(room);
      return;
    }

    if (_isConnecting) return;
    _isConnecting = true;

    final token = await Session.getToken();
    if (token == null) {
      _isConnecting = false;
      return;
    }

    _socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({"token": token})
          .enableReconnection()
          .setReconnectionAttempts(20)
          .setReconnectionDelay(2000)
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _isConnecting = false;
      _joinRoom(room);
      print("🟢 Socket connected");
    });

    _socket!.onReconnect((_) {
      print("♻️ Reconnected");
      if (_currentRoom != null) _joinRoom(_currentRoom!);
    });

    _socket!.onDisconnect((_) {
      print("🔴 Disconnected");
      _isConnecting = false;
    });

    _socket!.onConnectError((err) {
      print("❌ Connect error: $err");
      _isConnecting = false;
    });
  }

  /// ===============================
  /// JOIN ROOM SAFE
  /// ===============================
  static void _joinRoom(String room) {
    if (_socket == null || !_socket!.connected) return;
    if (_currentRoom == room) return;
    _currentRoom = room;
    _socket!.emit("joinRoom", room);
    print("📡 Joined $room");
  }

  /// ===============================
  /// SAFE EMIT
  /// ===============================
  static void emit(String event, dynamic data) {
    if (_socket == null || !_socket!.connected) {
      print("⚠️ Emit blocked — socket not connected");
      return;
    }
    _socket!.emit(event, data);
  }

  /// ===============================
  /// SAFE LISTENER
  /// ===============================
  static void on(String event, Function(dynamic) handler) {
    if (_socket == null) return;
    _socket!.off(event);
    _socket!.on(event, handler);
  }

  static void off(String event) => _socket?.off(event);

  /// ===============================
  /// CLEAN DESTROY
  /// ===============================
  static void disconnect() {
    _socket?.clearListeners();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _currentRoom = null;
    print("🛑 Socket destroyed");
  }

  static Future<void> connectVendor(String vendorId) async {
    await connectToRoom("vendor_$vendorId");
  }
}