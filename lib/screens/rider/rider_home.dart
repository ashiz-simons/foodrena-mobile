import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../../utils/session.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/rider_service.dart';

import 'rider_orders_screen.dart';
import 'rider_wallet_screen.dart';
import 'rider_profile_screen.dart';

const _kDark    = Color(0xFFFFF8F2);
const _kCard    = Color(0xFFFFFFFF);
const _kCardAlt = Color(0xFFFFF0E6);
const _kOnline  = Color(0xFF00D97E);
const _kOffline = Color(0xFF3A3F50);
const _kAmber   = Color(0xFFFFC542);
const _kBlue    = Color(0xFF4A90E2);
const _kText    = Color(0xFF1A1A1A);
const _kMuted   = Color(0xFF888888);
const _kPurple  = Color(0xFFB06EFF);

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
    await loadDashboard();
    if (mounted) setState(() => loading = false);
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: const Color(0xFFFFF8F2),
        body: Center(child: CircularProgressIndicator(color: _kOnline)),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _kDark,
        body: RefreshIndicator(
          color: _kOnline,
          backgroundColor: Colors.white,
          onRefresh: loadDashboard,
          child: CustomScrollView(
            slivers: [
              _buildHeader(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  child: Column(
                    children: [
                      _onlineToggleCard(),
                      const SizedBox(height: 20),
                      _statsRow(),
                      const SizedBox(height: 28),
                      _sectionLabel("QUICK ACTIONS"),
                      const SizedBox(height: 14),
                      _actionCard(
                        icon: Icons.delivery_dining_rounded,
                        title: "Active Orders",
                        subtitle: "View and manage your deliveries",
                        accent: _kBlue,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const RiderOrdersScreen())),
                      ),
                      const SizedBox(height: 12),
                      _actionCard(
                        icon: Icons.account_balance_wallet_rounded,
                        title: "Wallet & Earnings",
                        subtitle: "Withdraw your balance",
                        accent: _kAmber,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const RiderWalletScreen())),
                      ),
                      const SizedBox(height: 12),
                      _actionCard(
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

  // ── HEADER ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar → profile
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
                          color: online ? _kOnline : _kOffline,
                          width: 2.5,
                        ),
                      ),
                      child: ClipOval(
                        child: profileImageUrl != null
                            ? Image.network(profileImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _avatarPlaceholder())
                            : _avatarPlaceholder(),
                      ),
                    ),
                    // Online dot
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: online ? _kOnline : _kOffline,
                            border: Border.all(color: _kDark, width: 2),
                            boxShadow: online
                                ? [BoxShadow(
                                    color: _kOnline.withOpacity(
                                        0.6 * _pulseAnim.value),
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
                    if (riderRating > 0)
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: _kAmber, size: 13),
                          const SizedBox(width: 3),
                          Text(riderRating.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: _kAmber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          Text(
                            "($riderRatingCount ${riderRatingCount == 1 ? 'rating' : 'ratings'})",
                            style: const TextStyle(
                                color: _kMuted, fontSize: 11),
                          ),
                        ],
                      )
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
        color: const Color(0xFFFFF0E6),
        child: const Icon(Icons.person_outline, color: _kMuted, size: 28),
      );

  Widget _onlineToggleCard() {
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
              ? [const Color(0xFFE8F8F0), const Color(0xFFD4F2E4)]
              : [const Color(0xFFFFFFFF), const Color(0xFFFFF0E6)],
        ),
        border: Border.all(
          color: online
              ? _kOnline.withOpacity(0.4)
              : Colors.orange.withOpacity(0.15),
        ),
        boxShadow: online
            ? [BoxShadow(
                color: _kOnline.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8))]
            : [],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => SizedBox(
              width: 40,
              height: 40,
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
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online ? _kOnline : _kMuted,
                      boxShadow: online
                          ? [BoxShadow(
                              color: _kOnline.withOpacity(0.6),
                              blurRadius: 8)]
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
                    color: online ? _kOnline : _kText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  online ? "Ready to receive new orders" : "Go online to start earning",
                  style: const TextStyle(color: _kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          _toggling
              ? const SizedBox(
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
                    width: 52,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: online ? _kOnline : _kOffline,
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: online
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        width: 22, height: 22,
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

  Widget _statsRow() {
    return Row(
      children: [
        Expanded(child: _statCard(
          label: "Today's Orders",
          value: ordersToday.toString(),
          icon: Icons.receipt_long_rounded,
          accent: _kBlue,
        )),
        const SizedBox(width: 14),
        Expanded(child: _statCard(
          label: "Total Earned",
          value: "₦${_formatAmount(earnings)}",
          icon: Icons.account_balance_wallet_rounded,
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
        border: Border.all(color: Colors.orange.withOpacity(0.12)),
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
                  color: _kText, fontSize: 22,
                  fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: _kMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text,
          style: const TextStyle(
              color: _kMuted, fontSize: 11,
              fontWeight: FontWeight.w600, letterSpacing: 1.4)),
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
          border: Border.all(color: Colors.orange.withOpacity(0.12)),
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
                          color: _kText, fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(color: _kMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: _kMuted),
          ],
        ),
      ),
    );
  }
}