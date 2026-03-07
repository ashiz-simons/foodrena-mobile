import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

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
      source: ImageSource.gallery,
      imageQuality: 70, // compress
    );

    if (picked == null) return;

    setState(() => uploadingItemId = menuItemId);

    try {
      File imageFile = File(picked.path);

      // 1️⃣ Upload to backend
      final uploadRes = await ApiService.uploadFile(
        "/upload",
        imageFile,
        {
          "folder": "vendors/menu",
        },
      );

      final imageUrl = uploadRes["url"];
      final publicId = uploadRes["publicId"];

      // 2️⃣ Patch menu item
      await ApiService.patch(
        "/vendors/menu/$menuItemId/image",
        {
          "imageUrl": imageUrl,
          "publicId": publicId,
        },
      );

      _showMessage("Image updated");
      await loadMenu();

    } catch (e) {
      _showMessage("Upload failed");
    }

    setState(() => uploadingItemId = null);
  }

  Future<void> editMenuItem(Map item) async {
    final nameCtrl = TextEditingController(text: item["name"]);
    final priceCtrl =
        TextEditingController(text: item["price"].toString());
    final descCtrl =
        TextEditingController(text: item["description"] ?? "");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Menu Item"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Item name"),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: "Description"),
              ),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: "Price"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiService.put(
                "/vendors/menu/${item["_id"]}",
                {
                  "name": nameCtrl.text,
                  "description": descCtrl.text,
                  "price": double.parse(priceCtrl.text),
                },
              );

              Navigator.pop(context);
              loadMenu();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> deleteMenuItem(String id) async {
    final confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Item"),
        content: const Text("Are you sure you want to delete this item?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await ApiService.delete("/vendors/menu/$id");

    loadMenu();
  }

  void showAddItemDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Menu Item"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Item name"),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: "Description"),
              ),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: "Price"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            onPressed: () async {
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
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Menu"),
        backgroundColor: Colors.blue,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: showAddItemDialog,
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : menuItems.isEmpty
              ? const Center(child: Text("No menu items yet"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: menuItems.length,
                  itemBuilder: (_, i) {
                    final item = menuItems[i];
                    final image = item["image"];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: uploadingItemId == item["_id"]
                            ? const SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : image != null && image["url"] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      image["url"],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(Icons.fastfood),
                        title: Text(item["name"]),
                        subtitle: Text(item["description"] ?? ""),
                        trailing: Text(
                          "₦${item["price"]}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () => uploadMenuImage(item["_id"]),
                        onLongPress: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (_) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.edit),
                                  title: const Text("Edit"),
                                  onTap: () {
                                    Navigator.pop(context);
                                    editMenuItem(item);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.delete, color: Colors.red),
                                  title: const Text("Delete"),
                                  onTap: () {
                                    Navigator.pop(context);
                                    deleteMenuItem(item["_id"]);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}