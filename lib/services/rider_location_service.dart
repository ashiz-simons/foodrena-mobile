import 'dart:async';
import '../services/socket_service.dart';
import '../utils/session.dart';
import '../services/location_service.dart';

/// Continuously emits the rider's GPS location via socket every 5 seconds.
/// Start when rider goes online, stop when they go offline.
class RiderLocationService {
  static Timer? _timer;
  static bool _running = false;

  static Future<void> start() async {
    if (_running) return;
    _running = true;

    print("📍 RiderLocationService started");

    // Send immediately, then every 5 seconds
    await _sendLocation();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _sendLocation();
    });
  }

  static Future<void> _sendLocation() async {
    try {
      final position = await LocationService.getCurrentLocation();
      final riderId = await Session.getUserId();
      if (riderId == null) return;

      SocketService.emit("rider_location_update", {
        "riderId": riderId,
        "lat": position.latitude,
        "lng": position.longitude,
      });

      await Session.saveLocation(position.latitude, position.longitude);
    } catch (e) {
      print("❌ RiderLocationService: $e");
    }
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    print("🛑 RiderLocationService stopped");
  }

  static bool get isRunning => _running;
}