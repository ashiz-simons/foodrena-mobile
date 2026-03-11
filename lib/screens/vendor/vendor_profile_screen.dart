import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/vendor_service.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../utils/session.dart';
import 'vendor_bank_screen.dart';
import '../rider/vehicle_info_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────
const _kBg      = Color(0xFFF0FAFA);
const _kCard    = Color(0xFFFFFFFF);
const _kCardAlt = Color(0xFFE0F7F7);
const _kTeal    = Color(0xFF00B4B4);
const _kAmber   = Color(0xFFFFC542);
const _kBlue    = Color(0xFF4A90E2);
const _kPurple  = Color(0xFFB06EFF);
const _kText    = Color(0xFF1A1A1A);
const _kMuted   = Color(0xFF6B8A8A);
const _kOpen    = Color(0xFF00C48C);

class VendorProfileScreen extends StatefulWidget {
  final VoidCallback? onRoleSwitch;
  final VoidCallback? onLogout;

  const VendorProfileScreen({
    super.key,
    this.onRoleSwitch,
    this.onLogout,
  });

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  Map<String, dynamic>? vendor;
  String vendorName = "Vendor";
  String vendorEmail = "";
  String activeRole = "vendor";
  List<String> userRoles = ["vendor"];
  double vendorRating = 0.0;
  int vendorRatingCount = 0;
  String? logoUrl;

  bool loading = true;
  bool isUploading = false;
  bool switching = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final results = await Future.wait([
        VendorService.getMe(),
        Session.getUser(),
        Session.getUserName(),
      ]);

      final res  = results[0] as Map<String, dynamic>?;
      final user = results[1] as Map?;
      final name = results[2] as String?;

      if (mounted) {
        setState(() {
          vendor          = res;
          logoUrl         = res?["logo"]?["url"];
          vendorRating    = (res?["rating"] ?? 0).toDouble();
          vendorRatingCount = (res?["ratingCount"] ?? 0) as int;
          vendorName      = name ?? user?["name"] ?? "Vendor";
          vendorEmail     = user?["email"] ?? "";
          activeRole      = user?["role"] ?? "vendor";
          userRoles       = List<String>.from(user?["roles"] ?? ["vendor"]);
          loading         = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() => isUploading = true);
    try {
      final uploadResult = await ApiService.uploadFile(
          "/upload", File(file.path), {"folder": "vendors"});
      if (uploadResult == null || uploadResult["url"] == null) {
        _showError("Upload failed — no URL returned");
        return;
      }
      final url      = uploadResult["url"] as String;
      final publicId = uploadResult["publicId"] as String;
      await ApiService.patch("/vendors/logo", {
        "imageUrl": url,
        "publicId": publicId,
      });
      if (mounted) {
        setState(() => logoUrl = url);
        _showSuccess("Logo updated!");
      }
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    }
    if (mounted) setState(() => isUploading = false);
  }

  Future<void> _switchRole(String role) async {
    if (switching) return;
    setState(() => switching = true);
    try {
      final res = await ApiService.post("/auth/switch-role", {"role": role});
      await Session.saveToken(res["token"]);
      await Session.saveUser(res["user"]);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onRoleSwitch?.call();
    } catch (e) {
      final msg = e.toString().replaceAll("Exception: ", "");
      if (msg.contains("Vehicle info required") ||
          msg.contains("requiresVehicleInfo")) {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VehicleInfoScreen(
              onCompleted: () async {
                final res = await ApiService.post(
                    "/auth/switch-role", {"role": "rider"});
                await Session.saveToken(res["token"]);
                await Session.saveUser(res["user"]);
                widget.onRoleSwitch?.call();
              },
            ),
          ),
        );
      } else {
        if (mounted) _showError(msg);
      }
    }
    if (mounted) setState(() => switching = false);
  }

  Future<void> _logout() async {
    await Session.clearAll();
    SocketService.disconnect();
    if (!mounted) return;
    if (widget.onLogout != null) {
      Navigator.pop(context);
      widget.onLogout!();
    } else {
      Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green));

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _kBg,
        body: loading
            ? const Center(child: CircularProgressIndicator(color: _kTeal))
            : CustomScrollView(
                slivers: [
                  _buildHeader(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Store info ──────────────────────────────
                          _sectionLabel("STORE INFO"),
                          const SizedBox(height: 12),
                          _infoBand(),
                          const SizedBox(height: 28),

                          // ── Account ──────────────────────────────────
                          _sectionLabel("ACCOUNT"),
                          const SizedBox(height: 12),
                          _menuTile(
                            icon: Icons.account_balance_rounded,
                            title: "Bank Details",
                            subtitle: "Withdrawal account",
                            accent: _kBlue,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => const VendorBankScreen())),
                          ),
                          const SizedBox(height: 28),

                          // ── Switch role ───────────────────────────────
                          _sectionLabel("SWITCH ROLE"),
                          const SizedBox(height: 12),
                          ..._buildRoleTiles(),
                          const SizedBox(height: 28),

                          // ── Danger zone ───────────────────────────────
                          _sectionLabel("DANGER ZONE"),
                          const SizedBox(height: 12),
                          _menuTile(
                            icon: Icons.logout_rounded,
                            title: "Logout",
                            subtitle: "Sign out of your account",
                            accent: Colors.redAccent,
                            onTap: _logout,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: _kText, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            // Logo
            GestureDetector(
              onTap: isUploading ? null : _pickAndUploadLogo,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _kTeal, width: 2.5),
                    ),
                    child: ClipOval(
                      child: logoUrl != null
                          ? Image.network(logoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _logoPlaceholder())
                          : _logoPlaceholder(),
                    ),
                  ),
                  if (isUploading)
                    Positioned.fill(
                      child: ClipOval(
                        child: Container(
                          color: Colors.black54,
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: _kTeal,
                        shape: BoxShape.circle,
                        border: Border.all(color: _kBg, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 13),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            Text(vendorName,
                style: const TextStyle(
                    color: _kText,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4)),
            const SizedBox(height: 4),
            Text(vendorEmail,
                style: const TextStyle(color: _kMuted, fontSize: 13)),
            const SizedBox(height: 12),

            // Rating pill
            if (vendorRating > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _kAmber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kAmber.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: _kAmber, size: 16),
                    const SizedBox(width: 5),
                    Text(vendorRating.toStringAsFixed(1),
                        style: const TextStyle(
                            color: _kAmber,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 5),
                    Text(
                      "· $vendorRatingCount ${vendorRatingCount == 1 ? 'rating' : 'ratings'}",
                      style: const TextStyle(color: _kMuted, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _kCardAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.teal.withOpacity(0.15)),
                ),
                child: const Text("No ratings yet",
                    style: TextStyle(color: _kMuted, fontSize: 12)),
              ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // ── STORE INFO BAND ───────────────────────────────────────────────────────
  Widget _infoBand() {
    final isOpen = vendor?["isOpen"] == true;
    final fields = [
      ["Business Name", vendor?["name"] ?? "—"],
      ["Phone",         vendor?["phone"] ?? "—"],
      ["Status",        isOpen ? "Open" : "Closed"],
    ];
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withOpacity(0.12)),
      ),
      child: Column(
        children: fields.asMap().entries.map((e) {
          final isLast = e.key == fields.length - 1;
          final label = e.value[0];
          final value = e.value[1];
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label,
                        style:
                            const TextStyle(color: _kMuted, fontSize: 13)),
                    Text(
                      value,
                      style: TextStyle(
                        color: label == "Status"
                            ? (isOpen ? _kOpen : Colors.redAccent)
                            : _kText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Colors.teal.withOpacity(0.08)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── ROLE TILES ────────────────────────────────────────────────────────────
  List<Widget> _buildRoleTiles() {
    final allRoles   = ["customer", "rider", "vendor"];
    final roleIcons  = {
      "customer": Icons.person_rounded,
      "rider":    Icons.delivery_dining_rounded,
      "vendor":   Icons.storefront_rounded,
    };
    final roleColors = {
      "customer": _kBlue,
      "rider":    _kOpen,
      "vendor":   _kTeal,
    };

    final tiles = <Widget>[];
    for (int i = 0; i < allRoles.length; i++) {
      final role    = allRoles[i];
      final isActive = role == activeRole;
      final hasRole  = userRoles.contains(role);
      final accent   = roleColors[role]!;

      tiles.add(
        GestureDetector(
          onTap: (isActive || switching) ? null : () => _switchRole(role),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isActive ? 1.0 : 0.7,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isActive ? accent.withOpacity(0.10) : _kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive
                      ? accent.withOpacity(0.4)
                      : Colors.teal.withOpacity(0.12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(roleIcons[role], color: accent, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role[0].toUpperCase() + role.substring(1),
                          style: TextStyle(
                            color: isActive ? accent : _kText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isActive
                              ? "Current role"
                              : hasRole
                                  ? "Tap to switch"
                                  : "Tap to add this role",
                          style:
                              const TextStyle(color: _kMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text("Active",
                          style: TextStyle(
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    )
                  else if (switching)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kMuted),
                    )
                  else
                    Icon(
                      hasRole
                          ? Icons.swap_horiz_rounded
                          : Icons.add_circle_outline_rounded,
                      color: _kMuted,
                      size: 18,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      if (i < allRoles.length - 1) tiles.add(const SizedBox(height: 10));
    }
    return tiles;
  }

  Widget _logoPlaceholder() => Container(
        color: _kCardAlt,
        child: const Icon(Icons.storefront_rounded, color: _kTeal, size: 36),
      );

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          color: _kMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4));

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: Colors.teal.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: _kText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          const TextStyle(color: _kMuted, fontSize: 12)),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: accent == Colors.redAccent
                  ? Colors.redAccent.withOpacity(0.5)
                  : _kMuted,
            ),
          ],
        ),
      ),
    );
  }
}