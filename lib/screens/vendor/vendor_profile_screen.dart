import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/theme/app_theme.dart';
import '../../widgets/dark_mode_toggle.dart';
import '../../services/vendor_service.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../utils/session.dart';
import 'vendor_bank_screen.dart';
import 'vendor_promos_screen.dart';
import '../rider/vehicle_info_screen.dart';

const _kTeal   = Color(0xFF00B4B4);
const _kTealDk = Color(0xFF00D4D4);
const _kAmber  = Color(0xFFFFC542);
const _kBlue   = Color(0xFF4A90E2);
const _kOpen   = Color(0xFF00C48C);

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
  double _deliveryRadius = 10.0;
  bool _savingRadius = false;

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
          vendor            = res;
          logoUrl           = res?["logo"]?["url"];
          vendorRating      = (res?["rating"] ?? 0).toDouble();
          vendorRatingCount = (res?["ratingCount"] ?? 0) as int;
          _deliveryRadius   = (res?["maxDeliveryRadius"] ?? 10).toDouble();
          vendorName        = name ?? user?["name"] ?? "Vendor";
          vendorEmail       = user?["email"] ?? "";
          activeRole        = user?["role"] ?? "vendor";
          userRoles         = List<String>.from(user?["roles"] ?? ["vendor"]);
          loading           = false;
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

  Future<void> _saveRadius(double radius) async {
    setState(() => _savingRadius = true);
    try {
      await VendorService.updateProfile({"maxDeliveryRadius": radius});
      _showSuccess("Delivery radius updated");
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _savingRadius = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green));

  bool _dark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;
  Color _bg(BuildContext ctx)      => _dark(ctx) ? VendorColors.backgroundDark : VendorColors.background;
  Color _card(BuildContext ctx)    => _dark(ctx) ? VendorColors.surfaceDark    : VendorColors.surface;
  Color _cardAlt(BuildContext ctx) => _dark(ctx) ? VendorColors.surfaceAltDark : VendorColors.surfaceAlt;
  Color _text(BuildContext ctx)    => _dark(ctx) ? VendorColors.textDark       : VendorColors.text;
  Color _muted(BuildContext ctx)   => _dark(ctx) ? VendorColors.mutedDark      : VendorColors.muted;
  Color _teal(BuildContext ctx)    => _dark(ctx) ? _kTealDk : _kTeal;
  Color _border(BuildContext ctx)  => _dark(ctx)
      ? Colors.teal.withOpacity(0.15)
      : Colors.teal.withOpacity(0.12);

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg(context),
        body: loading
            ? Center(child: CircularProgressIndicator(color: _teal(context)))
            : CustomScrollView(
                slivers: [
                  _buildHeader(context),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Appearance ──────────────────────────────
                          _sectionLabel("APPEARANCE", context),
                          const SizedBox(height: 12),
                          const DarkModeToggle(),
                          const SizedBox(height: 28),

                          // ── Store info ──────────────────────────────
                          _sectionLabel("STORE INFO", context),
                          const SizedBox(height: 12),
                          _infoBand(context),
                          const SizedBox(height: 20),

                          // ── Delivery Range ───────────────────────────
                          _sectionLabel("DELIVERY RANGE", context),
                          const SizedBox(height: 12),
                          _deliveryRadiusCard(context),
                          const SizedBox(height: 28),

                          // ── Account ──────────────────────────────────
                          _sectionLabel("ACCOUNT", context),
                          const SizedBox(height: 12),
                          _menuTile(
                            context: context,
                            icon: Icons.account_balance_rounded,
                            title: "Bank Details",
                            subtitle: "Withdrawal account",
                            accent: _kBlue,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => const VendorBankScreen())),
                          ),
                          const SizedBox(height: 10),
                          _menuTile(
                            context: context,
                            icon: Icons.discount_rounded,
                            title: "Promo Codes",
                            subtitle: "Create & manage discount codes",
                            accent: _teal(context),
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => const VendorPromosScreen())),
                          ),
                          const SizedBox(height: 28),

                          // ── Switch Role ───────────────────────────────
                          _sectionLabel("SWITCH ROLE", context),
                          const SizedBox(height: 12),
                          ..._buildRoleTiles(context),
                          const SizedBox(height: 28),

                          // ── Danger Zone ───────────────────────────────
                          _sectionLabel("DANGER ZONE", context),
                          const SizedBox(height: 12),
                          _menuTile(
                            context: context,
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

  Widget _buildHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: _text(context), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            GestureDetector(
              onTap: isUploading ? null : _pickAndUploadLogo,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _teal(context), width: 2.5),
                    ),
                    child: ClipOval(
                      child: logoUrl != null
                          ? Image.network(logoUrl!, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _logoPlaceholder(context))
                          : _logoPlaceholder(context),
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
                        color: _teal(context),
                        shape: BoxShape.circle,
                        border: Border.all(color: _bg(context), width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 13),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            Text(vendorName,
                style: TextStyle(
                    color: _text(context),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4)),
            const SizedBox(height: 4),
            Text(vendorEmail,
                style: TextStyle(color: _muted(context), fontSize: 13)),
            const SizedBox(height: 12),

            if (vendorRating > 0)
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
                    Text(vendorRating.toStringAsFixed(1),
                        style: const TextStyle(
                            color: _kAmber, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 5),
                    Text(
                      "· $vendorRatingCount ${vendorRatingCount == 1 ? 'rating' : 'ratings'}",
                      style: TextStyle(color: _muted(context), fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _cardAlt(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.teal.withOpacity(0.15)),
                ),
                child: Text("No ratings yet",
                    style: TextStyle(color: _muted(context), fontSize: 12)),
              ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

 Widget _deliveryRadiusCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.location_on_rounded,
                    color: _teal(context), size: 18),
                const SizedBox(width: 8),
                Text("Maximum delivery distance",
                    style: TextStyle(
                        color: _text(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ]),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _teal(context).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${_deliveryRadius.round()} km",
                  style: TextStyle(
                      color: _teal(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Customers beyond this range won't see your kitchen",
            style: TextStyle(color: _muted(context), fontSize: 11),
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _teal(context),
              inactiveTrackColor: _teal(context).withOpacity(0.15),
              thumbColor: _teal(context),
              overlayColor: _teal(context).withOpacity(0.12),
              trackHeight: 4,
            ),
            child: Slider(
              value: _deliveryRadius,
              min: 1,
              max: 50,
              divisions: 49,
              onChanged: (val) => setState(() => _deliveryRadius = val),
              onChangeEnd: (val) => _saveRadius(val),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("1 km",
                  style: TextStyle(color: _muted(context), fontSize: 11)),
              Text("50 km",
                  style: TextStyle(color: _muted(context), fontSize: 11)),
            ],
          ),
          if (_savingRadius) ...[
            const SizedBox(height: 10),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _teal(context)),
                  ),
                  const SizedBox(width: 8),
                  Text("Saving...",
                      style:
                          TextStyle(color: _muted(context), fontSize: 11)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoBand(BuildContext context) {
    final isOpen = vendor?["isOpen"] == true;
    final fields = [
      ["Business Name", vendor?["name"] ?? "—"],
      ["Phone",         vendor?["phone"] ?? "—"],
      ["Status",        isOpen ? "Open" : "Closed"],
    ];
    return Container(
      decoration: BoxDecoration(
        color: _card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border(context)),
      ),
      child: Column(
        children: fields.asMap().entries.map((e) {
          final isLast = e.key == fields.length - 1;
          final label  = e.value[0];
          final value  = e.value[1];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: TextStyle(color: _muted(context), fontSize: 13)),
                    Text(value,
                        style: TextStyle(
                          color: label == "Status"
                              ? (isOpen ? _kOpen : Colors.redAccent)
                              : _text(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
              if (!isLast)
                Divider(height: 1, indent: 16, endIndent: 16,
                    color: _border(context)),
            ],
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildRoleTiles(BuildContext context) {
    final allRoles = ["customer", "rider", "vendor"];
    final roleIcons = {
      "customer": Icons.person_rounded,
      "rider":    Icons.delivery_dining_rounded,
      "vendor":   Icons.storefront_rounded,
    };
    final roleColors = {
      "customer": _kBlue,
      "rider":    _kOpen,
      "vendor":   _teal(context),
    };

    final tiles = <Widget>[];
    for (int i = 0; i < allRoles.length; i++) {
      final role     = allRoles[i];
      final isActive = role == activeRole;
      final hasRole  = userRoles.contains(role);
      final accent   = roleColors[role]!;

      tiles.add(
        GestureDetector(
          onTap: (isActive || switching) ? null : () => _switchRole(role),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isActive ? 1.0 : 0.75,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isActive ? accent.withOpacity(0.10) : _card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? accent.withOpacity(0.4) : _border(context),
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
                            color: isActive ? accent : _text(context),
                            fontSize: 14, fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isActive ? "Current role"
                              : hasRole ? "Tap to switch"
                              : "Tap to add this role",
                          style: TextStyle(color: _muted(context), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text("Active",
                          style: TextStyle(
                              color: accent, fontSize: 11, fontWeight: FontWeight.w600)),
                    )
                  else if (switching)
                    SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _muted(context)),
                    )
                  else
                    Icon(
                      hasRole
                          ? Icons.swap_horiz_rounded
                          : Icons.add_circle_outline_rounded,
                      color: _muted(context), size: 18,
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

  Widget _logoPlaceholder(BuildContext context) => Container(
        color: _cardAlt(context),
        child: Icon(Icons.storefront_rounded, color: _teal(context), size: 36),
      );

  Widget _sectionLabel(String text, BuildContext context) => Text(text,
      style: TextStyle(
          color: _muted(context), fontSize: 11,
          fontWeight: FontWeight.w600, letterSpacing: 1.4));

  Widget _menuTile({
    required BuildContext context,
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
          color: _card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border(context)),
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
                      style: TextStyle(
                          color: _text(context), fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(color: _muted(context), fontSize: 12)),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: accent == Colors.redAccent
                  ? Colors.redAccent.withOpacity(0.5)
                  : _muted(context),
            ),
          ],
        ),
      ),
    );
  }
}