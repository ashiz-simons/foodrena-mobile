import 'package:flutter/material.dart';
import '../../services/rider_wallet_service.dart';

class RiderWalletScreen extends StatefulWidget {
  const RiderWalletScreen({super.key});

  @override
  State<RiderWalletScreen> createState() => _RiderWalletScreenState();
}

class _RiderWalletScreenState extends State<RiderWalletScreen> {
  double balance = 0;
  bool loading = true;
  bool withdrawing = false;

  List withdrawals = [];

  final amountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadWallet();
  }

  Future<void> loadWallet() async {
    setState(() => loading = true);

    try {
      final wallet = await RiderWalletService.getWallet();
      final history = await RiderWalletService.getWithdrawals();

      setState(() {
        balance = (wallet["balance"] ?? 0).toDouble();
        withdrawals = history;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load wallet")),
      );
    }
  }

  Future<void> withdraw() async {
    final amount = double.tryParse(amountCtrl.text);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid amount")),
      );
      return;
    }

    if (amount > balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Insufficient balance")),
      );
      return;
    }

    setState(() => withdrawing = true);

    try {
      await RiderWalletService.withdraw(amount);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Withdrawal successful")),
      );

      amountCtrl.clear();
      await loadWallet();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Withdrawal failed")),
      );
    } finally {
      setState(() => withdrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Wallet")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadWallet,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // BALANCE CARD
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Available Balance",
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "₦${balance.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // WITHDRAW SECTION
                  const Text(
                    "Withdraw Earnings",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Amount",
                      prefixText: "₦",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: withdrawing ? null : withdraw,
                      child: withdrawing
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text("Withdraw Now"),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // HISTORY
                  const Text(
                    "Withdrawal History",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  if (withdrawals.isEmpty)
                    const Text(
                      "No withdrawals yet",
                      style: TextStyle(color: Colors.grey),
                    ),

                  ...withdrawals.map(
                    (w) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.payments),
                        title: Text("₦${w["amount"]}"),
                        subtitle: Text(
                          (w["status"] ?? "completed").toString().toUpperCase(),
                        ),
                        trailing: Text(
                          w["createdAt"]
                              .toString()
                              .substring(0, 10),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
