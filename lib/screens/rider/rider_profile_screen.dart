import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/session.dart';
import '../../services/api_service.dart';
import 'rider_bank_screen.dart';
import 'dart:io';
import '../../services/socket_service.dart';

class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key});

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  String? imageUrl;
  String riderName = "Rider";
  bool isUploading = false;
  bool loading = true;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ApiService.get("/riders/dashboard");
      if (mounted) {
        setState(() {
          imageUrl = res?["profileImage"]?["url"];
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }

    // Load name from session
    final name = await Session.getUserName();
    if (mounted) setState(() => riderName = name ?? "Rider");
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;

    setState(() => isUploading = true);

    try {
      // 1. Upload to Cloudinary via /api/upload
      final uploadResult = await ApiService.uploadFile(
        "/upload",
        File(file.path),
        {"folder": "riders"},
      );

      if (uploadResult == null || uploadResult["url"] == null) {
        _showError("Upload failed — no URL returned");
        return;
      }

      final url = uploadResult["url"] as String;
      final publicId = uploadResult["publicId"] as String;

      // 2. Save URL to rider profile
      await ApiService.patch("/riders/profile-image", {
        "imageUrl": url,
        "publicId": publicId,
      });

      if (mounted) {
        setState(() => imageUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile picture updated!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    }

    if (mounted) setState(() => isUploading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: isUploading ? null : _pickAndUploadImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: imageUrl != null
                              ? NetworkImage(imageUrl!)
                              : null,
                          child: imageUrl == null
                              ? const Icon(Icons.person, size: 45)
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
                              color: Colors.orange,
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
                  const SizedBox(height: 12),
                  Text(
                    riderName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text("Rider",
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 30),
                  ListTile(
                    leading: const Icon(Icons.account_balance),
                    title: const Text("Bank Details"),
                    trailing:
                        const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RiderBankScreen()),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text("Logout",
                        style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      await Session.clearAll();
                      SocketService.disconnect();
                      if (!mounted) return;
                      Navigator.pushNamedAndRemoveUntil(
                          context, "/login", (_) => false);
                    },
                  ),
                ],
              ),
            ),
    );
  }
}