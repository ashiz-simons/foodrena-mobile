import 'package:flutter/material.dart';
import '../../services/vendor_service.dart';
import '../../core/theme/app_theme.dart';

class PreferredRidersScreen extends StatefulWidget {
  const PreferredRidersScreen({super.key});

  @override
  State<PreferredRidersScreen> createState() => _PreferredRidersScreenState();
}

class _PreferredRidersScreenState extends State<PreferredRidersScreen> {
  bool _loading = true;
  bool _usePreferred = false;
  bool _fallback = true;
  List _riders = [];

  static const _kTeal = Color(0xFF00B4B4);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await VendorService.getPreferredRiders();
      if (mounted) {
        setState(() {
          _riders = res['preferredRiders'] ?? [];
          _usePreferred = res['usePreferredRiders'] ?? false;
          _fallback = res['fallbackToAutoAssign'] ?? true;
        });
      }
    } catch (e) {
      _showError("Failed to load preferred riders");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      await VendorService.updatePreferredRiderSettings(
        usePreferredRiders: _usePreferred,
        fallbackToAutoAssign: _fallback,
      );
      _showSnack("Settings saved");
    } catch (e) {
      _showError("Failed to save settings");
    }
  }

  Future<void> _removeRider(String riderId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove Rider"),
        content: Text("Remove $name from your preferred riders?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await VendorService.removePreferredRider(riderId);
      setState(() => _riders.removeWhere((r) => r['_id'] == riderId));
      _showSnack("$name removed");
    } catch (e) {
      _showError("Failed to remove rider");
    }
  }

  Future<void> _showAddRiderDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Preferred Rider"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter the rider's User ID.\nYou can find this from a completed order.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Rider User ID",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final id = controller.text.trim();
              if (id.isEmpty) return;
              Navigator.pop(context);
              await _addRider(id);
            },
            child: Text("Add", style: TextStyle(color: _kTeal)),
          ),
        ],
      ),
    );
  }

  Future<void> _addRider(String riderId) async {
    try {
      await VendorService.addPreferredRider(riderId);
      _showSnack("Rider added to preferred list");
      await _load();
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: _kTeal),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  bool _dark() => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final dark = _dark();
    final bg = dark ? VendorColors.backgroundDark : VendorColors.background;
    final card = dark ? VendorColors.surfaceDark : VendorColors.surface;
    final text = dark ? VendorColors.textDark : VendorColors.text;
    final muted = dark ? VendorColors.mutedDark : VendorColors.muted;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text("Preferred Riders",
            style: TextStyle(color: text, fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: text),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRiderDialog,
        backgroundColor: _kTeal,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text("Add Rider", style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _kTeal))
          : RefreshIndicator(
              color: _kTeal,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  // ── Settings Card ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _usePreferred
                            ? _kTeal.withOpacity(0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Assignment Settings",
                            style: TextStyle(
                                color: text,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          "Control how riders are assigned to your orders",
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        _settingRow(
                          title: "Use Preferred Riders First",
                          subtitle:
                              "Offer new orders to your preferred riders before others",
                          value: _usePreferred,
                          onChanged: (val) {
                            setState(() => _usePreferred = val);
                            _saveSettings();
                          },
                          text: text,
                          muted: muted,
                        ),
                        const Divider(height: 24),
                        _settingRow(
                          title: "Fall Back to Auto-Assign",
                          subtitle:
                              "If no preferred riders accept, assign to nearest available rider",
                          value: _fallback,
                          onChanged: _usePreferred
                              ? (val) {
                                  setState(() => _fallback = val);
                                  _saveSettings();
                                }
                              : null,
                          text: text,
                          muted: muted,
                        ),
                        if (!_usePreferred)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              "Enable preferred riders first to configure fallback",
                              style:
                                  TextStyle(color: muted, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Riders List ────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Your Preferred Riders",
                          style: TextStyle(
                              color: text,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      Text("${_riders.length} rider${_riders.length == 1 ? '' : 's'}",
                          style: TextStyle(color: muted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_riders.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.people_outline_rounded,
                              size: 48, color: muted),
                          const SizedBox(height: 12),
                          Text("No preferred riders yet",
                              style: TextStyle(
                                  color: text, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            "Add riders you trust for faster order assignment",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else
                    ...(_riders.map((rider) => _riderCard(
                          rider: rider,
                          card: card,
                          text: text,
                          muted: muted,
                        ))),
                ],
              ),
            ),
    );
  }

  Widget _settingRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required Color text,
    required Color muted,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: onChanged != null ? text : muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(color: muted, fontSize: 11)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: _kTeal,
        ),
      ],
    );
  }

  Widget _riderCard({
    required Map rider,
    required Color card,
    required Color text,
    required Color muted,
  }) {
    final name = rider['name'] ?? 'Unknown Rider';
    final phone = rider['phone'] ?? '';
    final imageUrl = rider['profileImage']?['url'];
    final riderId = rider['_id'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _kTeal.withOpacity(0.15),
            backgroundImage:
                imageUrl != null ? NetworkImage(imageUrl) : null,
            child: imageUrl == null
                ? Icon(Icons.person_rounded, color: _kTeal, size: 24)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: text,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                if (phone.isNotEmpty)
                  Text(phone,
                      style: TextStyle(color: muted, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeRider(riderId, name),
            icon: const Icon(Icons.remove_circle_outline_rounded,
                color: Colors.redAccent, size: 22),
            tooltip: "Remove",
          ),
        ],
      ),
    );
  }
}