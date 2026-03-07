import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/vendor_service.dart';
import '../../services/api_service.dart';

class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  Map<String, dynamic>? vendor;
  bool loading = true;
  bool isUploading = false;
  String? logoUrl;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final res = await VendorService.getMe();
    if (mounted) {
      setState(() {
        vendor = res;
        logoUrl = res?["logo"]?["url"];
        loading = false;
      });
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;

    setState(() => isUploading = true);

    try {
      // 1. Upload to Cloudinary
      final uploadResult = await ApiService.uploadFile(
        "/upload",
        File(file.path),
        {"folder": "vendors"},
      );

      if (uploadResult == null || uploadResult["url"] == null) {
        _showError("Upload failed — no URL returned");
        return;
      }

      final url = uploadResult["url"] as String;
      final publicId = uploadResult["publicId"] as String;

      // 2. Save to vendor profile
      await ApiService.patch("/vendors/logo", {
        "imageUrl": url,
        "publicId": publicId,
      });

      if (mounted) {
        setState(() => logoUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Logo updated!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    }

    if (mounted) setState(() => isUploading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo upload
                      Center(
                        child: GestureDetector(
                          onTap: isUploading ? null : _pickAndUploadLogo,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.blue.shade50,
                                backgroundImage: logoUrl != null
                                    ? NetworkImage(logoUrl!)
                                    : null,
                                child: logoUrl == null
                                    ? const Icon(Icons.storefront,
                                        size: 45, color: Colors.blue)
                                    : null,
                              ),
                              if (isUploading)
                                const Positioned.fill(
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.black38,
                                    child: CircularProgressIndicator(
                                        color: Colors.white),
                                  ),
                                ),
                              if (!isUploading)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 16),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text("Tap to update logo",
                            style: TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ),
                      const SizedBox(height: 28),

                      _item("Business Name", vendor?["name"] ?? "—"),
                      _item("Phone", vendor?["phone"] ?? "—"),
                      _item("Email", vendor?["email"] ?? "—"),
                      _item("Status",
                          vendor?["isOpen"] == true ? "Open" : "Closed"),
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