import 'package:flutter/material.dart';
import 'phone_auth_screen.dart';

/// Entry point for authentication. Immediately opens the phone auth
/// flow. The class name is kept as LoginScreen so all existing
/// navigation references (`Navigator.push → LoginScreen()`) continue
/// to work without changes across the codebase.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Navigate directly to phone auth on first build frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await Navigator.pushReplacement<bool, void>(
        context,
        MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
      );
      if (result == true && context.mounted) {
        Navigator.pop(context, true);
      }
    });

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
