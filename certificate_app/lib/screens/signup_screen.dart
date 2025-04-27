import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(); // Added email controller
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final email = _emailController.text.trim(); // Use email controller
        final password = _passwordController.text.trim();
        final username = _usernameController.text.trim(); // Get username

        // Sign up the user, passing username in metadata for the trigger
        final response = await Supabase.instance.client.auth.signUp(
          email: email, // Use the actual email for signup
          password: password,
          data: {'username': username}, // Pass username in metadata
        );

        final userId = response.user?.id;
        // The handle_new_user trigger should insert the profile record,
        // including the email. This update is likely redundant.
        // if (userId != null) {
        //   // Update profiles table with email
        //   await Supabase.instance.client
        //       .from('profiles')
        //       .update({'email': email})
        //       .eq('id', userId);
        // }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sign Up Successful! Check your email for verification (if enabled).',
              ),
            ),
          );
          // Optionally navigate back to login or directly to home after signup
          Navigator.pop(context); // Go back to login screen
        }
      } on AuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sign Up Failed: ${e.message}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An unexpected error occurred: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose(); // Dispose email controller
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
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
                      TextFormField(
                        // Added Email Field
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              !value.contains('@')) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16), // Added spacing
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a username';
                          }
                          // Add more username validation if needed (e.g., length, characters)
                          // Check if username already exists (requires a Supabase query)
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            // Example: Basic password length check
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
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                            onPressed: _signUp,
                            child: const Text('Sign Up'),
                          ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // Go back to Login Screen
                        },
                        child: const Text('Already have an account? Login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 10.0,
                horizontal: 16.0,
              ),
              child: RichText(
                textAlign: TextAlign.center, // Center the text
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 12.0, // Smaller font size for subtlety
                    color: Colors.grey[600], // Lighter text color
                  ),
                  children: const <TextSpan>[
                    TextSpan(
                      text: 'Designed and developed by\n',
                    ), // Add newline for spacing
                    TextSpan(
                      text: 'Nathamuni',
                      style: TextStyle(
                        fontWeight: FontWeight.w500, // Slightly bolder
                        // Optionally increase font size slightly if needed
                        // fontSize: 13.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
