import 'api_service.dart';

class PromoService {
  /// Fetch active promos for the home screen banner (no auth needed)
  static Future<List> getPublicPromos() async {
    final res = await ApiService.get('/promos/public');
    return res is List ? res : [];
  }

  /// Apply a promo code at checkout
  /// Returns { valid, type, discountPercent, discountAmount, message, promoId }
  static Future<Map> applyCode({
    required String code,
    required double orderTotal,
  }) async {
    final res = await ApiService.post('/promos/apply', {
      "code":       code,
      "orderTotal": orderTotal,
    });
    return res as Map;
  }

  // ── Vendor ──────────────────────────────────────────────────────────────
  static Future<List> getVendorPromos() async {
    final res = await ApiService.get('/promos/vendor');
    return res is List ? res : [];
  }

  static Future<void> createVendorPromo(Map<String, dynamic> body) async {
    await ApiService.post('/promos/vendor', body);
  }

  static Future<void> deleteVendorPromo(String id) async {
    await ApiService.delete('/promos/vendor/$id');
  }
}