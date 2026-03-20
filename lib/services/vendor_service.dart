import 'api_service.dart';

class VendorService {
  /// Get my vendor profile
  static Future<Map<String, dynamic>> getMe() async {
    final res = await ApiService.get('/vendors/me');

    if (res is Map<String, dynamic>) {
        // unwrap common backend response shapes
        if (res.containsKey("vendor")) {
        return res["vendor"];
        }
        if (res.containsKey("data")) {
        return res["data"];
        }
        return res; // already flat
    }

    return {};
    }


  /// Get vendor orders
  static Future<List> getOrders() async {
    final res = await ApiService.get('/orders/vendor');
    return res is List ? res : [];
  }

  /// Update vendor availability (OPEN / CLOSED)
  static Future<void> toggleAvailability(bool isOpen) async {
    await ApiService.put('/vendors/me', {
      'isOpen': isOpen,
    });
  }

  static Future<void> updateOrderStatus(String id, String status) async {
    await ApiService.patch('/orders/$id/status', {
        "status": status,
    });
    }

  static Future<void> updateProfile(Map data) async {
    await ApiService.put('/vendors/me', data);
  }

  // ── Preferred Riders ────────────────────────────────────────

  static Future<Map<String, dynamic>> getPreferredRiders() async {
    final res = await ApiService.get('/vendors/preferred-riders');
    return res is Map<String, dynamic> ? res : {};
  }

  static Future<void> addPreferredRider(String riderId) async {
    await ApiService.post('/vendors/preferred-riders/$riderId', {});
  }

  static Future<void> removePreferredRider(String riderId) async {
    await ApiService.delete('/vendors/preferred-riders/$riderId');
  }

  static Future<void> updatePreferredRiderSettings({
    required bool usePreferredRiders,
    required bool fallbackToAutoAssign,
  }) async {
    await ApiService.patch('/vendors/preferred-riders/settings', {
      'usePreferredRiders': usePreferredRiders,
      'fallbackToAutoAssign': fallbackToAutoAssign,
    });
  }

    /// Get vendor bank
    static Future<Map<String, dynamic>> getBank() async {
    final res = await ApiService.get('/vendors/me/bank');
    return res is Map<String, dynamic> ? res : {};
    }

    /// Save vendor bank
    static Future<void> saveBank(Map data) async {
    await ApiService.post('/vendors/me/bank', data);
    }
  
}
