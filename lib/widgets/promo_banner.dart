import 'package:flutter/material.dart';
import '../../services/promo_service.dart';

class PromoBanner extends StatefulWidget {
  const PromoBanner({super.key});

  @override
  State<PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<PromoBanner> {
  List _promos = [];
  bool _loading = true;
  final PageController _pageCtrl = PageController();
  int _current = 0;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await PromoService.getPublicPromos();
      if (mounted) setState(() { _promos = res; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _describePromo(Map p) {
    if (p["type"] == "free_delivery") {
      final min = (p["minOrder"] ?? 0) as num;
      return min > 0
          ? "Free delivery on orders above ₦$min"
          : "Free delivery on your order";
    }
    final pct = p["discountPercent"];
    final min = (p["minOrder"] ?? 0) as num;
    final firstOnly = p["firstOrderOnly"] == true;
    String desc = "$pct% off";
    if (firstOnly) desc += " your first order";
    if (min > 0) desc += " (min ₦$min)";
    return desc;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 72,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _dark ? const Color(0xFF1A1208) : const Color(0xFFFFF0E6),
          borderRadius: BorderRadius.circular(14),
        ),
      );
    }

    if (_promos.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 72,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: _promos.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) {
              final p = _promos[i] as Map;
              final isDelivery = p["type"] == "free_delivery";
              final color = isDelivery ? Colors.green : const Color(0xFFDC2626);
              final bg    = isDelivery
                  ? (_dark ? const Color(0xFF0A2010) : const Color(0xFFECFDF5))
                  : (_dark ? const Color(0xFF2C1010) : const Color(0xFFFFF0F0));

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDelivery ? Icons.delivery_dining_rounded : Icons.discount_rounded,
                        color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  p["code"] ?? "",
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    letterSpacing: 1.2,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              if (p["firstOrderOnly"] == true) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text("First order",
                                      style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _describePromo(p),
                            style: TextStyle(
                              color: color.withOpacity(0.8),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_promos.length > 1) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_promos.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: _current == i ? 14 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: _current == i
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFDC2626).withOpacity(0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            )),
          ),
        ],
      ],
    );
  }
}