import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/session.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import 'rider_bank_screen.dart';
import '../rider/vehicle_info_screen.dart';
import 'dart:io';

const _kDark    = Color(0xFFFFF8F2);
const _kCard    = Color(0xFFFFFFFF);
const _kCardAlt = Color(0xFFFFF0E6);
const _kOnline  = Color(0xFF00D97E);
const _kAmber   = Color(0xFFFFC542);
const _kText    = Color(0xFF1A1A1A);
const _kMuted   = Color(0xFF888888);
const _kBlue    = Color(0xFF4A90E2);
const _kPurple  = Color(0xFFB06EFF);

class RiderProfileScreen extends StatefulWidget {
  final VoidCallback? onRoleSwitch;
  final VoidCallback? onLogout;

  const RiderProfileScreen({
    super.key,
    this.onRoleSwitch,
    this.onLogout,
  });

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  String? imageUrl;
  String riderName = "Rider";
  String riderEmail = "";
  String activeRole = "rider";
  List<String> userRoles = ["rider"];
  double riderRating = 0.0;
  int riderRatingCount = 0;

  bool isUploading = false;
  bool loading = true;
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
        ApiService.get("/riders/dashboard"),
        Session.getUser(),
        Session.getUserName(),
      ]);

      final res = results[0] as Map?;
      final user = results[1] as Map?;
      final name = results[2] as String?;

      if (mounted) {
        setState(() {
          final rider = res?["rider"];
          imageUrl = rider?["profileImage"]?["url"];
          riderRating = (rider?["rating"] ?? 0).toDouble();
          riderRatingCount = (rider?["ratingCount"] ?? 0) as int;
          riderName = name ?? user?["name"] ?? "Rider";
          riderEmail = user?["email"] ?? "";
          activeRole = user?["role"] ?? "rider";
          userRoles = List<String>.from(user?["roles"] ?? ["rider"]);
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() => isUploading = true);
    try {
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
      await ApiService.patch("/riders/profile-image", {
        "imageUrl": url,
        "publicId": publicId,
      });
      if (mounted) {
        setState(() => imageUrl = url);
        _showSuccess("Profile picture updated!");
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
      if (msg.contains("Vehicle info required") || msg.contains("requiresVehicleInfo")) {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VehicleInfoScreen(
              onCompleted: () async {
                final res = await ApiService.post("/auth/switch-role", {"role": "rider"});
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

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green));

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8F2),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: _kOnline))
            : CustomScrollView(
                slivers: [
                  _buildHeader(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel("ACCOUNT"),
                          const SizedBox(height: 12),
                          _menuTile(
                            icon: Icons.account_balance_rounded,
                            title: "Bank Details",
                            subtitle: "Withdrawal account",
                            accent: _kBlue,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const RiderBankScreen())),
                          ),
                          const SizedBox(height: 10),
                          _menuTile(
                            icon: Icons.two_wheeler_rounded,
                            title: "Vehicle Info",
                            subtitle: "Update your vehicle details",
                            accent: _kPurple,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => VehicleInfoScreen(
                                          onCompleted: () => Navigator.pop(context),
                                        ))),
                          ),
                          const SizedBox(height: 28),
                          _sectionLabel("SWITCH ROLE"),
                          const SizedBox(height: 12),
                          ..._buildRoleTiles(),
                          const SizedBox(height: 28),
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

  // ── HEADER ────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: SafeArea(
        child: Column(
          children: [
            // Back button row
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: const Color(0xFF1A1A1A), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            // Avatar
            GestureDetector(
              onTap: isUploading ? null : _pickAndUploadImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _kOnline, width: 2.5),
                    ),
                    child: ClipOval(
                      child: imageUrl != null
                          ? Image.network(imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _avatarPlaceholder())
                          : _avatarPlaceholder(),
                    ),
                  ),
                  if (isUploading)
                    Positioned.fill(
                      child: ClipOval(
                        child: Container(
                          color: Colors.black54,
                          child: const Center(
                            child: SizedBox(
                              width: 24, height: 24,
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
                        color: _kOnline,
                        shape: BoxShape.circle,
                        border: Border.all(color: _kDark, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 13),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Name
            Text(riderName,
                style: const TextStyle(
                    color: _kText,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4)),
            const SizedBox(height: 4),
            Text(riderEmail,
                style: const TextStyle(color: _kMuted, fontSize: 13)),

            const SizedBox(height: 12),

            // Rating pill
            if (riderRating > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                    Text(
                      riderRating.toStringAsFixed(1),
                      style: const TextStyle(
                          color: _kAmber,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "· $riderRatingCount ${riderRatingCount == 1 ? 'rating' : 'ratings'}",
                      style: const TextStyle(color: _kMuted, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
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

  // ── ROLE TILES ────────────────────────────────────────────────────────
  List<Widget> _buildRoleTiles() {
    final allRoles = ["customer", "rider", "vendor"];
    final roleIcons = {
      "customer": Icons.person_rounded,
      "rider": Icons.delivery_dining_rounded,
      "vendor": Icons.storefront_rounded,
    };
    final roleColors = {
      "customer": _kBlue,
      "rider": _kOnline,
      "vendor": _kAmber,
    };

    final tiles = <Widget>[];
    for (int i = 0; i < allRoles.length; i++) {
      final role = allRoles[i];
      final isActive = role == activeRole;
      final hasRole = userRoles.contains(role);
      final accent = roleColors[role]!;

      tiles.add(
        GestureDetector(
          onTap: (isActive || switching) ? null : () => _switchRole(role),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isActive ? 1.0 : 0.7,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isActive ? accent.withOpacity(0.12) : _kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive
                      ? accent.withOpacity(0.4)
                      : Colors.orange.withOpacity(0.12),
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
                          style: const TextStyle(
                              color: _kMuted, fontSize: 11),
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
                      width: 16, height: 16,
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

  Widget _avatarPlaceholder() => Container(
        color: const Color(0xFFFFF0E6),
        child: const Icon(Icons.person_outline, color: _kMuted, size: 36),
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: Text(text,
            style: const TextStyle(
                color: _kMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4)),
      );

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
          border: Border.all(color: Colors.orange.withOpacity(0.12)),
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
                      style: const TextStyle(
                          color: _kMuted, fontSize: 12)),
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