import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.mode,
      // Each role sets its own theme in its root widget,
      // but we provide a sensible global fallback here.
      theme: customerLightTheme,
      darkTheme: customerDarkTheme,
      home: const SplashScreen(),
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationService.init(context);
        });
        return child!;
      },
    );
  }
}