import 'package:flutter/material.dart';
import '../../services/vendor_service.dart';

class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  Map<String, dynamic>? vendor;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final res = await VendorService.getMe();
    setState(() {
      vendor = res;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vendor Profile"),
        backgroundColor: Colors.blue,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : vendor == null
              ? const Center(child: Text("Failed to load profile"))
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                     _item("Business Name", vendor?["name"] ?? "—"),
                     _item("Phone", vendor?["phone"] ?? "—"),
                     _item("Email", vendor?["email"] ?? "—"),
                     _item(
                      "Status",
                      vendor?["isOpen"] == true ? "Open" : "Closed",
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _item(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
