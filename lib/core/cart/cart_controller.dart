import 'package:flutter/foundation.dart';
import '../../models/menu_item_model.dart';

class CartEntry {
  final MenuItem item;
  int quantity;

  CartEntry({required this.item, this.quantity = 1});
}

class CartController extends ChangeNotifier {
  final List<CartEntry> _items = [];
  String? _vendorId;

  List<CartEntry> get items => _items;
  String? get vendorId => _vendorId;

  bool get isEmpty => _items.isEmpty;

  double get total {
    return _items.fold(0, (sum, e) => sum + (e.item.price * e.quantity));
  }

  void add(MenuItem item, String vendorId) {
    if (_vendorId != null && _vendorId != vendorId) {
      _items.clear();
    }
    _vendorId = vendorId;

    final index = _items.indexWhere((e) => e.item.id == item.id);
    if (index >= 0) {
      _items[index].quantity++;
    } else {
      _items.add(CartEntry(item: item));
    }
    notifyListeners();
  }

  // Decrease quantity by 1, remove if it hits 0
  void remove(String itemId) {
    final index = _items.indexWhere((e) => e.item.id == itemId);
    if (index < 0) return;

    if (_items[index].quantity > 1) {
      _items[index].quantity--;
    } else {
      _items.removeAt(index);
    }

    if (_items.isEmpty) _vendorId = null;
    notifyListeners();
  }

  // Remove item entirely regardless of quantity
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