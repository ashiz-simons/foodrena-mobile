import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class VendorMenuScreen extends StatefulWidget {
  const VendorMenuScreen({super.key});

  @override
  State<VendorMenuScreen> createState() => _VendorMenuScreenState();
}

class _VendorMenuScreenState extends State<VendorMenuScreen> {
  bool loading = true;
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
        menuItems = res["menuItems"] ?? [];
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  void showAddItemDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Menu Item"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
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

              await ApiService.post('/vendors/menu', {
                "name": nameCtrl.text,
                "description": descCtrl.text,
                "price": double.parse(priceCtrl.text),
              });

              Navigator.pop(context);
              loadMenu();
            },
            child: const Text("Add"),
          ),
        ],
      ),
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

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(item["name"]),
                        subtitle: Text(item["description"] ?? ""),
                        trailing: Text(
                          "₦${item["price"]}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
