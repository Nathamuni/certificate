import 'package:flutter/material.dart';

class ForgotPasswordRedirectPage extends StatelessWidget {
  const ForgotPasswordRedirectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Password Reset')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Your password has been reset successfully.\n\nYou may now log in with your new password.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
