import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../../utils/session.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/rider_service.dart';
import '../../services/notification_store.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/notification_bell.dart';

import 'rider_orders_screen.dart';
import 'rider_wallet_screen.dart';
import 'rider_profile_screen.dart';
import 'order_alert_screen.dart';
import '../../services/order_alert_service.dart';
import '../shared/identity_verification_screen.dart'; 

const _kOnline = Color(0xFF00D97E);
const _kAmber  = Color(0xFFFFC542);
const _kBlue   = Color(0xFF4A90E2);
const _kPurple = Color(0xFFB06EFF);

class RiderHome extends StatefulWidget {
  final VoidCallback? onLogout;
  final VoidCallback? onRoleSwitch;

  const RiderHome({super.key, this.onLogout, this.onRoleSwitch});

  @override
  State<RiderHome> createState() => _RiderHomeState();
}

class _RiderHomeState extends State<RiderHome>
    with SingleTickerProviderStateMixin {
  bool online = false;
  bool loading = true;
  bool _toggling = false;
  String _verificationStatus = "unverified";

  int ordersToday = 0;
  double earnings = 0.0;
  double riderRating = 0.0;
  int riderRatingCount = 0;
  String? profileImageUrl;

  String? riderId;
  String? userId;
  String riderName = "Rider";

  StreamSubscription<Position>? gpsStream;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    initialize();
  }

  Future<void> initialize() async {
    riderId = await Session.getRiderId();
    userId = await Session.getUserId();
    riderName = await Session.getUserName() ?? "Rider";
    await OrderAlertService.init();
    await Future.wait([loadDashboard(), _loadVerificationStatus()]);
    _listenForOrders();
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadVerificationStatus() async {
    try {
      final res = await ApiService.get("/verification/identity/status");
      if (mounted) {
        setState(() => _verificationStatus = res["status"] ?? "unverified");
      }
    } catch (_) {}
  }

  Future<void> loadDashboard() async {
    try {
      final res = await ApiService.get("/riders/dashboard");
      if (res != null && mounted) {
        final rider = res["rider"];
        setState(() {
          ordersToday = res["ordersToday"] ?? 0;
          earnings = (res["earnings"] ?? 0).toDouble();
          online = res["isAvailable"] ?? false;
          riderRating = (rider?["rating"] ?? 0).toDouble();
          riderRatingCount = (rider?["ratingCount"] ?? 0) as int;
          profileImageUrl = rider?["profileImage"]?["url"];
        });
        if (online && riderId != null) {
          await _connectSocket();
          startTracking();
        }
      }
    } catch (e) {
      debugPrint("❌ Dashboard load failed: $e");
    }
  }

  void _listenForOrders() {
    SocketService.on("new_order", (data) {
      if (!mounted) return;

      // Add to notification store
      NotificationStore.instance.add(AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: "New Order!",
        body: "You have a new delivery request.",
        type: "new_order",
        receivedAt: DateTime.now(),
      ));

      // Start alarm + vibration
      OrderAlertService.startAlert();

      // Show full screen alert overlay
      final orderData = data is Map<String, dynamic>
          ? data
          : <String, dynamic>{};

      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => OrderAlertScreen(
            orderData: orderData,
            onAccepted: () => loadDashboard(),
            onRejected: () => loadDashboard(),
          ),
        ),
      );
    });
  }

  Future<void> _connectSocket() async {
    await SocketService.connectToRoom("rider_$riderId");
    SocketService.emit("rider_online", {"riderId": riderId});
  }

  Future<void> toggleOnline(bool value) async {
    if (riderId == null || _toggling) return;
    HapticFeedback.mediumImpact();
    setState(() { _toggling = true; online = value; });
    await RiderService.toggleAvailability(value);
    if (value) {
      await _connectSocket();
      startTracking();
    } else {
      SocketService.emit("rider_offline", {"riderId": riderId});
      await gpsStream?.cancel();
      gpsStream = null;
      SocketService.disconnect();
    }
    setState(() => _toggling = false);
  }

  Future<void> startTracking() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;
    await gpsStream?.cancel();
    gpsStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      if (!online || riderId == null) return;
      SocketService.emit("rider_location_update", {
        "riderId": riderId,
        "lat": position.latitude,
        "lng": position.longitude,
      });
      ApiService.patch("/riders/location", {
        "lat": position.latitude,
        "lng": position.longitude,
      });
    });
  }

  Future<void> logout() async {
    await gpsStream?.cancel();
    gpsStream = null;
    SocketService.disconnect();
    await Session.clearAll();
    widget.onLogout?.call();
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RiderProfileScreen(
          onLogout: logout,
          onRoleSwitch: widget.onRoleSwitch,
        ),
      ),
    ).then((_) => loadDashboard());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    gpsStream?.cancel();
    SocketService.off("new_delivery");
    SocketService.disconnect();
    super.dispose();
  }

  String get _firstName => riderName.split(' ').first;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return "Good morning";
    if (h < 17) return "Good afternoon";
    return "Good evening";
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) return "${(amount / 1000000).toStringAsFixed(1)}M";
    if (amount >= 1000) return "${(amount / 1000).toStringAsFixed(1)}K";
    return amount.toStringAsFixed(0);
  }

  bool _dark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;

  Color _bg(BuildContext ctx) => _dark(ctx)
      ? RiderColors.backgroundDark
      : RiderColors.background;

  Color _card(BuildContext ctx) => _dark(ctx)
      ? RiderColors.surfaceDark
      : RiderColors.surface;

  Color _cardAlt(BuildContext ctx) => _dark(ctx)
      ? RiderColors.surfaceAltDark
      : RiderColors.surfaceAlt;

  Color _text(BuildContext ctx) => _dark(ctx)
      ? RiderColors.textDark
      : RiderColors.text;

  Color _muted(BuildContext ctx) => _dark(ctx)
      ? RiderColors.mutedDark
      : RiderColors.muted;

  Color _offline(BuildContext ctx) => _dark(ctx)
      ? RiderColors.offlineDark
      : RiderColors.offline;

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);

    if (loading) {
      return Scaffold(
        backgroundColor: _bg(context),
        body: const Center(child: CircularProgressIndicator(color: _kOnline)),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg(context),
        body: RefreshIndicator(
          color: _kOnline,
          backgroundColor: _card(context),
          onRefresh: loadDashboard,
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
                      _onlineToggleCard(context),
                      const SizedBox(height: 20),
                      _statsRow(context),
                      const SizedBox(height: 28),
                      _sectionLabel("QUICK ACTIONS", context),
                      const SizedBox(height: 14),
                      _actionCard(
                        context: context,
                        icon: Icons.delivery_dining_rounded,
                        title: "Active Orders",
                        subtitle: "View and manage your deliveries",
                        accent: _kBlue,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const RiderOrdersScreen())),
                      ),
                      const SizedBox(height: 12),
                      _actionCard(
                        context: context,
                        icon: Icons.account_balance_wallet_rounded,
                        title: "Wallet & Earnings",
                        subtitle: "Withdraw your balance",
                        accent: _kAmber,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const RiderWalletScreen())),
                      ),
                      const SizedBox(height: 12),
                      _actionCard(
                        context: context,
                        icon: Icons.person_rounded,
                        title: "My Profile",
                        subtitle: "Settings, bank details & role switch",
                        accent: _kPurple,
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

  Widget _verificationBanner(BuildContext context) {
    final isPending = _verificationStatus == "pending";
    final isFailed  = _verificationStatus == "failed";
    final color     = isFailed ? Colors.redAccent : _kAmber;

    return GestureDetector(
      onTap: isPending ? null : () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IdentityVerificationScreen(
            accentColor: _kOnline,
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
                          color: online ? _kOnline : _offline(context),
                          width: 2.5,
                        ),
                      ),
                      child: ClipOval(
                        child: profileImageUrl != null
                            ? Image.network(profileImageUrl!, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _avatarPlaceholder(context))
                            : _avatarPlaceholder(context),
                      ),
                    ),
                    Positioned(
                      bottom: 2, right: 2,
                      child: AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: online ? _kOnline : _offline(context),
                            border: Border.all(color: _bg(context), width: 2),
                            boxShadow: online
                                ? [BoxShadow(
                                    color: _kOnline.withOpacity(0.6 * _pulseAnim.value),
                                    blurRadius: 6)]
                                : [],
                          ),
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
                    if (riderRating > 0)
                      Row(children: [
                        const Icon(Icons.star_rounded, color: _kAmber, size: 13),
                        const SizedBox(width: 3),
                        Text(riderRating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: _kAmber, fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Text(
                          "($riderRatingCount ${riderRatingCount == 1 ? 'rating' : 'ratings'})",
                          style: TextStyle(color: _muted(context), fontSize: 11),
                        ),
                      ])
                    else
                      Text("No ratings yet",
                          style: TextStyle(color: _muted(context), fontSize: 11)),
                  ],
                ),
              ),
              // ── Notification bell ───────────────────────────────────
              NotificationBell(
                color: _text(context),
                badgeColor: _kOnline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder(BuildContext context) => Container(
        color: _cardAlt(context),
        child: Icon(Icons.person_outline, color: _muted(context), size: 28),
      );

  Widget _onlineToggleCard(BuildContext context) {
    final dark = _dark(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: online
              ? (dark
                  ? [const Color(0xFF0A2A1A), const Color(0xFF082215)]
                  : [const Color(0xFFE8F8F0), const Color(0xFFD4F2E4)])
              : [_card(context), _cardAlt(context)],
        ),
        border: Border.all(
          color: online
              ? _kOnline.withOpacity(0.4)
              : (dark
                  ? Colors.orange.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.15)),
        ),
        boxShadow: online
            ? [BoxShadow(
                color: _kOnline.withOpacity(0.15),
                blurRadius: 24, offset: const Offset(0, 8))]
            : [],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => SizedBox(
              width: 40, height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (online)
                    Container(
                      width: 40 * _pulseAnim.value,
                      height: 40 * _pulseAnim.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kOnline.withOpacity(0.15 * _pulseAnim.value),
                      ),
                    ),
                  Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online ? _kOnline : _muted(context),
                      boxShadow: online
                          ? [BoxShadow(
                              color: _kOnline.withOpacity(0.6), blurRadius: 8)]
                          : [],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  online ? "You're Online" : "You're Offline",
                  style: TextStyle(
                    color: online ? _kOnline : _text(context),
                    fontSize: 17, fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  online ? "Ready to receive new orders" : "Go online to start earning",
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
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kOnline),
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: () => toggleOnline(!online),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 52, height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: online ? _kOnline : _offline(context),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment:
                          online ? Alignment.centerRight : Alignment.centerLeft,
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

  Widget _statsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _statCard(
          context: context,
          label: "Today's Orders",
          value: ordersToday.toString(),
          icon: Icons.receipt_long_rounded,
          accent: _kBlue,
        )),
        const SizedBox(width: 14),
        Expanded(child: _statCard(
          context: context,
          label: "Total Earned",
          value: "₦${_formatAmount(earnings)}",
          icon: Icons.account_balance_wallet_rounded,
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
                ? Colors.orange.withOpacity(0.1)
                : Colors.orange.withOpacity(0.12)),
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
          Text(label, style: TextStyle(color: _muted(context), fontSize: 11)),
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
                  ? Colors.orange.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.12)),
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