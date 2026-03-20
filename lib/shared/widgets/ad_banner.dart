import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../core/theme/app_theme.dart';

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  static List<Map<String, dynamic>> _cachedBanners = [];
  static DateTime? _lastFetch;

  List<Map<String, dynamic>> _banners = [];
  bool _loading = true;
  int _currentIndex = 0;
  Timer? _autoScrollTimer;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    // Use cache if fetched within last 5 minutes
    final now = DateTime.now();
    if (_cachedBanners.isNotEmpty &&
        _lastFetch != null &&
        now.difference(_lastFetch!).inMinutes < 5) {
      if (mounted) {
        setState(() {
          _banners = _cachedBanners;
          _loading = false;
        });
        _startAutoScroll();
      }
      return;
    }

    try {
      final res = await ApiService.get("/banners");
      if (res is List) {
        _cachedBanners = res.map((b) => Map<String, dynamic>.from(b)).toList();
        _lastFetch = now;
        if (mounted) {
          setState(() {
            _banners = _cachedBanners;
            _loading = false;
          });
          _startAutoScroll();
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startAutoScroll() {
    if (_banners.length <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _banners.isEmpty) return;
      final next = (_currentIndex + 1) % _banners.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? CustomerColors.primaryDark : CustomerColors.primary;

    // Loading state
    if (_loading) {
      return Container(
        height: 90,
        decoration: BoxDecoration(
          color: primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: primary),
          ),
        ),
      );
    }

    // Fallback — no banners from API
    if (_banners.isEmpty) {
      return _fallbackBanner(isDark, primary);
    }

    // Dynamic banners carousel
    return Column(
      children: [
        SizedBox(
          height: 90,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) {
              final banner = _banners[i];
              final imageUrl = banner["imageUrl"] ?? "";
              final title = banner["title"] ?? "";

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: primary.withOpacity(0.08),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) =>
                              _fallbackBannerChild(isDark, primary, title),
                        )
                      : _fallbackBannerChild(isDark, primary, title),
                ),
              );
            },
          ),
        ),

        // Dots indicator
        if (_banners.length > 1) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_banners.length, (i) {
              final isActive = i == _currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? primary
                      : primary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _fallbackBanner(bool isDark, Color primary) {
    final textColor = isDark
        ? CustomerColors.textPrimaryDark
        : CustomerColors.textPrimary;
    return Container(
      height: 90,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.campaign, color: primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "🎉 Promo: Free delivery on your first order",
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackBannerChild(bool isDark, Color primary, String title) {
    final textColor = isDark
        ? CustomerColors.textPrimaryDark
        : CustomerColors.textPrimary;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.campaign, color: primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title.isNotEmpty
                  ? title
                  : "🎉 Promo: Free delivery on your first order",
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}