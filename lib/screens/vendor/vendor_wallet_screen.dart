import 'package:flutter/material.dart';
import '../../services/vendor_wallet_service.dart';
import '../vendor/vendor_bank_screen.dart';

class VendorWalletScreen extends StatefulWidget {
  const VendorWalletScreen({super.key});

  @override
  State<VendorWalletScreen> createState() => _VendorWalletScreenState();
}

class _VendorWalletScreenState extends State<VendorWalletScreen> {
  bool loading = true;
  Map wallet = {};
  List withdrawals = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    wallet = await VendorWalletService.getWallet();
    withdrawals = await VendorWalletService.getWithdrawals();
    setState(() => loading = false);
  }

  Future<void> withdraw() async {
    await VendorWalletService.withdraw(wallet["balance"].toDouble());
    await load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Wallet"),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BALANCE
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Available Balance"),
                    const SizedBox(height: 10),
                    Text(
                      "₦${wallet["balance"]}",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed:
                          wallet["balance"] >= 500 ? withdraw : null,
                      child: const Text("Withdraw"),
                    ),
                    const SizedBox(height: 8),

                        OutlinedButton(
                        onPressed: () {
                            Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const VendorBankScreen(),
                            ),
                            );
                        },
                        child: const Text("Bank Details"),
                        ),

                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text("Withdrawal History"),

            const SizedBox(height: 12),

            Expanded(
              child: withdrawals.isEmpty
                  ? const Center(child: Text("No withdrawals yet"))
                  : ListView.builder(
                      itemCount: withdrawals.length,
                      itemBuilder: (_, i) {
                        final w = withdrawals[i];

                        return ListTile(
                          title: Text("₦${w["amount"]}"),
                          subtitle: Text(w["status"]),
                          trailing: Text(
                            w["createdAt"]
                                .toString()
                                .substring(0, 10),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
