import 'api_service.dart';
import '../models/vendor_model.dart';
import '../models/menu_item_model.dart';

class CustomerVendorService {
  /// =======================
  /// GET ALL VENDORS
  /// =======================
  static Future<List<Vendor>> getVendors({
    double? lat,
    double? lng,
    String? category,
  }) async {
    String path = "/vendors";
    final params = <String>[];
    if (lat != null && lng != null) {
      params.add("lat=$lat&lng=$lng");
    }
    if (category != null) {
      params.add("category=${Uri.encodeComponent(category)}");
    }
    if (params.isNotEmpty) path += "?${params.join('&')}";
    final res = await ApiService.get(path);

    if (res is! List) return [];

    return res.map((e) => Vendor.fromJson(e)).toList();
  }

  /// =======================
  /// GET VENDOR MENU
  /// =======================
  static Future<List<MenuItem>> getVendorMenu(String vendorId) async {
    final res = await ApiService.get("/vendors/$vendorId/menu");

    if (res is! List) return [];

    return res.map((e) => MenuItem.fromJson(e)).toList();
  }
}