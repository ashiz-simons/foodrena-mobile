import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../services/support_service.dart';
import '../../services/order_service.dart';

// ── Contact details — update these ────────────────────────────────────────
const _kWhatsApp = "2348145394013"; // no + sign, with country code
const _kPhone    = "+2348145394013";
const _kEmail    = "support@foodrena.com";
// ──────────────────────────────────────────────────────────────────────────

class CustomerSupport extends StatefulWidget {
  const CustomerSupport({super.key});

  @override
  State<CustomerSupport> createState() => _CustomerSupportState();
}

class _CustomerSupportState extends State<CustomerSupport>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg    => _dark ? const Color(0xFF1A0808) : const Color(0xFFFFF0F0);
  Color get _card  => _dark ? const Color(0xFF2C1010) : Colors.white;
  Color get _text  => _dark ? Colors.white : const Color(0xFF1A1A1A);
  Color get _muted => _dark ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _red   => CustomerColors.primary;
  Color get _border=> _dark ? Colors.white10 : Colors.grey.shade200;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text("Support",
            style: TextStyle(
                color: _text, fontWeight: FontWeight.w700, fontSize: 18)),
        iconTheme: IconThemeData(color: _text),
        bottom: TabBar(
          controller: _tabs,
          labelColor: _red,
          unselectedLabelColor: _muted,
          indicatorColor: _red,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: "Help"),
            Tab(text: "Contact"),
            Tab(text: "My Tickets"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _FaqTab(dark: _dark, bg: _bg, card: _card, text: _text,
              muted: _muted, red: _red, border: _border),
          _ContactTab(dark: _dark, bg: _bg, card: _card, text: _text,
              muted: _muted, red: _red, border: _border,
              onNewTicket: () => _tabs.animateTo(2)),
          _TicketsTab(dark: _dark, bg: _bg, card: _card, text: _text,
              muted: _muted, red: _red, border: _border),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 — FAQ
// ═══════════════════════════════════════════════════════════════════════════
class _FaqTab extends StatefulWidget {
  final bool dark;
  final Color bg, card, text, muted, red, border;
  const _FaqTab({required this.dark, required this.bg, required this.card,
      required this.text, required this.muted, required this.red,
      required this.border});
  @override State<_FaqTab> createState() => _FaqTabState();
}

class _FaqTabState extends State<_FaqTab> {
  int? _open;

  static const _faqs = [
    {
      "q": "How do I place an order?",
      "a": "Browse vendors on the home screen, tap a vendor to see their menu, add items to your cart, confirm your delivery address, and proceed to checkout. Payment is handled securely via Paystack."
    },
    {
      "q": "How long does delivery take?",
      "a": "Delivery time depends on the vendor's preparation time and your distance. You'll see an estimated time on the order tracking screen once a rider is assigned."
    },
    {
      "q": "Can I cancel my order?",
      "a": "You can cancel an order while it's still in 'pending' status before the vendor accepts it. Once a vendor accepts your order, cancellation is no longer available through the app — contact support."
    },
    {
      "q": "How do refunds work?",
      "a": "If your order was not delivered or you received the wrong items, you can request a refund through the Support tab. Refunds are reviewed within 24–48 hours and returned to your original payment method."
    },
    {
      "q": "My rider marked the order as delivered but I didn't receive it.",
      "a": "Please raise a support ticket immediately with your order details. Our team will investigate and resolve it within 24 hours."
    },
    {
      "q": "I was charged but no order was created.",
      "a": "This can happen if the connection dropped during checkout. Check your order history. If no order appears within 10 minutes, raise a support ticket with your payment reference and we'll investigate."
    },
    {
      "q": "How do I change my delivery address?",
      "a": "You can update your delivery address in the cart before placing an order. Once an order is placed, the address cannot be changed — contact support if there's an urgent issue."
    },
    {
      "q": "How do I become a vendor or rider?",
      "a": "Go to your profile, tap 'Switch Role', and select Vendor or Rider. You'll be guided through a short onboarding process."
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: widget.red.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.red.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.help_outline_rounded, color: widget.red, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Can't find your answer? Use the Contact tab to reach us directly.",
                  style: TextStyle(color: widget.red.withOpacity(0.85), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        ..._faqs.asMap().entries.map((e) {
          final i    = e.key;
          final faq  = e.value;
          final open = _open == i;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: widget.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: open
                      ? widget.red.withOpacity(0.3)
                      : widget.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _open = open ? null : i),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(faq["q"]!,
                                  style: TextStyle(
                                      color: open ? widget.red : widget.text,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                            ),
                            Icon(
                              open
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: open ? widget.red : widget.muted,
                            ),
                          ],
                        ),
                      ),
                      if (open)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: Text(faq["a"]!,
                              style: TextStyle(
                                  color: widget.muted,
                                  fontSize: 13,
                                  height: 1.6)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2 — CONTACT + NEW TICKET FORM
// ═══════════════════════════════════════════════════════════════════════════
class _ContactTab extends StatefulWidget {
  final bool dark;
  final Color bg, card, text, muted, red, border;
  final VoidCallback onNewTicket;
  const _ContactTab({required this.dark, required this.bg, required this.card,
      required this.text, required this.muted, required this.red,
      required this.border, required this.onNewTicket});
  @override State<_ContactTab> createState() => _ContactTabState();
}

class _ContactTabState extends State<_ContactTab> {
  final _subjectCtrl     = TextEditingController();
  final _descCtrl        = TextEditingController();
  String  _category      = "other";
  String? _selectedOrderId;
  List<Map<String, dynamic>> _orders = [];
  bool _loadingOrders    = false;
  bool _submitting       = false;
  String _submitError    = "";
  bool _submitSuccess    = false;

  static const _categories = [
    {"value": "refund",   "label": "Refund Request"},
    {"value": "delivery", "label": "Delivery Issue"},
    {"value": "payment",  "label": "Payment Problem"},
    {"value": "account",  "label": "Account Issue"},
    {"value": "other",    "label": "Other"},
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _loadingOrders = true);
    try {
      final orders = await OrderService.fetchActiveOrders();
      // also fetch recent completed
      setState(() => _orders = orders);
    } catch (_) {}
    if (mounted) setState(() => _loadingOrders = false);
  }

  Future<void> _submit() async {
    if (_subjectCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      setState(() => _submitError = "Please fill in subject and description");
      return;
    }
    setState(() { _submitting = true; _submitError = ""; });
    try {
      await SupportService.createTicket(
        category:    _category,
        subject:     _subjectCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        orderId:     _selectedOrderId,
      );
      if (!mounted) return;
      setState(() { _submitting = false; _submitSuccess = true; });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) widget.onNewTicket();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.toString().replaceAll("Exception: ", "");
        _submitting  = false;
      });
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // ── Quick contact ────────────────────────────────────────────────
        Text("Reach us directly",
            style: TextStyle(color: widget.text, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _contactBtn(
              icon: Icons.chat_rounded,
              label: "WhatsApp",
              color: const Color(0xFF25D366),
              onTap: () => _launch("https://wa.me/$_kWhatsApp"),
            )),
            const SizedBox(width: 10),
            Expanded(child: _contactBtn(
              icon: Icons.phone_rounded,
              label: "Call Us",
              color: const Color(0xFF4A90E2),
              onTap: () => _launch("tel:$_kPhone"),
            )),
            const SizedBox(width: 10),
            Expanded(child: _contactBtn(
              icon: Icons.email_rounded,
              label: "Email",
              color: widget.red,
              onTap: () => _launch("mailto:$_kEmail"),
            )),
          ],
        ),
        const SizedBox(height: 28),

        // ── Ticket form ──────────────────────────────────────────────────
        Text("Submit a ticket",
            style: TextStyle(color: widget.text, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 4),
        Text("We'll respond within 24 hours",
            style: TextStyle(color: widget.muted, fontSize: 12)),
        const SizedBox(height: 14),

        if (_submitSuccess)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(child: Text("Ticket submitted! Redirecting to your tickets...",
                    style: TextStyle(color: Colors.green.shade700, fontSize: 13))),
              ],
            ),
          )
        else ...[
          // Category
          _label("Category"),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: widget.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _category,
                isExpanded: true,
                dropdownColor: widget.card,
                style: TextStyle(color: widget.text, fontSize: 14),
                items: _categories.map((c) => DropdownMenuItem(
                  value: c["value"],
                  child: Text(c["label"]!),
                )).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Link to order (optional)
          _label("Related Order (optional)"),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: widget.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedOrderId,
                isExpanded: true,
                dropdownColor: widget.card,
                style: TextStyle(color: widget.text, fontSize: 14),
                hint: Text("No specific order",
                    style: TextStyle(color: widget.muted, fontSize: 13)),
                items: [
                  DropdownMenuItem<String?>(
                      value: null,
                      child: Text("No specific order",
                          style: TextStyle(color: widget.muted))),
                  ..._orders.map((o) => DropdownMenuItem<String?>(
                    value: o["_id"] as String,
                    child: Text(
                      "#${(o["_id"] as String).substring(0, 8).toUpperCase()} — ${o["status"]}",
                      style: TextStyle(color: widget.text, fontSize: 13),
                    ),
                  )),
                ],
                onChanged: (v) => setState(() => _selectedOrderId = v),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Subject
          _label("Subject *"),
          const SizedBox(height: 8),
          _textField(controller: _subjectCtrl, hint: "e.g. Wrong items delivered"),
          const SizedBox(height: 12),

          // Description
          _label("Description *"),
          const SizedBox(height: 8),
          _textField(
            controller: _descCtrl,
            hint: "Describe your issue in detail...",
            maxLines: 5,
          ),

          if (_submitError.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_submitError,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Submit Ticket",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _contactBtn({required IconData icon, required String label,
      required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: TextStyle(
          color: widget.text, fontWeight: FontWeight.w600, fontSize: 13));

  Widget _textField({required TextEditingController controller,
      required String hint, int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: widget.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: widget.muted, fontSize: 13),
        filled: true,
        fillColor: widget.card,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.red, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3 — MY TICKETS + CHAT
// ═══════════════════════════════════════════════════════════════════════════
class _TicketsTab extends StatefulWidget {
  final bool dark;
  final Color bg, card, text, muted, red, border;
  const _TicketsTab({required this.dark, required this.bg, required this.card,
      required this.text, required this.muted, required this.red,
      required this.border});
  @override State<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<_TicketsTab> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final t = await SupportService.myTickets();
      if (mounted) setState(() { _tickets = t; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case "open":        return Colors.blue;
      case "in_progress": return Colors.orange;
      case "resolved":    return Colors.green;
      default:            return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case "open":        return "Open";
      case "in_progress": return "In Progress";
      case "resolved":    return "Resolved";
      default:            return "Closed";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: widget.red));
    }
    if (_tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 48,
                color: widget.muted.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text("No tickets yet",
                style: TextStyle(color: widget.muted, fontSize: 15)),
            const SizedBox(height: 6),
            Text("Submit a ticket from the Contact tab",
                style: TextStyle(color: widget.muted, fontSize: 12)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: widget.red,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        itemCount: _tickets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final t      = _tickets[i];
          final status = t["status"] as String? ?? "open";
          final sc     = _statusColor(status);
          return GestureDetector(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => _TicketChatScreen(
                  ticketId: t["_id"] as String,
                  subject:  t["subject"] as String? ?? "Support Ticket",
                  dark: widget.dark,
                ),
              ));
              _load(); // refresh after returning
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: widget.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: sc.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.support_agent_rounded, color: sc, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t["subject"] as String? ?? "—",
                            style: TextStyle(
                                color: widget.text,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(
                          (t["category"] as String? ?? "other")
                              .replaceAll("_", " ")
                              .toUpperCase(),
                          style: TextStyle(color: widget.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sc.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_statusLabel(status),
                        style: TextStyle(
                            color: sc,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TICKET CHAT SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class _TicketChatScreen extends StatefulWidget {
  final String ticketId;
  final String subject;
  final bool dark;
  const _TicketChatScreen({
    required this.ticketId,
    required this.subject,
    required this.dark,
  });
  @override State<_TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends State<_TicketChatScreen> {
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  Map<String, dynamic>? _ticket;
  bool _loading  = true;
  bool _sending  = false;

  bool  get _dark   => widget.dark;
  Color get _bg     => _dark ? const Color(0xFF1A0808) : const Color(0xFFFFF0F0);
  Color get _card   => _dark ? const Color(0xFF2C1010) : Colors.white;
  Color get _text   => _dark ? Colors.white : const Color(0xFF1A1A1A);
  Color get _muted  => _dark ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _red    => CustomerColors.primary;
  Color get _bubble => _dark ? const Color(0xFF3A1515) : const Color(0xFFFFF0F0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final t = await SupportService.getTicket(widget.ticketId);
      if (mounted) {
        setState(() { _ticket = t; _loading = false; });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      final t = await SupportService.sendMessage(widget.ticketId, text);
      if (mounted) {
        setState(() { _ticket = t; _sending = false; });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _ticket != null
        ? List<Map<String, dynamic>>.from(_ticket!["messages"] ?? [])
        : <Map<String, dynamic>>[];
    final status   = _ticket?["status"] as String? ?? "open";
    final closed   = status == "closed";

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: IconThemeData(color: _text),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.subject,
                style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(status.replaceAll("_", " ").toUpperCase(),
                style: TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _red))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg       = messages[i];
                      final isCustomer= msg["sender"] == "customer";
                      return Align(
                        alignment: isCustomer
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.72),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isCustomer ? _red : _card,
                            borderRadius: BorderRadius.only(
                              topLeft:     const Radius.circular(14),
                              topRight:    const Radius.circular(14),
                              bottomLeft:  Radius.circular(isCustomer ? 14 : 2),
                              bottomRight: Radius.circular(isCustomer ? 2  : 14),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isCustomer)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text("Support",
                                      style: TextStyle(
                                          color: _red,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ),
                              Text(msg["text"] as String? ?? "",
                                  style: TextStyle(
                                      color: isCustomer
                                          ? Colors.white
                                          : _text,
                                      fontSize: 14,
                                      height: 1.4)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── Input bar ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  decoration: BoxDecoration(
                    color: _card,
                    border: Border(
                        top: BorderSide(
                            color: _dark ? Colors.white10 : Colors.grey.shade200)),
                  ),
                  child: closed
                      ? Center(
                          child: Text("This ticket is closed",
                              style: TextStyle(
                                  color: _muted, fontSize: 13)),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _msgCtrl,
                                style: TextStyle(color: _text, fontSize: 14),
                                maxLines: 3,
                                minLines: 1,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText: "Type a message...",
                                  hintStyle: TextStyle(
                                      color: _muted, fontSize: 13),
                                  filled: true,
                                  fillColor: _dark
                                      ? const Color(0xFF1A0808)
                                      : const Color(0xFFF7F7F7),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      borderSide: BorderSide.none),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _sending ? null : _send,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _sending
                                      ? _red.withOpacity(0.5)
                                      : _red,
                                  shape: BoxShape.circle,
                                ),
                                child: _sending
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Icon(Icons.send_rounded,
                                        color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}