import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/session.dart';
import '../../core/role_router.dart';
import 'register_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool loading = false;
  String error = "";

  Future<void> login() async {
    setState(() {
      loading = true;
      error = "";
    });

    final res = await ApiService.post("/auth/login", {
      "email": emailCtrl.text.trim(),
      "password": passwordCtrl.text.trim(),
    });

    setState(() => loading = false);

    if (res["token"] == null) {
      setState(() => error = res["message"] ?? "Login failed");
      return;
    }

    print("TOKEN SAVED");
    print("USER SAVED => ${res["user"]}");

    await Session.saveToken(res["token"]);

      // Always save base user
      await Session.saveUser({
        ...res["user"],
        if (res["rider"] != null) "riderProfile": res["rider"]
      });

      final user = await Session.getUser();
      print("🧠 FINAL SESSION => $user");

      final riderId = user?["riderProfile"]?["id"];
      print("✅ SAVED RIDER ID => $riderId");

    // Debug log
    print("USER SAVED => ${res["user"]}");


    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => RoleRouter()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
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

            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(error, style: const TextStyle(color: Colors.red)),
              ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : login,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Login"),
            ),

            TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                child: const Text("Create an account"),
              ),  
          ],
        ),
      ),
    );
  }
}
