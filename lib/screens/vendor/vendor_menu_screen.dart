import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

const _kTeal = Color(0xFF00B4B4);

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
    await _showItemDialog(
      title: "Edit Item",
      nameCtrl: nameCtrl,
      priceCtrl: priceCtrl,
      descCtrl: descCtrl,
      onSave: () async {
        await ApiService.put("/vendors/menu/${item["_id"]}", {
          "name": nameCtrl.text,
          "description": descCtrl.text,
          "price": double.parse(priceCtrl.text),
        });
        Navigator.pop(context);
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
              child: const Text("Delete", style: TextStyle(color: Colors.redAccent))),
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
      onSave: () async {
        if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
        try {
          await ApiService.post('/vendors/menu', {
            "name": nameCtrl.text,
            "description": descCtrl.text,
            "price": double.parse(priceCtrl.text),
          });
          Navigator.pop(context);
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
    required VoidCallback onSave,
  }) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: TextStyle(color: _text, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameCtrl, "Item name"),
              const SizedBox(height: 12),
              _dialogField(descCtrl, "Description"),
              const SizedBox(height: 12),
              _dialogField(priceCtrl, "Price", inputType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: _muted)),
          ),
          GestureDetector(
            onTap: onSave,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: _kTeal, borderRadius: BorderRadius.circular(10)),
              child: Text(
                title == "Add Item" ? "Add" : "Save",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kTeal, width: 1.5),
        ),
      ),
    );
  }

  void _showMessage(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: _dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Manage Menu",
            style: TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 18)),
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
                      Icon(Icons.restaurant_menu_rounded, size: 52, color: _muted.withOpacity(0.4)),
                      const SizedBox(height: 14),
                      Text("No menu items yet", style: TextStyle(color: _muted, fontSize: 15)),
                      const SizedBox(height: 8),
                      Text("Tap + to add your first dish", style: TextStyle(color: _muted, fontSize: 12)),
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
                  title: Text("Edit", style: TextStyle(color: _text, fontWeight: FontWeight.w600)),
                  onTap: () { Navigator.pop(context); editMenuItem(item); },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                  title: const Text("Delete",
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  onTap: () { Navigator.pop(context); deleteMenuItem(item["_id"]); },
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
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
              child: SizedBox(
                width: 72,
                height: 72,
                child: isUploading
                    ? Container(
                        color: _cardAlt,
                        child: const Center(
                          child: SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _kTeal),
                          ),
                        ),
                      )
                    : image != null && image["url"] != null
                        ? Image.network(image["url"], fit: BoxFit.cover)
                        : Container(
                            color: _cardAlt,
                            child: const Icon(Icons.fastfood_rounded, color: _kTeal, size: 28),
                          ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item["name"],
                        style: TextStyle(color: _text, fontWeight: FontWeight.w600, fontSize: 14)),
                    if ((item["description"] ?? "").isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(item["description"],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _muted, fontSize: 12)),
                    ],
                    const SizedBox(height: 6),
                    Text("₦${item["price"]}",
                        style: const TextStyle(color: _kTeal, fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                children: [
                  Icon(Icons.photo_camera_rounded, size: 16, color: _muted.withOpacity(0.5)),
                  const SizedBox(height: 2),
                  Text("tap", style: TextStyle(fontSize: 9, color: _muted.withOpacity(0.5))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}