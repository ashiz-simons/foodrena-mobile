import 'package:flutter/material.dart';
import '../../services/rider_service.dart';

const _kOrange = Color(0xFFFF8C00);

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final controller = TextEditingController();
  bool loading = false;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg   => _dark ? const Color(0xFF1A1208) : const Color(0xFFFFF8F2);
  Color get _card => _dark ? const Color(0xFF2A1E0C) : Colors.white;
  Color get _text => _dark ? Colors.white : const Color(0xFF1A1A1A);
  Color get _muted => _dark ? Colors.grey.shade400 : const Color(0xFF888888);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final amount = double.tryParse(controller.text);
    if (amount == null || amount <= 0) return;
    setState(() => loading = true);
    try {
      await RiderService.withdraw(amount);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Withdrawal requested"), backgroundColor: _kOrange),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Withdrawal failed"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text("Withdraw Earnings", style: TextStyle(color: _text)),
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: IconThemeData(color: _text),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Amount to withdraw",
                style: TextStyle(fontSize: 13, color: _muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 15, color: _text),
              decoration: InputDecoration(
                prefixText: "₦ ",
                prefixStyle: const TextStyle(color: _kOrange, fontWeight: FontWeight.w600),
                hintText: "Enter amount",
                hintStyle: TextStyle(color: _muted, fontSize: 14),
                filled: true,
                fillColor: _card,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: _dark
                      ? BorderSide(color: Colors.grey.shade700)
                      : const BorderSide(color: _kOrange, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kOrange, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: loading ? null : submit,
                child: loading
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Submit",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}