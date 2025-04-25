import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:certificate_app/screens/home_screen.dart'; // Import HomeScreen
import 'package:certificate_app/screens/login_screen.dart'; // Import LoginScreen

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Add is_approved to the select query
      final response = await Supabase.instance.client
          .from('profiles')
          .select(
            'id, username, email, is_admin, is_approved',
          ) // Added is_approved
          .order('username', ascending: true);

      if (mounted) {
        setState(() {
          _users = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching users: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error fetching users: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  // --- Toggle Approval Function ---
  Future<void> _toggleApproval(
    String userId,
    String username,
    bool currentStatus,
  ) async {
    final newStatus = !currentStatus;
    final confirm = await _showConfirmationDialog(
      context,
      newStatus ? 'Approve User' : 'Disapprove User',
      'Are you sure you want to ${newStatus ? 'approve' : 'disapprove'} user "$username"?',
      () {}, // Callback not needed here as we use the bool return
      confirmText: newStatus ? 'Approve' : 'Disapprove',
    );

    if (!confirm) return;

    _showLoadingDialog(
      newStatus ? 'Approving user...' : 'Disapproving user...',
    );

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'is_approved': newStatus})
          .eq('id', userId);

      if (mounted) Navigator.of(context).pop(); // Close loading dialog

      _showSuccessSnackBar(
        'User "$username" ${newStatus ? 'approved' : 'disapproved'} successfully.',
      );
      _fetchUsers(); // Refresh list
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Close loading dialog on error
      print('Error toggling approval: $e');
      _showErrorSnackBar('Failed to update approval status: ${e.toString()}');
    }
  }
  // --- End Toggle Approval Function ---

  Future<void> _promoteUser(String userId, String username) async {
    // Implement permission check
    if (_currentUserId == null) {
      // User is not logged in, redirect to login screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to perform this action.'),
          ),
        );
      }
      return;
    }

    // Check if the current user is an admin
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      // User is not logged in, redirect to login screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to perform this action.'),
          ),
        );
      }
      return;
    }

    final profileResponse =
        await Supabase.instance.client
            .from('profiles')
            .select('is_admin')
            .eq('id', currentUser.id)
            .single();

    final isAdmin = profileResponse['is_admin'] as bool?;

    if (isAdmin == null || !isAdmin) {
      // If the user is not an admin, show an error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not have permission to promote users.'),
          ),
        );
      }
      return;
    }

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'is_admin': true})
          .eq('id', userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User "$username" promoted to admin.'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to promote user: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _demoteUser(String userId, String username) async {
    // Implement permission check
    if (_currentUserId == null) {
      // User is not logged in, redirect to login screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to perform this action.'),
          ),
        );
      }
      return;
    }

    // Check if the current user is an admin
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      // User is not logged in, redirect to login screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to perform this action.'),
          ),
        );
      }
      return;
    }

    final profileResponse =
        await Supabase.instance.client
            .from('profiles')
            .select('is_admin')
            .eq('id', currentUser.id)
            .single();

    final isAdmin = profileResponse['is_admin'] as bool?;

    if (isAdmin == null || !isAdmin) {
      // If the user is not an admin, show an error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not have permission to demote users.'),
          ),
        );
      }
      return;
    }

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'is_admin': false})
          .eq('id', userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User "$username" demoted from admin.'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to demote user: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- Delete User Function ---
  Future<void> _deleteUser(String userId, String username) async {
    // Permission check (redundant due to FutureBuilder, but good practice)
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null || _currentUserId == null) {
      _showErrorSnackBar('You must be logged in.');
      return;
    }
    // Prevent self-deletion
    if (userId == _currentUserId) {
      _showErrorSnackBar('You cannot delete your own account.');
      return;
    }

    // Confirm deletion using the modified dialog
    final confirm = await _showConfirmationDialog(
      context,
      'Confirm Deletion',
      'Are you sure you want to permanently delete the user "$username"? This action cannot be undone.',
      () {}, // Provide an empty callback as it's handled by the bool return
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (!confirm) return; // Exit if user cancelled

    _showLoadingDialog('Deleting user...');

    try {
      // 1. Delete from Supabase Auth (Requires Admin privileges on the client or an RPC)
      // Ensure your Supabase client has admin rights or use a secure RPC function.
      await Supabase.instance.client.auth.admin.deleteUser(userId);
      print('Successfully deleted user from Auth: $userId');

      // 2. Delete from profiles table (Optional, depends on cascade/triggers)
      // RLS might prevent this unless specifically allowed.
      try {
        await Supabase.instance.client
            .from('profiles')
            .delete()
            .eq('id', userId);
        print('Successfully deleted user profile: $userId');
      } catch (profileError) {
        print(
          'Warning: Deleted user from Auth but failed to delete profile row (might be RLS or already deleted): $profileError',
        );
      }

      if (mounted) Navigator.of(context).pop(); // Close loading dialog

      _showSuccessSnackBar('User "$username" deleted successfully.');
      _fetchUsers(); // Refresh list
    } on AuthException catch (e) {
      if (mounted) Navigator.of(context).pop(); // Close loading dialog on error
      print('Error deleting user from Auth: ${e.message}');
      _showErrorSnackBar('Auth Error: ${e.message}');
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Close loading dialog on error
      print('Error deleting user: $e');
      _showErrorSnackBar('Failed to delete user: ${e.toString()}');
    }
  }

  // --- Helper Functions for UI ---
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showLoadingDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(message),
            ],
          ),
        );
      },
    );
  }
  // --- End Helper Functions ---

  // --- Confirmation Dialog (Modified) ---
  Future<bool> _showConfirmationDialog(
    // Changed return type to bool
    BuildContext context,
    String title,
    String content,
    VoidCallback
    onConfirm, { // Made onConfirm required again for promote/demote
    String confirmText = 'Confirm', // Default confirm text
    bool isDestructive = false, // Flag for destructive actions
  }) async {
    final result = await showDialog<bool>(
      // Expect a boolean result
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(children: <Widget>[Text(content)]),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false); // Return false on cancel
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    isDestructive ? Colors.red : null, // Destructive color
              ),
              child: Text(confirmText), // Use dynamic confirm text
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // Return true on confirm
                // Execute the original callback AFTER popping the dialog
                // This is needed for promote/demote which don't expect a bool return
                // For delete, we'll use the bool return value directly.
                onConfirm();
              },
            ),
          ],
        );
      },
    );
    // Return the dialog result (true if confirmed, false if cancelled/dismissed)
    // Default to false if dialog is dismissed somehow without button press
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      // User is not logged in, redirect to login screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ); // Added return
    }
    // Check if the current user is an admin (this check seems redundant now,
    // as it's handled by the FutureBuilder, but keeping for safety/clarity)
    // We rely on the FutureBuilder below to handle the admin check and redirection.

    return FutureBuilder<List<dynamic>>(
      future: Supabase.instance.client
          .from('profiles')
          .select('is_admin')
          .eq('id', currentUser!.id) // Use null assertion operator (!)
          .limit(1),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          // If there's an error or no profile found, redirect to home
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Check mounted before navigation
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            }
          });
          return const Scaffold(
            body: Center(child: Text('Error loading admin status.')),
          );
        }

        final isAdminFromDb =
            snapshot.data!.first['is_admin'] as bool? ?? false;

        if (!isAdminFromDb) {
          // If the user is not an admin, redirect to home screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Check mounted before navigation
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            }
          });
          return const Scaffold(
            body: Center(
              child: Text('You do not have permission to view this page.'),
            ),
          );
        }

        // If the user is an admin, build the main content
        return Scaffold(
          appBar: AppBar(title: const Text('Admin Management')),
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
                  : _users.isEmpty
                  ? const Center(child: Text('No users found.'))
                  : RefreshIndicator(
                    // Added RefreshIndicator
                    onRefresh:
                        _fetchUsers, // Call _fetchUsers on pull-to-refresh
                    child: ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final userId = user['id'] as String? ?? '';
                        final username = user['username'] as String? ?? 'N/A';
                        final email = user['email'] as String? ?? 'N/A';
                        final isAdminUser = user['is_admin'] as bool? ?? false;
                        final isApproved =
                            user['is_approved'] as bool? ??
                            false; // Get is_approved status
                        final isCurrentUser = userId == _currentUserId;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          child: ListTile(
                            leading: Icon(
                              isAdminUser // Use the user's admin status
                                  ? Icons.admin_panel_settings_sharp
                                  : Icons.person,
                              color:
                                  isCurrentUser
                                      ? Theme.of(context)
                                          .primaryColor // Use theme color
                                      : isAdminUser
                                      ? Colors.orange
                                      : null, // Highlight admins
                            ),
                            title: Text(
                              username + (isCurrentUser ? ' (You)' : ''),
                              style: TextStyle(
                                fontWeight:
                                    isCurrentUser
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                            // Updated subtitle to include Approval status
                            subtitle: Text(
                              '$email\nApproved: ${isApproved ? 'Yes' : 'No'}',
                            ),
                            isThreeLine: true, // Allow more space for subtitle
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // --- Approve/Disapprove Button ---
                                if (!isCurrentUser)
                                  IconButton(
                                    icon: Icon(
                                      isApproved
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color:
                                          isApproved
                                              ? Colors.green
                                              : Colors.grey,
                                    ),
                                    tooltip:
                                        isApproved
                                            ? 'Disapprove User'
                                            : 'Approve User',
                                    onPressed:
                                        () => _toggleApproval(
                                          userId,
                                          username,
                                          isApproved,
                                        ),
                                  ),
                                // --- End Approve/Disapprove Button ---

                                // --- Promote/Demote Button (Updated Icons) ---
                                if (!isCurrentUser)
                                  IconButton(
                                    icon: Icon(
                                      isAdminUser
                                          ? Icons
                                              .arrow_downward // Demote icon
                                          : Icons.arrow_upward, // Promote icon
                                      color:
                                          isAdminUser
                                              ? Colors.orange
                                              : Colors.blue,
                                    ),
                                    tooltip:
                                        isAdminUser
                                            ? 'Demote to User'
                                            : 'Promote to Admin',
                                    onPressed:
                                        () =>
                                            isAdminUser
                                                ? _showConfirmationDialog(
                                                  context,
                                                  'Demote Admin',
                                                  'Are you sure you want to remove admin privileges for "$username"?',
                                                  () => _demoteUser(
                                                    userId,
                                                    username,
                                                  ),
                                                  confirmText: 'Demote',
                                                  isDestructive:
                                                      true, // Use orange/red style
                                                )
                                                : _showConfirmationDialog(
                                                  context,
                                                  'Make Admin',
                                                  'Are you sure you want to grant admin privileges to "$username"?',
                                                  () => _promoteUser(
                                                    userId,
                                                    username,
                                                  ),
                                                  confirmText: 'Promote',
                                                ),
                                  ),
                                // --- End Promote/Demote Button ---

                                // --- Delete Button (No change needed) ---
                                if (!isCurrentUser)
                                  IconButton(
                                    icon: const Icon(Icons.delete_forever),
                                    color: Colors.red[800],
                                    tooltip: 'Delete User',
                                    onPressed:
                                        () => _deleteUser(userId, username),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
        );
      },
    ); // Missing closing brace was here for FutureBuilder
  } // Closing brace for build method
} // End of _AdminManagementScreenState class
