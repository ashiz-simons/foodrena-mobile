import 'package:flutter/material.dart';
import '../../services/rider_service.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final controller = TextEditingController();
  bool loading = false;

  Future<void> submit() async {
    final amount = double.tryParse(controller.text);
    if (amount == null || amount <= 0) return;

    setState(() => loading = true);

    try {
      await RiderService.withdraw(amount);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Withdrawal requested")),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Withdrawal failed")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Withdraw Earnings")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Amount",
                prefixText: "₦ ",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : submit,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Submit"),
            )
          ],
        ),
      ),
    );
  }
}
