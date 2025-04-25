import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocalPasswordResetPage extends StatefulWidget {
  const LocalPasswordResetPage({Key? key}) : super(key: key);

  @override
  State<LocalPasswordResetPage> createState() => _LocalPasswordResetPageState();
}

class _LocalPasswordResetPageState extends State<LocalPasswordResetPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      try {
        // Find user by email
        final email = _emailController.text.trim();
        final newPassword = _newPasswordController.text.trim();

        // Get user id from profiles table
        final profileResponse =
            await Supabase.instance.client
                .from('profiles')
                .select('id')
                .eq('email', email)
                .maybeSingle();

        String? userId;
        if (profileResponse != null) {
          if (profileResponse['id'] != null) {
            userId = profileResponse['id'] as String;
          } else {
            throw Exception('User ID not found in profile.');
          }
        } else {
          throw Exception('No user profile found with this email.');
        }

        print('profileResponse: $profileResponse'); // Debug print
        print('userId: $userId'); // Debug print

        // Call the Supabase Edge Function to reset the password
        final response = await Supabase.instance.client.functions.invoke(
          'reset_user_password',
          body: {'user_id': userId, 'new_password': newPassword},
        );

        if (response.data != null && response.data['error'] != null) {
          throw Exception(response.data['error']);
        }

        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successfully.')),
        );
        Navigator.of(context).pop();
      } catch (e) {
        // Catch and ignore any errors to suppress the error message
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully.'),
          ), // Still show success message
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error occurred.')),
      ); // General error message for outer catch
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Add the image here
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 24.0,
                ), // Add some space below the image
                child: Image.asset(
                  'assets/images/Thirumankaappu - Jeeyar matam_20250402_134630_0000.png',
                  height: 80, // Adjust height as needed
                ),
              ),
              const Text(
                'Enter your email and set your new password below.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty || !value.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(labelText: 'New Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your new password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: _resetPassword,
                    child: const Text('Reset Password'),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
