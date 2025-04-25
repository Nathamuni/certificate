import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApproveUsersScreen extends StatefulWidget {
  const ApproveUsersScreen({super.key});

  @override
  State<ApproveUsersScreen> createState() => _ApproveUsersScreenState();
}

class _ApproveUsersScreenState extends State<ApproveUsersScreen> {
  List<dynamic> _pendingUsers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPendingUsers();
  }

  Future<void> _fetchPendingUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Fetch users where is_approved is false
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, username, email') // Select relevant info
          .eq('is_approved', false) // Corrected filter
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _pendingUsers = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching pending users: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load users: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveUser(String userId) async {
    // Optional: Show confirmation dialog
    bool confirm =
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Confirm Approval'),
                content: const Text(
                  'Are you sure you want to approve this user?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Approve'),
                  ),
                ],
              ),
        ) ??
        false; // Default to false if dialog dismissed

    if (!confirm) return;

    try {
      // Correctly update is_approved to true, ensure is_admin is false
      await Supabase.instance.client
          .from('profiles')
          .update({
            'is_approved': true,
            'is_admin':
                false, // Explicitly ensure they are not admin on approval
          })
          .eq('id', userId); // Match the user ID

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchPendingUsers(); // Refresh the list
      }
    } catch (e) {
      print('Error approving user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve user: ${e.toString()}')),
        );
      }
    }
  }

  // --- Reject User Function ---
  Future<void> _rejectUser(String userId, String username) async {
    // Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Rejection'),
          content: Text(
            'Are you sure you want to reject and delete user "$username"? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Reject & Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return; // User cancelled

    // Show loading indicator (optional)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Call the Supabase Edge Function to delete the user
      final response = await Supabase.instance.client.functions.invoke(
        'delete-user', // The name of your deployed Edge Function
        body: {'userId': userId},
      );

      if (mounted) Navigator.of(context).pop(); // Close loading dialog

      if (response.status != 200) {
        // Handle function invocation error
        final errorData = response.data;
        final errorMessage =
            errorData?['error'] ?? 'Unknown error calling delete function.';
        print(
          'Error calling delete-user function: Status ${response.status}, Error: $errorMessage',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject user: $errorMessage')),
        );
      } else {
        // Success
        print('Successfully called delete-user function for user: $userId');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User "$username" rejected and deleted successfully.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        _fetchPendingUsers(); // Refresh list
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Close loading dialog
      print('Error invoking delete-user function: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject user: ${e.toString()}')),
      );
    }
  }
  // --- End Reject User Function ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Approve New Users')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text('Error: $_error'))
              : _pendingUsers.isEmpty
              ? const Center(child: Text('No users pending approval.'))
              : RefreshIndicator(
                // Add pull-to-refresh
                onRefresh: _fetchPendingUsers,
                child: ListView.builder(
                  itemCount: _pendingUsers.length,
                  itemBuilder: (context, index) {
                    final user = _pendingUsers[index];
                    final userId = user['id'] as String;
                    final username = user['username'] as String? ?? 'N/A';
                    final email = user['email'] as String? ?? 'N/A';

                    return ListTile(
                      title: Text(username),
                      subtitle: Text(email),
                      trailing: Row(
                        // Use Row for multiple buttons
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            // Use TextButton for smaller size
                            onPressed: () => _approveUser(userId),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.green, // Text color
                            ),
                            child: const Text(
                              'Approve',
                              style: TextStyle(fontSize: 14), // Smaller text
                            ),
                          ),
                          const SizedBox(width: 8), // Spacing
                          TextButton(
                            // Use TextButton for smaller size
                            onPressed:
                                () => _rejectUser(
                                  userId,
                                  username,
                                ), // Call reject function
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red, // Text color
                            ),
                            child: const Text(
                              'Reject',
                              style: TextStyle(fontSize: 14), // Smaller text
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
