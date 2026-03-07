import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_gate.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase before anything else
  await Firebase.initializeApp();

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      builder: (context, child) {
        // ✅ Initialize notifications once the widget tree is ready
        // Using builder ensures context is available for navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationService.init(context);
        });
        return child!;
      },
    );
  }
}