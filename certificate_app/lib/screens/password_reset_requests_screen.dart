import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PasswordResetRequestsScreen extends StatefulWidget {
  const PasswordResetRequestsScreen({Key? key}) : super(key: key);

  @override
  State<PasswordResetRequestsScreen> createState() =>
      _PasswordResetRequestsScreenState();
}

class _PasswordResetRequestsScreenState
    extends State<PasswordResetRequestsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<dynamic> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _loading = true;
    });
    try {
      final data = await supabase
          .from('password_reset_requests')
          .select()
          .eq('status', 'pending')
          .order('requested_at', ascending: true);
      setState(() {
        _requests = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching requests: $e')));
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      // Call your server-side function or admin API to delete user
      final response = await supabase.functions.invoke(
        'delete_user',
        body: {'user_id': userId},
      );
      if (response.data != null && response.data['error'] != null) {
        throw Exception(response.data['error']);
      }
      // Remove request from list
      await supabase
          .from('password_reset_requests')
          .update({'status': 'deleted'})
          .eq('user_id', userId);
      _fetchRequests();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting user: $e')));
    }
  }

  void _navigateToPasswordReset(String userId, String email) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PasswordResetPage(userId: userId, email: email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Reset Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRequests,
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _requests.isEmpty
              ? const Center(child: Text('No pending requests'))
              : ListView.builder(
                itemCount: _requests.length,
                itemBuilder: (context, index) {
                  final request = _requests[index];
                  final userId = request['user_id'] as String;
                  final email = request['email'] as String;
                  final requestedAt = request['requested_at'] as String;
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text(email),
                      subtitle: Text('Requested at: $requestedAt'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.lock_reset),
                            tooltip: 'Reset Password',
                            onPressed:
                                () => _navigateToPasswordReset(userId, email),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            tooltip: 'Delete User',
                            onPressed: () => _deleteUser(userId),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

class PasswordResetPage extends StatefulWidget {
  final String userId;
  final String email;

  const PasswordResetPage({Key? key, required this.userId, required this.email})
    : super(key: key);

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

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
      // Call your server-side function or admin API to update password
      final response = await Supabase.instance.client.functions.invoke(
        'reset_user_password',
        body: {
          'user_id': widget.userId,
          'new_password': _passwordController.text,
        },
      );
      if (response.data != null && response.data['error'] != null) {
        throw Exception(response.data['error']);
      }

      // Update request status to handled
      await Supabase.instance.client
          .from('password_reset_requests')
          .update({'status': 'handled'})
          .eq('user_id', widget.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error resetting password: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset User Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text('Reset password for: ${widget.email}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
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
                  labelText: 'Confirm New Password',
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm the new password';
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
