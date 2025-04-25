import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViewAdminsScreen extends StatefulWidget {
  const ViewAdminsScreen({super.key});

  @override
  State<ViewAdminsScreen> createState() => _ViewAdminsScreenState();
}

class _ViewAdminsScreenState extends State<ViewAdminsScreen> {
  List<dynamic> _admins = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentUserId; // Store the current user's ID

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _fetchAdmins();
  }

  Future<void> _fetchAdmins() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch ID along with other details
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, username, email') // Select ID, username, email
          .eq('is_admin', true) // Filter for admins
          .order('username', ascending: true);

      if (mounted) {
        setState(() {
          _admins = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching admins: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error fetching admins: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  // --- Demote Admin Function ---
  Future<void> _demoteAdmin(String userId, String username) async {
    // Prevent self-demotion
    if (userId == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot demote yourself.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Demotion'),
          content: Text(
            'Are you sure you want to remove admin privileges for "$username"?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
              ), // Use orange for demote
              child: const Text('Demote'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm != true) return; // User cancelled

    setState(() => _isLoading = true); // Show loading

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'is_admin': false}) // Set is_admin to false
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User "$username" demoted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchAdmins(); // Refresh the list
      }
    } catch (e) {
      print('Error demoting admin $userId: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error demoting admin "$username": ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false); // Hide loading on error
      }
    }
    // No finally needed, _fetchAdmins handles loading state on success
  }
  // --- End Demote Admin Function ---

  // --- Delete User Logic ---
  Future<void> _confirmDeleteUser(String userId, String username) async {
    // Double-check self-deletion attempt (should be caught by button state, but good practice)
    if (userId == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot delete your own account.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
            'Are you sure you want to permanently delete the user "$username" ($userId)? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('DELETE'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _deleteUser(userId, username);
    }
  }

  Future<void> _deleteUser(String userId, String username) async {
    setState(() => _isLoading = true); // Show loading indicator

    try {
      // IMPORTANT: Call a secure Supabase Edge Function or RPC function
      // This function MUST run with elevated privileges (service_role) on the backend
      // to delete users from auth.users and handle related data cleanup.
      print('Invoking edge function to delete user: $userId');
      await Supabase.instance.client.functions.invoke(
        'delete_user_by_admin', // Ensure this Edge Function exists and is configured correctly
        body: {'user_id_to_delete': userId},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User "$username" deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchAdmins(); // Refresh the list
      }
    } catch (e) {
      print('Error deleting user $userId: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting user "$username": ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false); // Hide loading indicator on error
      }
    }
    // No finally block needed for isLoading, as _fetchAdmins will handle it on success.
  }

  // --- End Delete User Logic ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administrators')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
              : _admins.isEmpty
              ? const Center(child: Text('No administrators found.'))
              : ListView.builder(
                itemCount: _admins.length,
                itemBuilder: (context, index) {
                  final admin = _admins[index];
                  final userId =
                      admin['id'] as String? ?? ''; // Get the user ID
                  final username = admin['username'] as String? ?? 'N/A';
                  final email = admin['email'] as String? ?? 'N/A';
                  final isCurrentUser =
                      userId ==
                      _currentUserId; // Check if it's the logged-in admin

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.admin_panel_settings,
                        color:
                            isCurrentUser
                                ? Colors.blue
                                : null, // Highlight current user
                      ),
                      title: Text(
                        username + (isCurrentUser ? ' (You)' : ''),
                      ), // Indicate current user
                      subtitle: Text(email),
                      trailing: Row(
                        // Use Row for multiple buttons
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Demote Button
                          IconButton(
                            icon: Icon(
                              Icons.arrow_downward, // Demote icon
                              color:
                                  isCurrentUser
                                      ? Colors.grey
                                      : Colors.orange, // Disable for self
                            ),
                            tooltip:
                                isCurrentUser
                                    ? 'Cannot demote yourself'
                                    : 'Demote Admin',
                            onPressed:
                                isCurrentUser
                                    ? null
                                    : () => _demoteAdmin(
                                      userId,
                                      username,
                                    ), // Disable for self
                          ),
                          // Delete Button
                          IconButton(
                            icon: Icon(
                              Icons.delete_forever,
                              color:
                                  isCurrentUser
                                      ? Colors.grey
                                      : Colors.red, // Disable delete for self
                            ),
                            tooltip:
                                isCurrentUser
                                    ? 'Cannot delete yourself'
                                    : 'Delete User',
                            onPressed:
                                isCurrentUser
                                    ? null
                                    : () => _confirmDeleteUser(
                                      userId,
                                      username,
                                    ), // Disable for self
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchAdmins,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
