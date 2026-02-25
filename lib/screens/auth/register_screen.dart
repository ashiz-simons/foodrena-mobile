import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/session.dart';
import '../../core/role_router.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  String role = "customer";
  bool loading = false;
  String error = "";

  Future<void> register() async {
    setState(() {
      loading = true;
      error = "";
    });

    final res = await ApiService.post("/auth/register", {
      "name": nameCtrl.text.trim(),
      "email": emailCtrl.text.trim(),
      "password": passwordCtrl.text.trim(),
      "role": role,
    });

    setState(() => loading = false);

    if (!res["success"]) {
      setState(() => error = res["message"]);
      return;
    }

    // Save token only if backend returned it (admins don’t get token)
    if (res["token"] != null) {
      await Session.saveToken(res["token"]);
    }

    await Session.saveUser(res["user"]);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RoleRouter()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Full Name"),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField(
              value: role,
              decoration: const InputDecoration(labelText: "Select Role"),
              items: const [
                DropdownMenuItem(value: "customer", child: Text("Customer")),
                DropdownMenuItem(value: "rider", child: Text("Rider")),
                DropdownMenuItem(value: "vendor", child: Text("Vendor")),
              ],
              onChanged: (value) => setState(() => role = value!),
            ),

            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error, style: const TextStyle(color: Colors.red)),
              ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : register,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Register"),
            ),
          ],
        ),
      ),
    );
  }
}
