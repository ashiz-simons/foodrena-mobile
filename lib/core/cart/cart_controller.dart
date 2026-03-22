import 'package:flutter/foundation.dart';
import '../../models/menu_item_model.dart';

class CartEntry {
  final MenuItem item;
  int quantity;
  final List<AddOn> selectedAddOns;

  CartEntry({
    required this.item,
    this.quantity = 1,
    this.selectedAddOns = const [],
  });

  double get addOnsTotal =>
      selectedAddOns.fold(0, (sum, a) => sum + a.price);

  double get lineTotal => (item.price + addOnsTotal) * quantity;
}

class CartController extends ChangeNotifier {
  final List<CartEntry> _items = [];
  String? _vendorId;

  List<CartEntry> get items => _items;
  String? get vendorId => _vendorId;

  bool get isEmpty => _items.isEmpty;

  double get total =>
      _items.fold(0, (sum, e) => sum + e.lineTotal);

  void add(MenuItem item, String vendorId,
      {List<AddOn> selectedAddOns = const []}) {
    if (_vendorId != null && _vendorId != vendorId) {
      _items.clear();
    }
    _vendorId = vendorId;

    // If no add-ons, merge with existing entry of same item
    if (selectedAddOns.isEmpty) {
      final index =
          _items.indexWhere((e) => e.item.id == item.id && e.selectedAddOns.isEmpty);
      if (index >= 0) {
        _items[index].quantity++;
        notifyListeners();
        return;
      }
    }

    // Add-ons present or no existing entry — always new line
    _items.add(CartEntry(
        item: item, selectedAddOns: selectedAddOns));
    notifyListeners();
  }

  void remove(String itemId) {
    final index =
        _items.indexWhere((e) => e.item.id == itemId);
    if (index < 0) return;

    if (_items[index].quantity > 1) {
      _items[index].quantity--;
    } else {
      _items.removeAt(index);
    }

    if (_items.isEmpty) _vendorId = null;
    notifyListeners();
  }

  void removeAll(String itemId) {
    _items.removeWhere((e) => e.item.id == itemId);
    if (_items.isEmpty) _vendorId = null;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _vendorId = null;
    notifyListeners();
  }
}