import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key});

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  List<dynamic> _profiles = [];
  bool _loading = true;
  bool _isAdmin = false; // Track admin status

  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserAdminStatus(); // Fetch admin status first
    _fetchProfiles();
  }

  // Fetch current user's admin status
  Future<void> _fetchCurrentUserAdminStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isAdmin = false);
      return;
    }
    try {
      final response =
          await Supabase.instance.client
              .from('profiles')
              .select('is_admin')
              .eq('id', user.id)
              .single();
      if (mounted) {
        setState(() {
          _isAdmin = response['is_admin'] ?? false;
        });
      }
    } catch (e) {
      print("Error fetching user admin status: $e");
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  Future<void> _fetchProfiles() async {
    setState(() {
      _loading = true;
    });

    var query = Supabase.instance.client
        .from('profiles')
        .select('*, is_admin') // Include is_admin
        .eq('is_approved', true); // Only fetch approved users

    if (_search.isNotEmpty) {
      query = query.or('username.ilike.%$_search%,email.ilike.%$_search%');
    }

    final response = await query.order('created_at', ascending: false);
    setState(() {
      _profiles = response;
      _loading = false;
    });
  }

  // --- Promote User Function ---
  Future<void> _promoteUser(String userId, String username) async {
    // Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Promotion'),
          content: Text(
            'Are you sure you want to grant admin privileges to "$username"?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Promote'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => _loading = true); // Show loading indicator
      try {
        // Update is_admin to true for the selected user
        await Supabase.instance.client
            .from('profiles')
            .update({'is_admin': true})
            .eq('id', userId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User "$username" promoted to admin successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchProfiles(); // Refresh the list
        }
      } catch (e) {
        print('Error promoting user: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error promoting user: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _loading = false); // Hide loading on error
        }
      }
    }
  }
  // --- End Promote User Function ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchProfiles,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by username or email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                _search = value;
                _fetchProfiles();
              },
            ),
          ),
          Expanded(
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          // REMOVED const
                          DataColumn(label: Text('Username')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Created At')),
                          if (_isAdmin)
                            DataColumn(
                              label: Text('Actions'),
                            ), // Add Actions column if admin
                        ],
                        rows:
                            _profiles.map((profile) {
                              final profileId =
                                  profile['id'] as String?; // Get profile ID
                              final userEmail =
                                  profile['email']
                                      as String?; // Get email for safety check
                              final isAdminUser =
                                  profile['is_admin']
                                      as bool?; // Get admin status

                              return DataRow(
                                cells: [
                                  DataCell(Text(profile['username'] ?? '')),
                                  DataCell(Text(userEmail ?? '')),
                                  DataCell(Text(profile['created_at'] ?? '')),
                                  if (_isAdmin) // Add Actions cell if admin
                                    DataCell(
                                      Row(
                                        children: [
                                          // Promote Button (only for non-admins)
                                          if (isAdminUser != true)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.arrow_upward,
                                              ), // Simple arrow
                                              tooltip: 'Promote to Admin',
                                              onPressed:
                                                  () => _promoteUser(
                                                    profileId!,
                                                    profile['username'] ??
                                                        'this user',
                                                  ),
                                            ),
                                          // Delete Button (prevent deleting self)
                                          if (profileId !=
                                              Supabase
                                                  .instance
                                                  .client
                                                  .auth
                                                  .currentUser
                                                  ?.id)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              tooltip: 'Delete Profile',
                                              onPressed:
                                                  profileId == null
                                                      ? null // Disable if ID is missing
                                                      : () => _deleteProfile(
                                                        profileId,
                                                        userEmail ??
                                                            'this user',
                                                      ),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            }).toList(),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  // --- Delete Profile Logic ---
  Future<void> _deleteProfile(String profileId, String userIdentifier) async {
    // Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
            'Are you sure you want to delete the profile for "$userIdentifier"?\n\nNOTE: This only removes the profile data. The user authentication entry might still exist.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => _loading = true); // Show loading indicator

      try {
        // Call the Supabase Edge Function to delete the user
        print('Invoking delete-user function for ID: $profileId');
        final response = await Supabase.instance.client.functions.invoke(
          'delete-user', // The name of your deployed Edge Function
          body: {'userId': profileId},
        );

        if (response.status != 200) {
          // Handle function invocation error
          final errorData = response.data;
          final errorMessage =
              errorData?['error'] ?? 'Unknown error calling delete function.';
          print(
            'Error calling delete-user function: Status ${response.status}, Error: $errorMessage',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete user: $errorMessage')),
            );
          }
        } else {
          // Success
          print(
            'Successfully called delete-user function for user: $profileId',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('User "$userIdentifier" deleted successfully.'),
                backgroundColor: Colors.green,
              ),
            );
            _fetchProfiles(); // Refresh the list after successful deletion
          }
        }
      } catch (e) {
        print('Error invoking delete-user function: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete user: ${e.toString()}')),
          );
        }
      } // End of catch block
      finally {
        // Ensure loading indicator is hidden regardless of outcome,
        // unless _fetchProfiles handles it implicitly on success.
        // Check if _fetchProfiles sets loading to false. If yes, this might be redundant.
        // For safety, let's ensure it's set.
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    }
  }
}
