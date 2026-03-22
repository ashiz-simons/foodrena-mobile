import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/session.dart';

class SocketService {
  static const String socketUrl = String.fromEnvironment(
    "SOCKET_URL",
    defaultValue: "https://foodrena-backend-1.onrender.com",
  );

  static IO.Socket? _socket;
  static bool _isConnecting = false;
  static String? _currentRoom;

  // ── Multi-listener map ───────────────────────────────────────────────────
  // Maps event -> list of (handlerId, handler) pairs
  static final Map<String, List<_Handler>> _handlers = {};

  static bool get isConnected => _socket?.connected ?? false;

  // ── Connect ───────────────────────────────────────────────────────────────
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
      // Re-register all handlers after reconnect
      _reattachAll();
      print("🟢 Socket connected");
    });

    _socket!.onReconnect((_) {
      print("♻️ Reconnected");
      if (_currentRoom != null) _joinRoom(_currentRoom!);
      _reattachAll();
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

  // ── Join room ─────────────────────────────────────────────────────────────
  static void _joinRoom(String room) {
    if (_socket == null || !_socket!.connected) return;
    if (_currentRoom == room) return;
    _currentRoom = room;
    _socket!.emit("joinRoom", room);
    print("📡 Joined $room");
  }

  // ── Emit ──────────────────────────────────────────────────────────────────
  static void emit(String event, dynamic data) {
    if (_socket == null || !_socket!.connected) {
      print("⚠️ Emit blocked — socket not connected");
      return;
    }
    _socket!.emit(event, data);
  }

  // ── Multi-listener on/off ─────────────────────────────────────────────────
  /// Register a named handler for an event.
  /// [handlerId] identifies this specific handler so it can be removed
  /// without affecting other listeners on the same event.
  /// If [handlerId] is omitted it defaults to the event name (legacy behaviour).
  static void on(String event, Function(dynamic) handler,
      {String? handlerId}) {
    final id = handlerId ?? event;
    _handlers.putIfAbsent(event, () => []);

    // Remove existing handler with same id to avoid duplicates
    _handlers[event]!.removeWhere((h) => h.id == id);
    _handlers[event]!.add(_Handler(id: id, fn: handler));

    // Register a single socket listener that fans out to all handlers
    _socket?.off(event);
    _socket?.on(event, (data) {
      for (final h in List.of(_handlers[event] ?? [])) {
        h.fn(data);
      }
    });
  }

  /// Remove a specific named handler.
  /// If [handlerId] matches a registered handler only that one is removed.
  /// If no [handlerId] given, ALL handlers for the event are removed (legacy).
  static void off(String event, {String? handlerId}) {
    if (handlerId != null) {
      _handlers[event]?.removeWhere((h) => h.id == handlerId);
      // If no handlers left, remove the socket listener entirely
      if (_handlers[event]?.isEmpty ?? true) {
        _handlers.remove(event);
        _socket?.off(event);
      }
      // Otherwise re-register the fan-out with remaining handlers
      else {
        _socket?.off(event);
        _socket?.on(event, (data) {
          for (final h in List.of(_handlers[event] ?? [])) {
            h.fn(data);
          }
        });
      }
    } else {
      // Legacy: remove all handlers for this event
      _handlers.remove(event);
      _socket?.off(event);
    }
  }

  // ── Re-attach all handlers after reconnect ────────────────────────────────
  static void _reattachAll() {
    for (final event in _handlers.keys) {
      _socket?.off(event);
      _socket?.on(event, (data) {
        for (final h in List.of(_handlers[event] ?? [])) {
          h.fn(data);
        }
      });
    }
  }

  // ── Disconnect ────────────────────────────────────────────────────────────
  static void disconnect() {
    _handlers.clear();
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

// ── Internal handler model ────────────────────────────────────────────────
class _Handler {
  final String id;
  final Function(dynamic) fn;
  const _Handler({required this.id, required this.fn});
}