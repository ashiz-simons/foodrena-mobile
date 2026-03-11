import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

const _kBg      = Color(0xFFF0FAFA);
const _kCard    = Color(0xFFFFFFFF);
const _kCardAlt = Color(0xFFE0F7F7);
const _kTeal    = Color(0xFF00B4B4);
const _kText    = Color(0xFF1A1A1A);
const _kMuted   = Color(0xFF6B8A8A);

class VendorMenuScreen extends StatefulWidget {
  const VendorMenuScreen({super.key});

  @override
  State<VendorMenuScreen> createState() => _VendorMenuScreenState();
}

class _VendorMenuScreenState extends State<VendorMenuScreen> {
  bool loading = true;
  String? uploadingItemId;
  List menuItems = [];

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
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);
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
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Item",
            style: TextStyle(color: _kText, fontWeight: FontWeight.w700)),
        content: const Text("Are you sure you want to delete this item?",
            style: TextStyle(color: _kMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel",
                  style: TextStyle(color: _kMuted))),
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
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                color: _kText, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameCtrl, "Item name"),
              const SizedBox(height: 12),
              _dialogField(descCtrl, "Description"),
              const SizedBox(height: 12),
              _dialogField(priceCtrl, "Price",
                  inputType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",
                style: TextStyle(color: _kMuted)),
          ),
          GestureDetector(
            onTap: onSave,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _kTeal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                title == "Add Item" ? "Add" : "Save",
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
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
      style: const TextStyle(color: _kText, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _kMuted, fontSize: 13),
        filled: true,
        fillColor: _kCardAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
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
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Manage Menu",
            style: TextStyle(
                color: _kText, fontWeight: FontWeight.w700, fontSize: 18)),
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
                          size: 52, color: _kMuted.withOpacity(0.4)),
                      const SizedBox(height: 14),
                      const Text("No menu items yet",
                          style: TextStyle(color: _kMuted, fontSize: 15)),
                      const SizedBox(height: 8),
                      const Text("Tap + to add your first dish",
                          style: TextStyle(color: _kMuted, fontSize: 12)),
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
          backgroundColor: _kCard,
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
                    color: _kMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: _kTeal),
                  title: const Text("Edit",
                      style: TextStyle(color: _kText, fontWeight: FontWeight.w600)),
                  onTap: () { Navigator.pop(context); editMenuItem(item); },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_rounded,
                      color: Colors.redAccent),
                  title: const Text("Delete",
                      style: TextStyle(
                          color: Colors.redAccent, fontWeight: FontWeight.w600)),
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
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.teal.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(15)),
              child: SizedBox(
                width: 72,
                height: 72,
                child: isUploading
                    ? Container(
                        color: _kCardAlt,
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _kTeal),
                          ),
                        ),
                      )
                    : image != null && image["url"] != null
                        ? Image.network(image["url"], fit: BoxFit.cover)
                        : Container(
                            color: _kCardAlt,
                            child: const Icon(Icons.fastfood_rounded,
                                color: _kTeal, size: 28),
                          ),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item["name"],
                        style: const TextStyle(
                            color: _kText,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    if ((item["description"] ?? "").isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(item["description"],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _kMuted, fontSize: 12)),
                    ],
                    const SizedBox(height: 6),
                    Text("₦${item["price"]}",
                        style: const TextStyle(
                            color: _kTeal,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ],
                ),
              ),
            ),

            // Hint
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                children: [
                  Icon(Icons.photo_camera_rounded,
                      size: 16, color: _kMuted.withOpacity(0.5)),
                  const SizedBox(height: 2),
                  Text("tap",
                      style: TextStyle(
                          fontSize: 9, color: _kMuted.withOpacity(0.5))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}