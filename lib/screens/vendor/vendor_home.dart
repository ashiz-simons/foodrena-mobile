import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/session.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/vendor_service.dart';

import 'vendor_orders_screen.dart';
import 'vendor_menu_screen.dart';
import 'vendor_profile_screen.dart';
import 'vendor_wallet_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────
const _kBg      = Color(0xFFF0FAFA);
const _kCard    = Color(0xFFFFFFFF);
const _kCardAlt = Color(0xFFE0F7F7);
const _kTeal    = Color(0xFF00B4B4);
const _kAmber   = Color(0xFFFFC542);
const _kBlue    = Color(0xFF4A90E2);
const _kRed     = Color(0xFFFF5B5B);
const _kText    = Color(0xFF1A1A1A);
const _kMuted   = Color(0xFF6B8A8A);
const _kOpen    = Color(0xFF00C48C);

class VendorHome extends StatefulWidget {
  final VoidCallback? onLogout;
  final VoidCallback? onRoleSwitch;

  const VendorHome({super.key, this.onLogout, this.onRoleSwitch});

  @override
  State<VendorHome> createState() => _VendorHomeState();
}

class _VendorHomeState extends State<VendorHome> {
  bool open = false;
  bool loading = true;
  bool _toggling = false;

  int ordersToday = 0;
  int activeOrders = 0;
  double rating = 0.0;
  int ratingCount = 0;
  String? logoUrl;

  String? vendorId;
  String vendorName = "Vendor";

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    vendorName = await Session.getUserName() ?? "Vendor";
    await loadStats();
  }

  Future<void> loadStats() async {
    try {
      final res = await ApiService.get("/vendors/dashboard");
      if (res != null && mounted) {
        setState(() {
          ordersToday  = res["ordersToday"] ?? 0;
          activeOrders = res["activeOrders"] ?? 0;
          open         = res["isOpen"] ?? false;
          vendorId     = res["vendorId"]?.toString() ?? res["_id"]?.toString();
          rating       = (res["rating"] ?? 0).toDouble();
          ratingCount  = (res["ratingCount"] ?? 0) as int;
          logoUrl      = res["logo"]?["url"];
        });
        if (vendorId != null) {
          await SocketService.connectToRoom("vendor_$vendorId");
          _listenForOrders();
        }
      }
    } catch (e) {
      debugPrint("Vendor dashboard load failed: $e");
    }
    if (mounted) setState(() => loading = false);
  }

  void _listenForOrders() {
    SocketService.on("new_order", (data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.notifications_active, color: Colors.white),
            SizedBox(width: 10),
            Text("New order received!"),
          ]),
          backgroundColor: _kTeal,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: "View",
            textColor: Colors.white,
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => VendorOrdersScreen())),
          ),
        ),
      );
      loadStats();
    });
  }

  Future<void> toggleOpen(bool value) async {
    if (_toggling) return;
    HapticFeedback.mediumImpact();
    setState(() { _toggling = true; open = value; });
    await VendorService.toggleAvailability(value);
    setState(() => _toggling = false);
  }

  Future<void> logout() async {
    SocketService.disconnect();
    await Session.clearAll();
    widget.onLogout?.call();
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VendorProfileScreen(
          onLogout: logout,
          onRoleSwitch: widget.onRoleSwitch,
        ),
      ),
    ).then((_) => loadStats());
  }

  @override
  void dispose() {
    SocketService.off("new_order");
    super.dispose();
  }

  String get _firstName => vendorName.split(' ').first;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return "Good morning";
    if (h < 17) return "Good afternoon";
    return "Good evening";
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kTeal)),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _kBg,
        body: RefreshIndicator(
          color: _kTeal,
          backgroundColor: _kCard,
          onRefresh: loadStats,
          child: CustomScrollView(
            slivers: [
              _buildHeader(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  child: Column(
                    children: [
                      _storeToggleCard(),
                      const SizedBox(height: 20),
                      _statsRow(),
                      const SizedBox(height: 28),
                      _sectionLabel("QUICK ACTIONS"),
                      const SizedBox(height: 14),
                      _actionCard(
                        icon: Icons.receipt_long_rounded,
                        title: "View Orders",
                        subtitle: "$activeOrders active right now",
                        accent: _kTeal,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => VendorOrdersScreen())),
                      ),
                      const SizedBox(height: 12),
                      _actionCard(
                        icon: Icons.restaurant_menu_rounded,
                        title: "Manage Menu",
                        subtitle: "Add, edit or remove dishes",
                        accent: _kBlue,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const VendorMenuScreen())),
                      ),
                      const SizedBox(height: 12),
                      _actionCard(
                        icon: Icons.account_balance_wallet_rounded,
                        title: "Wallet & Earnings",
                        subtitle: "Check your balance",
                        accent: _kAmber,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const VendorWalletScreen())),
                      ),
                      const SizedBox(height: 12),
                      _actionCard(
                        icon: Icons.person_rounded,
                        title: "My Profile",
                        subtitle: "Logo, bank details & role switch",
                        accent: _kMuted,
                        onTap: _openProfile,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo avatar → profile
              GestureDetector(
                onTap: _openProfile,
                child: Stack(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: open ? _kOpen : _kMuted.withOpacity(0.4),
                          width: 2.5,
                        ),
                      ),
                      child: ClipOval(
                        child: logoUrl != null
                            ? Image.network(logoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _avatarPlaceholder())
                            : _avatarPlaceholder(),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: open ? _kOpen : _kMuted.withOpacity(0.5),
                          border: Border.all(color: _kBg, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Greeting + name + rating
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting,
                        style: const TextStyle(
                            color: _kMuted, fontSize: 12, letterSpacing: 0.3)),
                    const SizedBox(height: 2),
                    Text(_firstName,
                        style: const TextStyle(
                            color: _kText,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4)),
                    const SizedBox(height: 4),
                    if (rating > 0)
                      Row(children: [
                        const Icon(Icons.star_rounded, color: _kAmber, size: 13),
                        const SizedBox(width: 3),
                        Text(rating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: _kAmber,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Text(
                          "($ratingCount ${ratingCount == 1 ? 'rating' : 'ratings'})",
                          style: const TextStyle(color: _kMuted, fontSize: 11),
                        ),
                      ])
                    else
                      const Text("No ratings yet",
                          style: TextStyle(color: _kMuted, fontSize: 11)),
                  ],
                ),
              ),

              // Notifications
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_outlined,
                    color: _kText, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() => Container(
        color: _kCardAlt,
        child: const Icon(Icons.storefront_rounded, color: _kTeal, size: 28),
      );

  // ── STORE TOGGLE ──────────────────────────────────────────────────────────
  Widget _storeToggleCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: open
              ? [const Color(0xFFD4F5ED), const Color(0xFFBBEEE3)]
              : [_kCard, _kCardAlt],
        ),
        border: Border.all(
          color: open
              ? _kOpen.withOpacity(0.4)
              : Colors.teal.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: open
                ? _kOpen.withOpacity(0.15)
                : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: open ? _kOpen : _kMuted.withOpacity(0.4),
              boxShadow: open
                  ? [BoxShadow(
                      color: _kOpen.withOpacity(0.5), blurRadius: 8)]
                  : [],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  open ? "Store is Open" : "Store is Closed",
                  style: TextStyle(
                    color: open ? _kOpen : _kText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  open
                      ? "Accepting orders from customers"
                      : "Toggle to start accepting orders",
                  style: const TextStyle(color: _kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          _toggling
              ? const SizedBox(
                  width: 36,
                  height: 20,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kTeal),
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: () => toggleOpen(!open),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 52,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: open ? _kOpen : _kMuted.withOpacity(0.3),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: open
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ── STATS ─────────────────────────────────────────────────────────────────
  Widget _statsRow() {
    return Row(
      children: [
        Expanded(child: _statCard(
          label: "Orders Today",
          value: ordersToday.toString(),
          icon: Icons.receipt_long_rounded,
          accent: _kTeal,
        )),
        const SizedBox(width: 14),
        Expanded(child: _statCard(
          label: "Active Orders",
          value: activeOrders.toString(),
          icon: Icons.local_fire_department_rounded,
          accent: _kAmber,
        )),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.teal.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(height: 14),
          Text(value,
              style: const TextStyle(
                  color: _kText,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: _kMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text,
          style: const TextStyle(
              color: _kMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4)),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.teal.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: _kText,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(color: _kMuted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _kMuted),
          ],
        ),
      ),
    );
  }
}