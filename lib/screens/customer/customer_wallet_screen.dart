import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../services/customer_wallet_service.dart';

class CustomerWalletScreen extends StatefulWidget {
  const CustomerWalletScreen({super.key});

  @override
  State<CustomerWalletScreen> createState() => _CustomerWalletScreenState();
}

class _CustomerWalletScreenState extends State<CustomerWalletScreen> {
  double? _balance;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  String? _error;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        CustomerWalletService.getBalance(),
        CustomerWalletService.getTransactions(),
      ]);
      if (!mounted) return;
      setState(() {
        _balance = results[0] as double;
        _transactions = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll("Exception: ", "");
        _loading = false;
      });
    }
  }

  Color get _bg => _dark ? CustomerColors.backgroundDark : const Color(0xFFF7F7F7);
  Color get _card => _dark ? const Color(0xFF2C1010) : Colors.white;
  Color get _border => _dark ? Colors.grey.shade800 : Colors.grey.shade200;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text("My Wallet"),
        backgroundColor: _dark ? const Color(0xFF1A0808) : null,
        foregroundColor: _dark ? Colors.white : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _balanceCard(),
                        const SizedBox(height: 24),
                        _transactionsSection(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text("Retry")),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _dark
              ? [const Color(0xFF8B0000), const Color(0xFFDC2626)]
              : [CustomerColors.primary, const Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CustomerColors.primary.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            "Wallet Balance",
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            "₦${NumberFormat('#,##0.00').format(_balance ?? 0)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "Available for checkout",
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Transaction History",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _dark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        if (_transactions.isEmpty)
          _emptyTransactions()
        else
          ..._transactions.map(_transactionTile),
      ],
    );
  }

  Widget _emptyTransactions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            "No transactions yet",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            "Refunds from cancelled orders will appear here",
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _transactionTile(Map<String, dynamic> txn) {
    final isCredit = txn['type'] == 'credit';
    final amount = ((txn['amount'] ?? 0) as num).toDouble();
    final desc = txn['description'] ?? (isCredit ? 'Refund' : 'Payment');
    final dateStr = txn['createdAt'] as String?;
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCredit
                  ? Colors.green.withOpacity(0.12)
                  : CustomerColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isCredit ? Colors.green : CustomerColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _dark ? Colors.white : Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (date != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM d, yyyy • h:mm a').format(date),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),
          Text(
            "${isCredit ? '+' : '-'}₦${NumberFormat('#,##0.00').format(amount)}",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isCredit ? Colors.green : CustomerColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}