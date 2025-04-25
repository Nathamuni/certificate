import 'package:certificate_app/screens/home_screen.dart'; // Import home for navigation
import 'package:certificate_app/screens/signup_screen.dart'; // Import signup screen
import 'package:certificate_app/screens/local_password_reset_page.dart'; // Import local password reset page
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    // Check if the widget is still mounted before proceeding
    if (!mounted) return;

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final username = _usernameController.text.trim();
        final password = _passwordController.text.trim();

        // 1. Call the RPC function to get the email associated with the username
        final rpcResponse = await Supabase.instance.client.rpc(
          'login_with_username',
          params: {
            'p_username': username,
            'p_password': password,
          }, // Pass username and password
        );

        // Check if the widget is still mounted after await
        if (!mounted) return;

        // Check if the RPC call returned an error
        if (rpcResponse['error'] != null) {
          throw Exception(rpcResponse['error']); // Throw error message from RPC
        }

        // Extract the email from the RPC response
        final email = rpcResponse['email'] as String?;

        if (email == null) {
          // This case should ideally be caught by the RPC error check, but handle defensively
          throw Exception('Could not retrieve email for username.');
        }

        // 2. Attempt sign-in using the retrieved email and the provided password
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );

        // Check if the widget is still mounted after await
        if (!mounted) return;

        // 2.5 Fetch Profile and Check Approval
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          // Should not happen after successful signIn, but handle defensively
          throw Exception('User not found after sign in.');
        }

        final profileResponse =
            await Supabase.instance.client
                .from('profiles')
                .select(
                  'is_approved, is_admin',
                ) // Select both is_approved and is_admin
                .eq('id', user.id) // Match the authenticated user's ID
                .single(); // Expect exactly one profile per user

        final isApproved = profileResponse['is_approved'] as bool?;
        final isAdmin = profileResponse['is_admin'] as bool?;

        if (isApproved == null || !isApproved) {
          // If is_approved is null (shouldn't happen with default value) or false, deny login
          await Supabase.instance.client.auth.signOut(); // Sign out the user
          if (mounted) {
            // Check mounted again before showing SnackBar
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Login failed: Account not approved by admin.',
                ), // Updated message
                backgroundColor: Colors.orange,
              ),
            );
          }
          // Do NOT navigate forward
          return; // Stop execution here
        }

        // --- Check for users awaiting approval (if admin) ---
        if (isApproved == true && isAdmin == true) {
          try {
            // Corrected query to get pending users
            final pendingUsersResponse = await Supabase.instance.client
                .from('profiles')
                .select('id') // Select any column, 'id' is fine
                .eq('is_approved', false); // Filter by approval status

            // Check if the widget is still mounted after await
            if (!mounted) return;

            // Get count from the length of the returned list
            final pendingCount = pendingUsersResponse.length;

            if (pendingCount > 0 && mounted) {
              // Check if count is greater than 0
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$pendingCount user(s) awaiting approval.',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.blue, // Informational color
                  action: SnackBarAction(
                    label: 'VIEW',
                    textColor: Colors.white,
                    onPressed: () {
                      // TODO: Navigate to the approval screen
                      // Navigator.push(context, MaterialPageRoute(builder: (context) => ApproveUsersScreen()));
                      print("Navigate to approval screen - TO BE IMPLEMENTED");
                    },
                  ),
                ),
              );
            }
          } catch (e) {
            // Log error but don't block login for this notification failure
            print("Error checking for pending users: $e");
          }
        }
        // --- End check for pending users ---

        // 3. Navigate on success (only if approved)
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } on AuthException catch (e) {
        // Catch Supabase Auth specific errors
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Login Failed: ${e.message}')));
        }
      } catch (e) {
        // Catch other errors (like from RPC call Exception)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Login Error: ${e.toString().replaceFirst("Exception: ", "")}',
              ),
            ), // Display general errors
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
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Forgot Password Dialog Logic ---
  Future<void> _showForgotPasswordDialog() async {
    if (!mounted) return;

    // Directly navigate to the local password reset page (no dialog, no Supabase, no email)
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => LocalPasswordResetPage()));
  }
  // --- End Forgot Password ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
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
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                      onPressed: _signIn,
                      child: const Text('Login'),
                    ),
                TextButton(
                  onPressed: () {
                    // Navigate to Sign Up Screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignUpScreen(),
                      ),
                    );
                  },
                  child: const Text('Don\'t have an account? Sign Up'),
                ),
                // Add Forgot Password Button
                TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text('Forgot Password?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
