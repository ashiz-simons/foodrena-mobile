import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/session.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/vendor_service.dart';
import '../../services/notification_store.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/notification_bell.dart';

import 'vendor_orders_screen.dart';
import 'vendor_menu_screen.dart';
import 'vendor_profile_screen.dart';
import 'vendor_wallet_screen.dart';
import 'preferred_riders_screen.dart';
import '../shared/identity_verification_screen.dart';

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
  String _verificationStatus = "unverified";

  int ordersToday = 0;
  int activeOrders = 0;
  double rating = 0.0;
  int ratingCount = 0;
  String? logoUrl;

  String? vendorId;
  String vendorName = "Vendor";

  static const _kTeal   = Color(0xFF00B4B4);
  static const _kTealDk = Color(0xFF00D4D4);
  static const _kAmber  = Color(0xFFFFC542);
  static const _kBlue   = Color(0xFF4A90E2);
  static const _kOpen   = Color(0xFF00C48C);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    vendorName = await Session.getUserName() ?? "Vendor";
    await Future.wait([loadStats(), _loadVerificationStatus()]);
  }

  Future<void> _loadVerificationStatus() async {
    try {
      final res = await ApiService.get("/verification/identity/status");
      if (mounted) {
        setState(() => _verificationStatus = res["status"] ?? "unverified");
      }
    } catch (_) {}
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
      final teal = _teal(context);

      NotificationStore.instance.add(AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: "New Order!",
        body: "You have a new order waiting.",
        type: "new_order",
        receivedAt: DateTime.now(),
      ));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.notifications_active, color: Colors.white),
            SizedBox(width: 10),
            Text("New order received!"),
          ]),
          backgroundColor: teal,
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

  bool _dark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;

  Color _bg(BuildContext ctx) => _dark(ctx)
      ? VendorColors.backgroundDark
      : VendorColors.background;

  Color _card(BuildContext ctx) => _dark(ctx)
      ? VendorColors.surfaceDark
      : VendorColors.surface;

  Color _cardAlt(BuildContext ctx) => _dark(ctx)
      ? VendorColors.surfaceAltDark
      : VendorColors.surfaceAlt;

  Color _text(BuildContext ctx) => _dark(ctx)
      ? VendorColors.textDark
      : VendorColors.text;

  Color _muted(BuildContext ctx) => _dark(ctx)
      ? VendorColors.mutedDark
      : VendorColors.muted;

  Color _teal(BuildContext ctx) => _dark(ctx) ? _kTealDk : _kTeal;

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);

    if (loading) {
      return Scaffold(
        backgroundColor: _bg(context),
        body: Center(child: CircularProgressIndicator(color: _teal(context))),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg(context),
        body: RefreshIndicator(
          color: _teal(context),
          backgroundColor: _card(context),
          onRefresh: loadStats,
          child: CustomScrollView(
            slivers: [
              _buildHeader(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  child: Column(
                    children: [
                      if (_verificationStatus != "verified")
                        _verificationBanner(context),
                      if (_verificationStatus != "verified")
                        const SizedBox(height: 16),
                      _storeToggleCard(context),
                      const SizedBox(height: 20),
                      _statsRow(context),
                      const SizedBox(height: 28),
                      _sectionLabel("QUICK ACTIONS", context),
                      const SizedBox(height: 14),
                      _actionCard(
                        context: context,
                        icon: Icons.receipt_long_rounded,
                        title: "View Orders",
                        subtitle: "$activeOrders active right now",
                        accent: _teal(context),
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => VendorOrdersScreen())),
                      ),
                      const SizedBox(height: 12),
                      _actionCard(
                        context: context,
                        icon: Icons.restaurant_menu_rounded,
                        title: "Manage Menu",
                        subtitle: "Add, edit or remove dishes",
                        accent: _kBlue,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const VendorMenuScreen())),
                      ),
                      const SizedBox(height: 12),
                      _actionCard(
                        context: context,
                        icon: Icons.account_balance_wallet_rounded,
                        title: "Wallet & Earnings",
                        subtitle: "Check your balance",
                        accent: _kAmber,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const VendorWalletScreen())),
                      ),
                      const SizedBox(height: 12),
                      _actionCard(
                        context: context,
                        icon: Icons.people_rounded,
                        title: "Preferred Riders",
                        subtitle: "Manage your trusted riders",
                        accent: const Color(0xFF7C5CBF),
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const PreferredRidersScreen())),
                      ),
                      const SizedBox(height: 12),
                      _actionCard(
                        context: context,
                        icon: Icons.person_rounded,
                        title: "My Profile",
                        subtitle: "Logo, bank details & role switch",
                        accent: _muted(context),
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

  // ── Verification Banner ──────────────────────────────────────────────────
  Widget _verificationBanner(BuildContext context) {
    final isPending = _verificationStatus == "pending";
    final isFailed  = _verificationStatus == "failed";
    final color     = isFailed ? Colors.redAccent : _kAmber;

    return GestureDetector(
      onTap: isPending ? null : () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IdentityVerificationScreen(
            accentColor: _teal(context),
            onVerified: () {
              setState(() => _verificationStatus = "verified");
              Navigator.pop(context);
            },
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              isPending
                  ? Icons.hourglass_top_rounded
                  : isFailed
                      ? Icons.error_outline_rounded
                      : Icons.verified_user_outlined,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPending
                        ? "Verification Pending"
                        : isFailed
                            ? "Verification Failed"
                            : "Identity Not Verified",
                    style: TextStyle(
                        color: _text(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPending
                        ? "Your identity is being reviewed"
                        : isFailed
                            ? "Tap to retry verification"
                            : "Verify your NIN or Driver's License",
                    style: TextStyle(color: _muted(context), fontSize: 11),
                  ),
                ],
              ),
            ),
            if (!isPending)
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: _muted(context)),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _openProfile,
                child: Stack(
                  children: [
                    Container(
                      width: 58, height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: open ? _kOpen : _muted(context).withOpacity(0.4),
                          width: 2.5,
                        ),
                      ),
                      child: ClipOval(
                        child: logoUrl != null
                            ? Image.network(logoUrl!, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _avatarPlaceholder(context))
                            : _avatarPlaceholder(context),
                      ),
                    ),
                    Positioned(
                      bottom: 2, right: 2,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: open ? _kOpen : _muted(context).withOpacity(0.5),
                          border: Border.all(color: _bg(context), width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting,
                        style: TextStyle(
                            color: _muted(context), fontSize: 12, letterSpacing: 0.3)),
                    const SizedBox(height: 2),
                    Text(_firstName,
                        style: TextStyle(
                            color: _text(context), fontSize: 22,
                            fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                    const SizedBox(height: 4),
                    if (rating > 0)
                      Row(children: [
                        const Icon(Icons.star_rounded, color: _kAmber, size: 13),
                        const SizedBox(width: 3),
                        Text(rating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: _kAmber, fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Text(
                          "($ratingCount ${ratingCount == 1 ? 'rating' : 'ratings'})",
                          style: TextStyle(color: _muted(context), fontSize: 11),
                        ),
                      ])
                    else
                      Text("No ratings yet",
                          style: TextStyle(color: _muted(context), fontSize: 11)),
                  ],
                ),
              ),
              NotificationBell(
                color: _text(context),
                badgeColor: _teal(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder(BuildContext context) => Container(
        color: _cardAlt(context),
        child: Icon(Icons.storefront_rounded, color: _teal(context), size: 28),
      );

  // ── Store Toggle Card ─────────────────────────────────────────────────────
  Widget _storeToggleCard(BuildContext context) {
    final dark = _dark(context);
    final teal = _teal(context);
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
              ? (dark
                  ? [const Color(0xFF0D3028), const Color(0xFF0A2820)]
                  : [const Color(0xFFD4F5ED), const Color(0xFFBBEEE3)])
              : [_card(context), _cardAlt(context)],
        ),
        border: Border.all(
          color: open
              ? _kOpen.withOpacity(0.4)
              : (dark
                  ? Colors.teal.withOpacity(0.15)
                  : Colors.teal.withOpacity(0.12)),
        ),
        boxShadow: [
          BoxShadow(
            color: open
                ? _kOpen.withOpacity(0.15)
                : Colors.black.withOpacity(dark ? 0.3 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: open ? _kOpen : _muted(context).withOpacity(0.4),
              boxShadow: open
                  ? [BoxShadow(color: _kOpen.withOpacity(0.5), blurRadius: 8)]
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
                    color: open ? _kOpen : _text(context),
                    fontSize: 17, fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  open
                      ? "Accepting orders from customers"
                      : "Toggle to start accepting orders",
                  style: TextStyle(color: _muted(context), fontSize: 12),
                ),
              ],
            ),
          ),
          _toggling
              ? SizedBox(
                  width: 36, height: 20,
                  child: Center(
                    child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: teal),
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: () => toggleOpen(!open),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 52, height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: open ? _kOpen : _muted(context).withOpacity(0.3),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment:
                          open ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        width: 22, height: 22,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Colors.white),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────
  Widget _statsRow(BuildContext context) {
    final teal = _teal(context);
    return Row(
      children: [
        Expanded(child: _statCard(
          context: context,
          label: "Orders Today",
          value: ordersToday.toString(),
          icon: Icons.receipt_long_rounded,
          accent: teal,
        )),
        const SizedBox(width: 14),
        Expanded(child: _statCard(
          context: context,
          label: "Active Orders",
          value: activeOrders.toString(),
          icon: Icons.local_fire_department_rounded,
          accent: _kAmber,
        )),
      ],
    );
  }

  Widget _statCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    final dark = _dark(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: dark
                ? Colors.teal.withOpacity(0.15)
                : Colors.teal.withOpacity(0.1)),
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
              style: TextStyle(
                  color: _text(context), fontSize: 22,
                  fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(color: _muted(context), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text,
          style: TextStyle(
              color: _muted(context), fontSize: 11,
              fontWeight: FontWeight.w600, letterSpacing: 1.4)),
    );
  }

  // ── Action Card ───────────────────────────────────────────────────────────
  Widget _actionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final dark = _dark(context);
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _card(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: dark
                  ? Colors.teal.withOpacity(0.15)
                  : Colors.teal.withOpacity(0.1)),
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
                      style: TextStyle(
                          color: _text(context), fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(color: _muted(context), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: _muted(context)),
          ],
        ),
      ),
    );
  }
}