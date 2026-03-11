import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/session.dart';
import 'register_screen.dart';
import 'role_selection_screen.dart';
import 'phone_auth_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLogin;
  const LoginScreen({super.key, this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Toggle between phone and email login
  bool _usePhone = true;

  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  bool loading = false;
  bool _obscurePassword = true;
  String error = "";

  @override
  void dispose() {
    phoneCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() { loading = true; error = ""; });

    try {
      final Map<String, dynamic> body = {
        "password": passwordCtrl.text.trim(),
      };

      if (_usePhone) {
        final phone = phoneCtrl.text.trim();
        if (phone.isEmpty) throw Exception("Enter your phone number");
        body["phone"] = phone.startsWith('+')
            ? phone
            : '+234${phone.replaceFirst(RegExp(r'^0'), '')}';
      } else {
        final email = emailCtrl.text.trim();
        if (email.isEmpty) throw Exception("Enter your email");
        body["email"] = email;
      }

      final res = await ApiService.post("/auth/login", body);

      if (!mounted) return;
      setState(() => loading = false);

      if (res["token"] == null) {
        setState(() => error = res["message"] ?? "Login failed");
        return;
      }

      await Session.saveToken(res["token"]);
      await Session.saveUser(res["user"] ?? {});
      if (res["rider"] != null) await Session.saveRiderProfile(res["rider"]);

      widget.onLogin?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString().replaceAll("Exception: ", "");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFDC2626);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sign In"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Welcome back",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text("Sign in to your Foodrena account",
                style: TextStyle(color: Colors.grey, fontSize: 14)),

            const SizedBox(height: 28),

            // Toggle phone / email
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(child: _toggleBtn("Phone", Icons.phone_outlined, _usePhone,
                      () => setState(() { _usePhone = true; error = ""; }))),
                  Expanded(child: _toggleBtn("Email", Icons.email_outlined, !_usePhone,
                      () => setState(() { _usePhone = false; error = ""; }))),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Input field
            if (_usePhone)
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  hintText: "08012345678",
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: red, width: 1.5),
                  ),
                ),
              )
            else
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: red, width: 1.5),
                  ),
                ),
              ),

            const SizedBox(height: 14),

            TextField(
              controller: passwordCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: "Password",
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined, size: 20),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: red, width: 1.5),
                ),
              ),
            ),

            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(error,
                        style: const TextStyle(color: Colors.red, fontSize: 13))),
                  ]),
                ),
              ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: loading ? null : login,
                child: loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Sign In",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 16),

            Center(
              child: TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => RoleSelectionScreen(onLogin: widget.onLogin))),
                child: RichText(
                  text: const TextSpan(
                    text: "Don't have an account? ",
                    style: TextStyle(color: Colors.grey),
                    children: [
                      TextSpan(
                        text: "Create one",
                        style: TextStyle(color: red, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleBtn(String label, IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16,
                color: active ? const Color(0xFFDC2626) : Colors.grey),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    color: active ? const Color(0xFFDC2626) : Colors.grey)),
          ],
        ),
      ),
    );
  }
}