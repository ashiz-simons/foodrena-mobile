import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

const _kTeal = Color(0xFF00B4B4);

const _kCategories = [
  "Swallow", "Drinks", "Snacks", "Soups", "Pasta",
  "Burgers", "Shawarma", "Rice", "Cakes", "Grills", "Other",
];

class VendorMenuScreen extends StatefulWidget {
  const VendorMenuScreen({super.key});

  @override
  State<VendorMenuScreen> createState() => _VendorMenuScreenState();
}

class _VendorMenuScreenState extends State<VendorMenuScreen> {
  bool loading = true;
  String? uploadingItemId;
  List menuItems = [];

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg      => _dark ? const Color(0xFF081818) : const Color(0xFFF0FAFA);
  Color get _card    => _dark ? const Color(0xFF0F2828) : Colors.white;
  Color get _cardAlt => _dark ? const Color(0xFF163535) : const Color(0xFFE0F7F7);
  Color get _text    => _dark ? Colors.white : const Color(0xFF1A1A1A);
  Color get _muted   => _dark ? Colors.grey.shade400 : const Color(0xFF6B8A8A);
  Color get _border  => _dark ? Colors.teal.withOpacity(0.18) : Colors.teal.withOpacity(0.10);

  @override
  void initState() {
    super.initState();
    loadMenu();
  }

  Future<void> loadMenu() async {
    try {
      final res = await ApiService.get('/vendors/menu');
      setState(() {
        menuItems = res?["menuItems"] ?? [];
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      _showMessage("Failed to load menu");
    }
  }

  Future<void> uploadMenuImage(String menuItemId) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    setState(() => uploadingItemId = menuItemId);
    try {
      final uploadRes = await ApiService.uploadFile(
          "/upload", File(picked.path), {"folder": "vendors/menu"});
      await ApiService.patch("/vendors/menu/$menuItemId/image", {
        "imageUrl": uploadRes["url"],
        "publicId": uploadRes["publicId"],
      });
      _showMessage("Image updated");
      await loadMenu();
    } catch (e) {
      _showMessage("Upload failed");
    }
    setState(() => uploadingItemId = null);
  }

  Future<void> editMenuItem(Map item) async {
    final nameCtrl  = TextEditingController(text: item["name"]);
    final priceCtrl = TextEditingController(text: item["price"].toString());
    final descCtrl  = TextEditingController(text: item["description"] ?? "");
    String selectedCategory = item["category"] ?? "Other";
    final List<Map<String, dynamic>> addOns = item["addOns"] != null
        ? List<Map<String, dynamic>>.from(
            (item["addOns"] as List).map((a) => {
              "name": a["name"] ?? "",
              "price": (a["price"] ?? 0).toString(),
            }))
        : [];

    await _showItemDialog(
      title: "Edit Item",
      nameCtrl: nameCtrl,
      priceCtrl: priceCtrl,
      descCtrl: descCtrl,
      initialCategory: selectedCategory,
      initialAddOns: addOns,
      onSave: (category, addOnsList) async {
        await ApiService.put("/vendors/menu/${item["_id"]}", {
          "name": nameCtrl.text,
          "description": descCtrl.text,
          "price": double.parse(priceCtrl.text),
          "category": category,
          "addOns": addOnsList.map((a) => {
            "name": a["name"],
            "price": double.tryParse(a["price"].toString()) ?? 0,
          }).toList(),
        });
        if (mounted) Navigator.pop(context);
        loadMenu();
      },
    );
  }

  Future<void> deleteMenuItem(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Delete Item",
            style: TextStyle(color: _text, fontWeight: FontWeight.w700)),
        content: Text("Are you sure you want to delete this item?",
            style: TextStyle(color: _muted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel", style: TextStyle(color: _muted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete",
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true) return;
    await ApiService.delete("/vendors/menu/$id");
    loadMenu();
  }

  void showAddItemDialog() {
    final nameCtrl  = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    _showItemDialog(
      title: "Add Item",
      nameCtrl: nameCtrl,
      priceCtrl: priceCtrl,
      descCtrl: descCtrl,
      initialCategory: "Other",
      initialAddOns: [],
      onSave: (category, addOnsList) async {
        if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
        try {
          await ApiService.post('/vendors/menu', {
            "name": nameCtrl.text,
            "description": descCtrl.text,
            "price": double.parse(priceCtrl.text),
            "category": category,
            "addOns": addOnsList.map((a) => {
              "name": a["name"],
              "price": double.tryParse(a["price"].toString()) ?? 0,
            }).toList(),
          });
          if (mounted) Navigator.pop(context);
          loadMenu();
        } catch (_) {
          _showMessage("Failed to add item");
        }
      },
    );
  }

  Future<void> _showItemDialog({
    required String title,
    required TextEditingController nameCtrl,
    required TextEditingController priceCtrl,
    required TextEditingController descCtrl,
    required String initialCategory,
    required List<Map<String, dynamic>> initialAddOns,
    required Function(String category, List<Map<String, dynamic>> addOns) onSave,
    }) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: _card,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _MenuItemDialog(
          title: title,
          nameCtrl: nameCtrl,
          priceCtrl: priceCtrl,
          descCtrl: descCtrl,
          initialCategory: initialCategory,
          initialAddOns: initialAddOns,
          onSave: onSave,
          card: _card,
          cardAlt: _cardAlt,
          text: _text,
          muted: _muted,
        ),
      );
    }
          
  Widget _dialogField(TextEditingController ctrl, String label,
      {TextInputType inputType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      style: TextStyle(color: _text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _muted, fontSize: 13),
        filled: true,
        fillColor: _cardAlt,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kTeal, width: 1.5),
        ),
      ),
    );
  }

  void _showMessage(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle:
            _dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Manage Menu",
            style: TextStyle(
                color: _text, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _kTeal,
        onPressed: showAddItemDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _kTeal))
          : menuItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restaurant_menu_rounded,
                          size: 52, color: _muted.withOpacity(0.4)),
                      const SizedBox(height: 14),
                      Text("No menu items yet",
                          style: TextStyle(color: _muted, fontSize: 15)),
                      const SizedBox(height: 8),
                      Text("Tap + to add your first dish",
                          style: TextStyle(color: _muted, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: menuItems.length,
                  itemBuilder: (_, i) => _menuItemCard(menuItems[i]),
                ),
    );
  }

  Widget _menuItemCard(Map item) {
    final image = item["image"];
    final isUploading = uploadingItemId == item["_id"];
    final category = item["category"] ?? "Other";
    final addOns = item["addOns"] as List? ?? [];

    return GestureDetector(
      onTap: () => uploadMenuImage(item["_id"]),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showModalBottomSheet(
          context: context,
          backgroundColor: _card,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _muted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: _kTeal),
                  title: Text("Edit",
                      style: TextStyle(
                          color: _text, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    editMenuItem(item);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_rounded,
                      color: Colors.redAccent),
                  title: const Text("Delete",
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    deleteMenuItem(item["_id"]);
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(_dark ? 0.15 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            // ── Image ─────────────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(15)),
              child: SizedBox(
                width: 72,
                height: 72,
                child: isUploading
                    ? Container(
                        color: _cardAlt,
                        child: const Center(
                          child: SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _kTeal),
                          ),
                        ),
                      )
                    : image != null && image["url"] != null
                        ? Image.network(image["url"], fit: BoxFit.cover)
                        : Container(
                            color: _cardAlt,
                            child: const Icon(Icons.fastfood_rounded,
                                color: _kTeal, size: 28),
                          ),
              ),
            ),

            // ── Details ───────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item["name"],
                              style: TextStyle(
                                  color: _text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(category,
                              style: const TextStyle(
                                  color: _kTeal,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    if ((item["description"] ?? "").isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(item["description"],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _muted, fontSize: 12)),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text("₦${item["price"]}",
                            style: const TextStyle(
                                color: _kTeal,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        if (addOns.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            "+${addOns.length} add-on${addOns.length > 1 ? 's' : ''}",
                            style: TextStyle(
                                color: _muted, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                children: [
                  Icon(Icons.photo_camera_rounded,
                      size: 16, color: _muted.withOpacity(0.5)),
                  const SizedBox(height: 2),
                  Text("tap",
                      style: TextStyle(
                          fontSize: 9, color: _muted.withOpacity(0.5))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItemDialog extends StatefulWidget {
  final String title;
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController descCtrl;
  final String initialCategory;
  final List<Map<String, dynamic>> initialAddOns;
  final Function(String, List<Map<String, dynamic>>) onSave;
  final Color card;
  final Color cardAlt;
  final Color text;
  final Color muted;

  const _MenuItemDialog({
    required this.title,
    required this.nameCtrl,
    required this.priceCtrl,
    required this.descCtrl,
    required this.initialCategory,
    required this.initialAddOns,
    required this.onSave,
    required this.card,
    required this.cardAlt,
    required this.text,
    required this.muted,
  });

  @override
  State<_MenuItemDialog> createState() => _MenuItemDialogState();
}

class _MenuItemDialogState extends State<_MenuItemDialog> {
  late String selectedCategory;
  late List<Map<String, dynamic>> addOns;
  final addOnNameCtrl  = TextEditingController();
  final addOnPriceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.initialCategory;
    addOns = List<Map<String, dynamic>>.from(widget.initialAddOns);
  }

  @override
  void dispose() {
    addOnNameCtrl.dispose();
    addOnPriceCtrl.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType inputType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      style: TextStyle(color: widget.text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: widget.muted, fontSize: 13),
        filled: true,
        fillColor: widget.cardAlt,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kTeal, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: widget.muted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(widget.title,
                style: TextStyle(
                    color: widget.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
            const SizedBox(height: 20),

            _field(widget.nameCtrl, "Item name"),
            const SizedBox(height: 12),
            _field(widget.descCtrl, "Description (optional)"),
            const SizedBox(height: 12),
            _field(widget.priceCtrl, "Price (₦)",
                inputType: TextInputType.number),
            const SizedBox(height: 12),

            // Category
            Text("Category",
                style: TextStyle(
                    color: widget.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: widget.cardAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  dropdownColor: widget.card,
                  style: TextStyle(color: widget.text, fontSize: 14),
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: widget.muted),
                  items: _kCategories
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => selectedCategory = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Add-ons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Add-ons",
                    style: TextStyle(
                        color: widget.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                Text("optional",
                    style: TextStyle(color: widget.muted, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 10),

            // Existing add-ons
            ...addOns.asMap().entries.map((entry) {
              final i = entry.key;
              final addon = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.cardAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${addon["name"]} — ₦${addon["price"]}",
                        style: TextStyle(
                            color: widget.text, fontSize: 13),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => addOns.removeAt(i)),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.redAccent, size: 18),
                    ),
                  ],
                ),
              );
            }),

            // New add-on row
            Row(
              children: [
                Expanded(
                    flex: 5,
                    child: _field(addOnNameCtrl, "Add-on name")),
                const SizedBox(width: 8),
                Expanded(
                    flex: 3,
                    child: _field(addOnPriceCtrl, "Price",
                        inputType: TextInputType.number)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    final name  = addOnNameCtrl.text.trim();
                    final price = addOnPriceCtrl.text.trim();
                    if (name.isEmpty || price.isEmpty) return;
                    setState(() {
                      addOns.add({"name": name, "price": price});
                      addOnNameCtrl.clear();
                      addOnPriceCtrl.clear();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kTeal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => widget.onSave(selectedCategory, addOns),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  widget.title == "Add Item"
                      ? "Add to menu"
                      : "Save changes",
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}