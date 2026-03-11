import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/vendor_wallet_service.dart';
import '../vendor/vendor_bank_screen.dart';

const _kBg      = Color(0xFFF0FAFA);
const _kCard    = Color(0xFFFFFFFF);
const _kCardAlt = Color(0xFFE0F7F7);
const _kTeal    = Color(0xFF00B4B4);
const _kAmber   = Color(0xFFFFC542);
const _kText    = Color(0xFF1A1A1A);
const _kMuted   = Color(0xFF6B8A8A);

class VendorWalletScreen extends StatefulWidget {
  const VendorWalletScreen({super.key});
  @override
  State<VendorWalletScreen> createState() => _VendorWalletScreenState();
}

class _VendorWalletScreenState extends State<VendorWalletScreen> {
  bool _loading = true;
  bool _withdrawing = false;
  Map _wallet = {};
  List _withdrawals = [];
  final _amountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        VendorWalletService.getWallet(),
        VendorWalletService.getWithdrawals(),
      ]);
      if (!mounted) return;
      setState(() {
        _wallet = results[0] as Map;
        _withdrawals = results[1] as List;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _withdraw() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    final balance = (_wallet["balance"] ?? 0).toDouble();
    final bank = _wallet["bank"];

    if (amount == null || amount <= 0) {
      _snack("Enter a valid amount", error: true); return;
    }
    if (amount < 500) {
      _snack("Minimum withdrawal is ₦500", error: true); return;
    }
    if (amount > balance) {
      _snack("Insufficient balance", error: true); return;
    }
    if (bank == null || bank["accountNumber"] == null) {
      _snack("Please add bank details first", error: true);
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const VendorBankScreen()))
          .then((_) => _load());
      return;
    }

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Confirm Withdrawal",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          "Withdraw ₦${amount.toStringAsFixed(0)} to\n"
          "${bank["bankName"] ?? ""} · ${bank["accountNumber"] ?? ""}?",
          style: const TextStyle(color: _kMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: _kMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Withdraw",
                style: TextStyle(color: _kTeal, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _withdrawing = true);
    try {
      await VendorWalletService.withdraw(amount);
      _amountCtrl.clear();
      _snack("Withdrawal requested successfully");
      await _load();
    } catch (e) {
      _snack(e.toString().replaceAll("Exception: ", ""), error: true);
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : _kTeal,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text("Wallet & Earnings",
            style: TextStyle(
                color: _kText, fontWeight: FontWeight.w700, fontSize: 17)),
        iconTheme: const IconThemeData(color: _kText),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kTeal))
          : RefreshIndicator(
              color: _kTeal,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  _balanceCard(),
                  const SizedBox(height: 16),
                  _bankCard(),
                  const SizedBox(height: 20),
                  _withdrawCard(),
                  const SizedBox(height: 24),
                  _historySection(),
                ],
              ),
            ),
    );
  }

  Widget _balanceCard() {
    final balance = (_wallet["balance"] ?? 0).toDouble();
    final pending = (_wallet["pendingBalance"] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00B4B4), Color(0xFF007A7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _kTeal.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Available Balance",
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            "₦${balance.toStringAsFixed(2)}",
            style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800),
          ),
          if (pending > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      color: Colors.white70, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    "₦${pending.toStringAsFixed(2)} pending",
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bankCard() {
    final bank = _wallet["bank"];
    final hasBankDetails = bank != null && bank["accountNumber"] != null;

    return GestureDetector(
      onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const VendorBankScreen()))
          .then((_) => _load()),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: hasBankDetails
                  ? _kTeal.withOpacity(0.2)
                  : _kAmber.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: hasBankDetails
                    ? _kTeal.withOpacity(0.1)
                    : _kAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.account_balance_rounded,
                  color: hasBankDetails ? _kTeal : _kAmber, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: hasBankDetails
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bank["bankName"] ?? "Bank",
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: _kText)),
                        const SizedBox(height: 2),
                        Text(
                          "${bank["accountName"] ?? ""} · ${bank["accountNumber"] ?? ""}",
                          style: const TextStyle(
                              fontSize: 12, color: _kMuted),
                        ),
                      ],
                    )
                  : const Text("Add bank details to withdraw",
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: _kAmber)),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14,
                color: hasBankDetails ? _kMuted : _kAmber),
          ],
        ),
      ),
    );
  }

  Widget _withdrawCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kTeal.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Withdraw Funds",
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _kText)),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 14, color: _kText),
            decoration: InputDecoration(
              hintText: "Enter amount (min ₦500)",
              hintStyle:
                  const TextStyle(color: _kMuted, fontSize: 13),
              prefixText: "₦ ",
              prefixStyle: const TextStyle(
                  color: _kTeal, fontWeight: FontWeight.w600),
              filled: true,
              fillColor: _kCardAlt,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: _kTeal, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _withdrawing ? null : _withdraw,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _withdrawing
                      ? _kTeal.withOpacity(0.5)
                      : _kTeal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: _withdrawing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Text("Request Withdrawal",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Withdrawal History",
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: _kText)),
        const SizedBox(height: 12),
        if (_withdrawals.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  const Text("No withdrawals yet",
                      style:
                          TextStyle(color: _kMuted, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          ..._withdrawals.map((w) => _withdrawalTile(w)),
      ],
    );
  }

  Widget _withdrawalTile(Map w) {
    final status = (w["status"] ?? "pending").toString();
    final amount = (w["amount"] ?? 0).toDouble();
    final date = w["createdAt"]?.toString().substring(0, 10) ?? "";

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case "paid":
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case "failed":
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = _kAmber;
        statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("₦${amount.toStringAsFixed(2)}",
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _kText)),
                const SizedBox(height: 2),
                Text(date,
                    style: const TextStyle(
                        fontSize: 11, color: _kMuted)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}