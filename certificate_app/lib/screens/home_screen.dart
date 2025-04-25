import 'dart:typed_data'; // For Uint8List
import 'package:certificate_app/utils/pdf_generator.dart'; // Import PDF generator
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For number input formatting
import 'dart:io'; // For File operations
import 'package:path_provider/path_provider.dart'; // For finding local paths
import 'package:share_plus/share_plus.dart'; // For sharing files
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // For date formatting
// import 'package:url_launcher/url_launcher.dart'; // No longer needed for viewing
import 'package:intl_phone_field/intl_phone_field.dart'; // Import intl_phone_field
import 'package:intl_phone_field/phone_number.dart'; // Import PhoneNumber
import 'pdf_viewer_page.dart'; // Import the viewer page
import 'package:permission_handler/permission_handler.dart'; // Import permission handler
import 'package:media_store_plus/media_store_plus.dart'; // Import media_store_plus
import 'package:flutter/services.dart'; // Import MethodChannel for media scan
import 'package:device_info_plus/device_info_plus.dart'; // Import device info
import 'dart:async'; // Import async for StreamSubscription

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData; // Add optional initial data

  const HomeScreen({
    super.key,
    this.initialData, // Accept initial data
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _purposeController = TextEditingController();
  final _amountController = TextEditingController();
  final _chequeNumberController = TextEditingController();
  final _bankController = TextEditingController(); // Controller for Bank Name
  final _otherRemarksController =
      TextEditingController(); // Controller for Other Remarks
  final _internalRemarksController =
      TextEditingController(); // Controller for Internal Remarks

  String? _selectedTrust;
  String? _selectedOfferingType; // State variable for offering type
  PhoneNumber? _phoneNumber; // Store selected phone number object
  String? _selectedModeOfTransfer;
  bool _showChequeField = false;
  bool _isLoading = false;
  bool _isFetchingDonor = false; // Flag for auto-fill loading
  Uint8List? _generatedPdfBytes; // To store generated PDF bytes
  String? _certificateUrl; // To store the generated PDF URL locally for viewing
  String? _lastGeneratedBillNumber; // Store the last bill number for filenames
  int? _editingCertificateId; // Store the ID of the certificate being edited
  String? _originalFinancialYear; // Store the original FY for PDF path update
  bool _isEditMode = false; // Flag to indicate if editing an existing receipt
  bool _isAdmin = false; // State variable to track admin status
  int _pendingApprovalCount = 0; // State variable for pending user count
  String? _initialPhoneNumberString; // For edit mode prefill
  String? _initialCountryCodeString; // For edit mode prefill
  bool _phoneNumberManuallyChanged =
      false; // Flag to track manual changes in edit mode
  StreamSubscription<AuthState>?
  _authStateSubscription; // Add auth listener subscription
  RealtimeChannel? _profileChannel; // Add profile listener channel

  final List<String> _trustOptions = [
    "PARAMANADI TRUST",
    "NOOLAATTI PALA KALAI ORPPU MAIYAM", // Corrected spelling and case
  ];
  // Updated Mode of Transfer Options
  final List<String> _modeOfTransferOptions = [
    "Payment Gateway", // Added as first option
    "Account Transfer",
    "UPI",
    "Cash",
    "Cheque",
    "Donation In Kind",
  ];
  // Add "Clear Selection" as the first option, represented by null
  final List<String?> _offeringTypeOptions = [
    null, // Represents "Clear Selection"
    'Voluntary Contribution',
    'Corpus Donation',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserProfile().then((_) {
      // Fetch count only if the user is an admin
      if (_isAdmin) {
        _fetchPendingApprovalCount();
      }
      // Start listening to auth state changes AFTER fetching initial profile
      _setupAuthListener();
      // Start listening to profile changes AFTER fetching initial profile
      _setupProfileListener(); // Add this call
    });
    _populateFormIfInitialData(); // Populate form if editing
    _requestStoragePermissionOnStart(); // Request storage permission on app start
  }

  // --- Setup Auth State Listener ---
  void _setupAuthListener() {
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final AuthChangeEvent event = data.event;
        print('HomeScreen Auth Event: $event'); // Log the event

        // Check user validity on relevant events
        if (event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.signedIn || // Check on signedIn as well
            event == AuthChangeEvent.userUpdated) {
          _validateCurrentUserSession();
        }
        // Handle signedOut explicitly if needed (though SplashScreen might cover it)
        else if (event == AuthChangeEvent.signedOut) {
          if (mounted) {
            print("Detected SIGNED_OUT in HomeScreen, navigating to login.");
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (route) => false);
          }
        }
      },
      onError: (error) {
        // Handle listener errors if necessary
        print('Auth listener error: $error');
      },
    );
  }

  // --- Validate Current User Session ---
  Future<void> _validateCurrentUserSession() async {
    print("Validating current user session...");
    try {
      // Attempt to get the current user. If the token is invalid or user deleted, this should fail.
      final userResponse = await Supabase.instance.client.auth.getUser();
      // Access the User object within the UserResponse
      final user = userResponse.user;
      print(
        "User session validated successfully for: ${user?.email ?? 'No email'}",
      ); // Access user.email
      // Optional: You could also check user metadata or roles here if needed
    } on AuthException catch (e) {
      print("AuthException during validation: ${e.message}");
      // Check for specific errors indicating invalid session or user not found
      // Note: Specific error messages/codes might vary slightly. Adjust if needed.
      if (e.message.toLowerCase().contains('invalid session') ||
          e.message.toLowerCase().contains('user not found') ||
          e.statusCode == '401' || // Unauthorized
          e.statusCode == '403') // Forbidden
      {
        print(
          "Forcing logout due to invalid session or user deletion detected.",
        );
        if (mounted) {
          // Clear local session data and navigate to login
          await Supabase.instance.client.auth.signOut();
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } else {
        // Other auth error, log it but might not require immediate logout
        print("Non-critical AuthException during validation: ${e.message}");
      }
    } catch (e) {
      // Catch any other unexpected errors during validation
      print("Unexpected error during user session validation: $e");
      // Decide if a generic error should also trigger logout, maybe not.
    }
  }

  // --- Setup Profile Listener (Using syntax for supabase_flutter v2.x) ---
  void _setupProfileListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return; // Should not happen if in HomeScreen

    print("Setting up profile listener for user ID: ${user.id}");

    // Define the callback function
    final callback = (PostgresChangePayload payload) {
      print('Profile change received: ${payload.eventType}');

      if (payload.eventType == PostgresChangeEvent.update) {
        print('Profile UPDATE received: ${payload.newRecord}');
        final newData = payload.newRecord;
        final isAdmin = newData['is_admin'] as bool? ?? true;
        final isApproved = newData['is_approved'] as bool? ?? true;
        if (!isAdmin || !isApproved) {
          _handleLogout(
            "Profile status changed (Admin: $isAdmin, Approved: $isApproved)",
          );
        }
      } else if (payload.eventType == PostgresChangeEvent.delete) {
        // Since the channel is filtered for this user's ID,
        // any DELETE event received here *is* for this user.
        print(
          'Profile DELETE received for user ${user.id}. Payload: ${payload.oldRecord}',
        );
        _handleLogout("Profile deleted");
      }
    };

    // Subscribe to the channel
    _profileChannel = Supabase.instance.client
        .channel('public:profiles') // Channel for the whole table
        .onPostgresChanges(
          event: PostgresChangeEvent.all, // Listen for UPDATE and DELETE
          schema: 'public',
          table: 'profiles',
          // Filter specifically for the user's ID on the server-side
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: user.id,
          ),
          callback: callback,
        )
        .subscribe((status, [error]) async {
          // Make callback async
          if (status == RealtimeSubscribeStatus.subscribed) {
            print('Profile listener subscribed successfully.');
          } else if (status == RealtimeSubscribeStatus.channelError) {
            print('Profile listener subscription error: $error');
            // Optionally try to resubscribe or show an error
            // Example: Attempt to resubscribe after a delay
            await Future.delayed(const Duration(seconds: 5));
            if (mounted && _profileChannel != null) {
              print('Attempting to resubscribe profile listener...');
              _profileChannel?.subscribe(); // Try subscribing again
            }
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            print('Profile listener subscription timed out.');
            // Optionally try to resubscribe
            await Future.delayed(const Duration(seconds: 5));
            if (mounted && _profileChannel != null) {
              print(
                'Attempting to resubscribe profile listener after timeout...',
              );
              _profileChannel?.subscribe(); // Try subscribing again
            }
          } else {
            print('Profile listener status: $status');
          }
        });
  }

  // --- Helper to handle logout ---
  Future<void> _handleLogout(String reason) async {
    print("Logout triggered: $reason");
    if (mounted) {
      // Unsubscribe immediately to prevent potential duplicate triggers
      await _profileChannel?.unsubscribe();
      _profileChannel = null; // Clear the channel reference

      // Show a message before signing out
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logging out: $reason'),
          backgroundColor: Colors.orange,
        ),
      );
      // Add a small delay for the snackbar to be visible
      await Future.delayed(const Duration(seconds: 1));

      // Perform the sign out
      await Supabase.instance.client.auth.signOut();

      // Navigation is handled by the listener in SplashScreen/main.dart
    } else {
      print("Logout triggered but widget not mounted.");
    }
  }

  // --- Fetch Pending Approval Count ---
  Future<void> _fetchPendingApprovalCount() async {
    // No need to fetch if not admin
    if (!_isAdmin) return;

    try {
      // Count users where is_approved is false
      final response = await Supabase.instance.client
          .from('profiles')
          .count(CountOption.exact) // Use exact count
          .eq('is_approved', false); // Filter by is_approved == false

      if (mounted) {
        setState(() {
          _pendingApprovalCount = response; // The count is directly returned
        });
      }
    } catch (e) {
      print('Error fetching pending approval count: $e');
      if (mounted) {
        // Optionally show an error, but maybe just default to 0
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error fetching user count: ${e.toString()}')),
        // );
        setState(() {
          _pendingApprovalCount = 0; // Default to 0 on error
        });
      }
    }
  }
  // --- End Fetch Pending Approval Count ---

  Future<void> _requestPasswordReset() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to request password reset'),
          ),
        );
      }
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('password_reset_requests')
          .insert({
            'user_id': user.id,
            'email': user.email,
            'status': 'pending',
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset request submitted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit password reset request: $e'),
          ),
        );
      }
    }
  }

  Future<void> _requestStoragePermissionOnStart() async {
    // Only request on Android 12 and below (API 32 and below)
    if (!Platform.isAndroid) return;
    int sdkInt = 30;
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      sdkInt = androidInfo.version.sdkInt;
    } catch (_) {}

    if (sdkInt <= 32) {
      bool permissionGranted = false;
      for (int attempt = 0; attempt < 2; attempt++) {
        final status = await Permission.storage.status;
        if (status.isGranted) {
          permissionGranted = true;
          break;
        } else if (status.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Storage permission permanently denied. Please enable it in app settings for downloads to work.',
                ),
                duration: Duration(seconds: 5),
              ),
            );
          }
          await openAppSettings();
          await Future.delayed(const Duration(seconds: 3));
        } else {
          final result = await Permission.storage.request();
          if (result.isGranted) {
            permissionGranted = true;
            break;
          }
        }
      }
      if (!permissionGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Storage permission denied. You will not be able to download receipts.',
            ),
          ),
        );
      }
    }
    // On Android 13+ (API 33+), no permission is needed for saving to Downloads via MediaStore.
  }

  // --- Populate Form on Edit ---
  // Make async to fetch latest phone number
  Future<void> _populateFormIfInitialData() async {
    PhoneNumber? initialPhoneNumberObject; // Declare outside if/setState

    if (widget.initialData != null) {
      print("Populating form with initial data for editing:");
      print(widget.initialData);

      // --- Fetch latest phone number before setting state ---
      String? fetchedMobileNumber;
      String? fetchedCountryCode;
      final certificateId = widget.initialData!['id'] as int?;

      if (certificateId != null) {
        try {
          print("Fetching latest phone number for ID: $certificateId");
          final response =
              await Supabase.instance.client
                  .from('certificates')
                  .select('mobile_number, country_code')
                  .eq('id', certificateId)
                  .maybeSingle(); // Use maybeSingle

          if (response != null) {
            fetchedMobileNumber = response['mobile_number'] as String?;
            fetchedCountryCode = response['country_code'] as String?;
            print(
              "Fetched phone details: Number=$fetchedMobileNumber, Code=$fetchedCountryCode",
            );
          } else {
            print("Certificate ID $certificateId not found for phone fetch.");
            // Handle case where certificate might have been deleted between screens
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Error: Could not find the certificate record to fetch phone number.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        } catch (e) {
          print("Error fetching phone number during edit population: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error fetching latest phone number: ${e.toString()}',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          // Proceed with potentially stale data from initialData as fallback? Or clear?
          // For now, we'll let it use the initialData values if fetch fails.
        }
      }
      // --- End fetch ---

      // Use fetched data if available, otherwise fallback to initialData
      final String? countryCodeToUse =
          fetchedCountryCode ?? widget.initialData!['country_code'] as String?;
      final String? phoneNumberToUse =
          fetchedMobileNumber ??
          widget.initialData!['mobile_number'] as String?;

      // Now set the state with potentially updated phone details
      setState(() {
        _isEditMode = true;
        _phoneNumberManuallyChanged =
            false; // Reset flag when entering edit mode
        _editingCertificateId = certificateId; // Use the ID fetched earlier
        _lastGeneratedBillNumber =
            widget.initialData!['bill_number'] as String?;
        _originalFinancialYear =
            widget.initialData!['financial_year'] as String?;

        _selectedTrust = widget.initialData!['trust'] as String?;
        _nameController.text = widget.initialData!['name'] ?? '';
        _addressController.text = widget.initialData!['address'] ?? '';
        _emailController.text = widget.initialData!['email'] ?? '';
        _purposeController.text = widget.initialData!['purpose'] ?? '';
        _amountController.text =
            widget.initialData!['amount']?.toString() ?? '';
        _chequeNumberController.text =
            widget.initialData!['cheque_number'] ?? '';
        _otherRemarksController.text =
            widget.initialData!['other_remarks'] ?? '';
        _internalRemarksController.text =
            widget.initialData!['internal_remarks'] ?? '';
        _selectedOfferingType = widget.initialData!['offering_type'] as String?;
        _selectedModeOfTransfer =
            widget.initialData!['transfer_mode'] as String?;
        _showChequeField = _selectedModeOfTransfer == 'Cheque';
        _bankController.text = widget.initialData!['bank'] ?? '';

        // Store initial phone details for IntlPhoneField prefill
        // Ensure these are assigned BEFORE setState
        final initialCountryCode =
            widget.initialData!['country_code'] as String?;
        final initialPhoneNumber =
            widget.initialData!['mobile_number'] as String?;

        _initialCountryCodeString =
            countryCodeToUse; // Use potentially fetched value
        _initialPhoneNumberString =
            phoneNumberToUse; // Use potentially fetched value

        // Initialize _phoneNumber in edit mode using the determined values
        if (countryCodeToUse != null && phoneNumberToUse != null) {
          try {
            String numberToUse = phoneNumberToUse.trim();
            // Enforce max length 15 for phone number (min length check removed here, handled by validator)
            if (numberToUse.length > 15) {
              numberToUse = numberToUse.substring(0, 15);
            }
            // Update the state variable used by IntlPhoneField's initialValue
            _initialPhoneNumberString = numberToUse;

            // Create the PhoneNumber object for the state
            initialPhoneNumberObject = PhoneNumber(
              countryISOCode: countryCodeToUse, // Use potentially fetched value
              countryCode: '', // Not needed by IntlPhoneField directly
              number: numberToUse,
            );
            print("Successfully created PhoneNumber object for edit mode.");
          } catch (e) {
            print("Error creating PhoneNumber object in edit mode: $e");
            // Clear phone state if creation fails
            initialPhoneNumberObject = null;
            _initialPhoneNumberString = null;
            _initialCountryCodeString = null;
          }
        }
        // Restore assignment: Ensure _phoneNumber is set during initialization in edit mode
        _phoneNumber = initialPhoneNumberObject;

        // DO NOT explicitly call _fetchDonorDetails here.
        // The IntlPhoneField's onChanged callback will handle updating _phoneNumber
        // and triggering _fetchDonorDetails when the field initializes with the initialValue.
      }); // End of setState

      // --- NEW: Trigger validation after the frame builds in edit mode ---
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Ensure the widget is still mounted and the form state exists
        if (mounted && _formKey.currentState != null) {
          print("Triggering validation in post frame callback for edit mode.");
          _formKey.currentState!.validate();
        }
      });
      // --- END NEW ---
    } // End of if (widget.initialData != null)
  }

  // --- Fetch User Profile ---
  Future<void> _fetchUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return; // Not logged in

    try {
      final response =
          await Supabase.instance.client
              .from('profiles')
              .select('is_admin')
              .eq('id', user.id)
              .single();

      if (mounted) {
        setState(() {
          _isAdmin = response['is_admin'] as bool? ?? false;
        });
      }
    } catch (e) {
      print('Error fetching user profile: $e');
      // Handle error appropriately, maybe show a snackbar
    }
  }

  // --- Auto-fill Logic ---
  Future<void> _fetchDonorDetails(PhoneNumber number) async {
    // Only fetch if the number part is reasonably long (e.g., >= 5 digits) to avoid excessive queries
    if (number.number.length < 5 || _isFetchingDonor) {
      return;
    }

    setState(() {
      _isFetchingDonor = true;
    });

    try {
      // Query Supabase based on the number part and country code
      final response =
          await Supabase.instance.client
              .from('certificates')
              .select('name, address, email, country_code, mobile_number')
              .eq('mobile_number', number.number) // Match number part
              .eq(
                'country_code',
                number.countryISOCode,
              ) // Match country code (e.g., 'IN')
              .order(
                'created_at',
                ascending: false,
              ) // Get the latest record for this number
              .limit(1)
              .maybeSingle(); // Use maybeSingle to handle no results gracefully

      if (mounted && response != null) {
        setState(() {
          _nameController.text = response['name'] ?? '';
          _addressController.text = response['address'] ?? '';
          _emailController.text = response['email'] ?? '';
        });
      } else if (mounted && response == null) {
        // Optional: Clear fields if no donor found
      }
    } catch (e) {
      print('Error fetching donor details: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingDonor = false;
        });
      }
    }
  }
  // --- End Auto-fill Logic ---

  // Function to handle form submission
  Future<void> _submitForm() async {
    print('Submit form called');
    // Reset previous state
    setState(() {
      print('Setting state in submit form');
      _generatedPdfBytes = null;
      _certificateUrl = null;
      // Don't reset bill number if just entering edit mode
      if (!_isEditMode) {
        _lastGeneratedBillNumber = null;
        _editingCertificateId = null;
        _originalFinancialYear = null;
      }
    });

    // Validate form, BUT skip if in edit mode and phone number wasn't changed
    bool shouldValidate = true;
    if (_isEditMode && !_phoneNumberManuallyChanged) {
      print(
        "Skipping form validation during submit (edit mode, phone unchanged).",
      );
      shouldValidate = false;
    }

    if (shouldValidate && !_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the errors in the form')),
      );
      return;
    }

    // Removed phone number null/empty check for initial submission

    // Additional check: Ensure at least one of purpose or offering type is filled
    final isPurposeFilled = _purposeController.text.trim().isNotEmpty;
    final isOfferingTypeSelected = _selectedOfferingType != null;

    if (!isPurposeFilled && !isOfferingTypeSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please provide Nature of Donation or Purpose of Donation (or both)',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String? generatedBillNumber; // Local variable for this submission
    String? financialYear;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // --- Receipt Number Logic ---
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      if (currentMonth >= 4) {
        financialYear =
            '$currentYear-${(currentYear + 1).toString().substring(2)}';
      } else {
        financialYear =
            '${currentYear - 1}-${currentYear.toString().substring(2)}';
      }

      final lastReceiptResponse =
          await Supabase.instance.client
              .from('certificates')
              .select('receipt_number')
              .eq('financial_year', financialYear)
              .order('receipt_number', ascending: false)
              .limit(1)
              .maybeSingle();

      int nextReceiptNumber = 1;
      if (lastReceiptResponse != null &&
          lastReceiptResponse['receipt_number'] != null) {
        nextReceiptNumber = (lastReceiptResponse['receipt_number'] as int) + 1;
      }

      generatedBillNumber = '$nextReceiptNumber/$financialYear';
      _lastGeneratedBillNumber = generatedBillNumber; // Store for filename use
      // --- End Receipt Number Logic ---

      final trustName = _selectedTrust!;
      final logoAsset =
          trustName == "PARAMANADI TRUST"
              ? "assets/images/logo2.png"
              : "assets/images/logo.png";
      final name = _nameController.text.trim();
      final address = _addressController.text.trim();
      // --- Safely access phone number details (only if validation wasn't skipped) ---
      PhoneNumber currentPhoneNumber; // Declare variable
      String mobile;
      String countryCode;
      String mobileNumberPart;

      if (shouldValidate) {
        // Perform these checks only if main validation ran
        if (_phoneNumber == null) {
          throw Exception(
            'Phone number is missing or invalid. Please enter a valid mobile number.',
          );
        }
        currentPhoneNumber = _phoneNumber!; // Promote after null check

        // We trust the _phoneNumber object state if form validation passed.
        if (!currentPhoneNumber.isValidNumber()) {
          // This should ideally not be reached if form validation is working correctly
          print(
            "Warning: _submitForm reached with invalid _phoneNumber despite form validation.",
          );
          throw Exception(
            'Invalid phone number format detected during submission.',
          );
        }
        if (currentPhoneNumber.number.isEmpty ||
            currentPhoneNumber.countryISOCode.isEmpty) {
          throw Exception(
            'Phone number or country code is empty after validation.',
          );
        }
        // Assign values needed later
        mobile = currentPhoneNumber.completeNumber; // For PDF
        countryCode = currentPhoneNumber.countryISOCode; // For DB
        mobileNumberPart = currentPhoneNumber.number; // For DB
      } else {
        // If validation was skipped (edit mode, phone unchanged),
        // trust the existing _phoneNumber state (assuming it was loaded correctly).
        // We still need to handle the case where it might be null somehow, though
        // the initialization in _populateFormIfInitialData should prevent this.
        if (_phoneNumber == null) {
          // Add a safeguard check even when skipping validation
          print(
            "Error: _phoneNumber is null even when skipping validation in edit mode.",
          );
          throw Exception(
            'Internal Error: Phone number state is unexpectedly missing during edit.',
          );
        }
        currentPhoneNumber =
            _phoneNumber!; // Assign for consistency if needed later
        // Assign values needed later from the existing state
        mobile = currentPhoneNumber.completeNumber;
        countryCode = currentPhoneNumber.countryISOCode;
        mobileNumberPart = currentPhoneNumber.number;
      }
      // --- End phone number access ---
      final email = _emailController.text.trim();
      final purposeInput = _purposeController.text.trim();
      final offeringType = _selectedOfferingType;
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final mode = _selectedModeOfTransfer!;

      // Determine purpose for DB: Use input if provided, otherwise null.
      final String? purposeForDb =
          purposeInput.isNotEmpty ? purposeInput : null;

      // Validation check: Ensure at least one is filled (already done earlier, but good to keep consistent)
      if (purposeForDb == null && offeringType == null) {
        // This state should ideally be caught by the earlier validation check
        // but we keep it here as a safeguard during refactoring.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Internal Error: Validation failed for Purpose/Nature.',
            ),
          ),
        );
        setState(() => _isLoading = false); // Stop loading
        return; // Stop submission
      }

      final chequeNumber =
          _showChequeField ? _chequeNumberController.text.trim() : null;
      final bankName = _showChequeField ? _bankController.text.trim() : null;
      final otherRemarks = _otherRemarksController.text.trim();
      final internalRemarks = _internalRemarksController.text.trim();
      final formattedDate = DateFormat('dd-MM-yyyy').format(now);

      // 1. Prepare data for Supabase insertion (NO certificate_url)
      final certificateDataForDb = {
        'user_id': user.id,
        'user_email': user.email,
        'trust': trustName,
        'name': name,
        'address': address,
        'mobile_number': mobileNumberPart,
        'country_code': countryCode,
        'email': email.isEmpty ? null : email,
        'offering_type': offeringType,
        'purpose': purposeForDb,
        'amount': amount,
        'transfer_mode': mode,
        'cheque_number': chequeNumber,
        'bank': bankName,
        'bill_number': generatedBillNumber,
        'receipt_number': nextReceiptNumber,
        'financial_year': financialYear,
        'date': formattedDate,
        'other_remarks': otherRemarks.isEmpty ? null : otherRemarks,
        'internal_remarks': internalRemarks.isEmpty ? null : internalRemarks,
      };

      // --- EDIT MODE CHECK ---
      int currentCertificateId; // To store the ID for edit mode activation

      if (_isEditMode && _editingCertificateId != null) {
        // --- UPDATE PATH ---
        print('Updating existing certificate ID: $_editingCertificateId');

        // 1a. Prepare data for Supabase update (exclude fields that shouldn't change)
        final updateData = Map<String, dynamic>.from(certificateDataForDb);
        updateData.remove('user_id');
        updateData.remove('user_email');
        updateData.remove('bill_number');
        updateData.remove('receipt_number');
        updateData.remove('financial_year');
        // Consider if date should be updated - keeping original for now
        updateData.remove('date');
        // Also remove created_at just in case
        updateData.remove('created_at');

        // --- Re-validate and fetch current form values for update ---
        // Removed phone number null/validity checks for update
        final currentPhoneNumber =
            _phoneNumber; // Assign directly, handle potential null below

        // Overwrite relevant fields in updateData with current values from controllers/state
        updateData['trust'] = _selectedTrust!;
        updateData['name'] = _nameController.text.trim();
        updateData['address'] = _addressController.text.trim();
        // Use current state, handle potential null if needed elsewhere or ensure it's set
        updateData['mobile_number'] = currentPhoneNumber?.number;
        updateData['country_code'] = currentPhoneNumber?.countryISOCode;
        updateData['email'] =
            _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim();
        updateData['offering_type'] = _selectedOfferingType;
        // Recalculate purpose based on current form state
        final currentPurposeInput = _purposeController.text.trim();
        // FIX: Do not default to offering_type if editing and purpose is empty
        if (currentPurposeInput.isNotEmpty) {
          updateData['purpose'] = currentPurposeInput;
        } else {
          updateData['purpose'] = null;
        }
        updateData['amount'] =
            double.tryParse(_amountController.text.trim()) ?? 0.0;
        updateData['transfer_mode'] = _selectedModeOfTransfer!;
        updateData['cheque_number'] =
            _showChequeField ? _chequeNumberController.text.trim() : null;
        updateData['other_remarks'] =
            _otherRemarksController.text.trim().isEmpty
                ? null
                : _otherRemarksController.text.trim();
        updateData['internal_remarks'] =
            _internalRemarksController.text.trim().isEmpty
                ? null
                : _internalRemarksController.text.trim();
        // --- End re-fetch ---

        print('--- EDIT MODE ---');
        print('Attempting to update certificate ID: $_editingCertificateId');
        print(
          'Update Data being sent (after re-fetch): $updateData', // Log the map before sending
        );

        // Perform Update
        try {
          // Fetch existing mobile number to compare
          final existing =
              await Supabase.instance.client
                  .from('certificates')
                  .select('mobile_number')
                  .eq('id', _editingCertificateId!)
                  .maybeSingle();

          if (existing == null) {
            throw Exception(
              'The certificate record could not be found for update. It may have been deleted.',
            );
          }

          final existingMobile = existing['mobile_number'] as String?;

          // Check if mobile number changed
          if (updateData['mobile_number'] != null &&
              updateData['mobile_number'] != existingMobile) {
            // Update including mobile number
            await Supabase.instance.client
                .from('certificates')
                .update(updateData)
                .eq('id', _editingCertificateId!);
          } else {
            // Mobile number unchanged, exclude from update
            final dataWithoutMobile = Map<String, dynamic>.from(updateData);
            dataWithoutMobile.remove('mobile_number');
            await Supabase.instance.client
                .from('certificates')
                .update(dataWithoutMobile)
                .eq('id', _editingCertificateId!);
          }
          print('Update successful for ID: $_editingCertificateId');
        } catch (e) {
          print('!!! Supabase Update Error: $e');
          // Removed specific duplicate key handling for mobile number
          throw Exception(
            'Failed to update certificate in database: ${e.toString()}',
          );
        }

        // Use original bill number and FY for PDF path (already set if editing)
        generatedBillNumber = _lastGeneratedBillNumber;
        financialYear = _originalFinancialYear;
        currentCertificateId = _editingCertificateId!; // Keep the ID
      } else {
        // --- CREATE PATH ---
        print('--- CREATE MODE ---');
        print('Attempting to insert new certificate');
        print('Insert Data: $certificateDataForDb');

        // 1b. Insert data WITHOUT certificate_url
        try {
          final insertedData =
              await Supabase.instance.client
                  .from('certificates')
                  .insert(certificateDataForDb)
                  .select('id') // Select the ID of the newly inserted record
                  .single();
          currentCertificateId = insertedData['id']; // Store the new ID
          _originalFinancialYear = financialYear; // Store the original FY
          print('Insert successful, new ID: $currentCertificateId');
        } catch (e) {
          print('!!! Supabase Insert Error: $e');
          // Try to provide more specific feedback if possible
          if (e is PostgrestException) {
            print('Insert Error Details: ${e.details}');
            print('Insert Error Hint: ${e.hint}');
            print('Insert Error Code: ${e.code}');
            throw Exception('Database error saving certificate: ${e.message}');
          } else {
            throw Exception(
              'Failed to save certificate to database: ${e.toString()}',
            );
          }
        }
      }
      // --- END EDIT MODE CHECK ---

      print('Database operation successful. Proceeding with PDF generation...');

      // 2. Prepare data for PDF Generation (Uses current form data, ensuring consistent phone number)
      // Use the 'mobile' variable derived earlier, which holds the number intended for the DB update.
      final certificateDataForPdf = {
        'trust': _selectedTrust!, // Use current state
        'logoAsset': logoAsset, // logoAsset depends on trust, which is current
        'name': _nameController.text.trim(), // Use current controller value
        'address':
            _addressController.text.trim(), // Use current controller value
        'mobile_number': mobile, // Use the 'mobile' variable derived earlier
        'email':
            _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(), // Use current controller value
        'offering_type': _selectedOfferingType, // Use current state
        'purpose':
            _purposeController.text.trim().isEmpty
                ? null
                : _purposeController.text
                    .trim(), // Use current controller value
        'amount':
            double.tryParse(_amountController.text.trim()) ??
            0.0, // Use current controller value
        'transfer_mode': _selectedModeOfTransfer!, // Use current state
        'cheque_number':
            _showChequeField
                ? _chequeNumberController.text.trim()
                : null, // Use current controller value
        'bank':
            _showChequeField
                ? _bankController.text.trim()
                : null, // Use current controller value
        'bill_number':
            generatedBillNumber, // Use the correct bill number (original if edit, new if create)
        'date':
            _isEditMode
                ? widget.initialData!['date']
                : formattedDate, // Use original date if editing
        'username': user.email ?? 'N/A', // This seems okay
        'other_remarks':
            _otherRemarksController.text.trim().isEmpty
                ? null
                : _otherRemarksController.text
                    .trim(), // Use current controller value
      };

      // Generate PDF (using potentially updated data)
      final pdfBytes = await generateCertificatePdf(certificateDataForPdf);
      _generatedPdfBytes = pdfBytes;

      // 3. Upload PDF to Supabase Storage (Use correct FY and BillNumber)
      // Ensure financialYear and generatedBillNumber are not null here
      if (financialYear == null || generatedBillNumber == null) {
        throw Exception(
          "Financial year or bill number is missing before PDF upload.",
        );
      }
      final pdfPath =
          'certificates/$financialYear/${generatedBillNumber.replaceAll('/', '_')}.pdf';
      print('Uploading PDF to: $pdfPath');
      try {
        await Supabase.instance.client.storage
            .from('certificates')
            .uploadBinary(
              // Use uploadBinary for Uint8List
              pdfPath,
              pdfBytes,
              fileOptions: const FileOptions(
                upsert: true, // Important for updates
                contentType: 'application/pdf',
              ),
            );
        print('PDF upload successful.');
      } catch (e) {
        print('!!! Supabase Storage Upload Error: $e');
        // Decide if this is critical. Maybe the DB entry succeeded but upload failed.
        // For now, rethrow to show error to user.
        throw Exception(
          'Database record saved, but failed to upload PDF: ${e.toString()}',
        );
      }

      // 4. Get Signed URL (for viewing only, DO NOT update the table)
      String? signedUrl;
      String? urlError;
      try {
        signedUrl = await Supabase.instance.client.storage
            .from('certificates')
            .createSignedUrl(
              pdfPath,
              60 * 60 * 24 * 7, // 7 day validity for viewing link
            );
      } on StorageException catch (e) {
        print('Error creating signed URL: ${e.message}');
        urlError = e.message;
      } catch (e) {
        print('Unexpected error creating signed URL: $e');
        urlError = 'Unexpected error: $e';
      }

      // Store the URL locally for the View button
      if (signedUrl != null && mounted) {
        setState(() {
          _certificateUrl = signedUrl;
        });
      } else if (mounted) {
        // Show error only if URL generation failed, not if component unmounted
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error getting PDF URL for viewing: ${urlError ?? 'Unknown error'}',
            ),
          ),
        );
      }

      // Store the ID for potential future edits *after* successful generation/update
      _editingCertificateId = currentCertificateId;
      final successMessage =
          _isEditMode
              ? 'Receipt Updated Successfully!'
              : 'Receipt Generated and Saved!';

      if (mounted) {
        setState(() {
          _isEditMode =
              false; // Exit edit mode after successful update/generate
          _isLoading = false; // Ensure loading stops on success
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (e) {
      // Catch errors from DB or Storage operations
      print('Error caught in _submitForm catch block: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Operation Failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
          // Keep _isEditMode true if it was an edit attempt that failed
          // Keep generated PDF bytes null if generation failed? Or allow retry?
          // _generatedPdfBytes = null; // Reset PDF state on failure?
        });
      }
    }
    // Removed finally block as loading state is handled in success/error paths now
  }

  // REWRITTEN: Function to view PDF using temporary file and viewer page
  Future<void> _viewPdf() async {
    if (_generatedPdfBytes == null || _lastGeneratedBillNumber == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please generate the receipt first.')),
        );
      }
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    String? viewError;
    String? tempFilePath;

    try {
      // 1. Get temporary directory
      final tempDir = await getTemporaryDirectory();

      // 2. Create a unique temporary file path using the new format
      final trustAbbreviation =
          _selectedTrust == "PARAMANADI TRUST" ? "Paramanadi" : "Noolaatti";
      final billParts = _lastGeneratedBillNumber?.split('/');
      final receiptNumber =
          billParts?.isNotEmpty ?? false ? billParts![0] : 'UnknownReceiptNo';
      final financialYear =
          billParts?.length == 2 ? billParts![1] : 'UnknownFY';
      final safeName = _nameController.text
          .trim() // Trim whitespace first
          .replaceAll(RegExp(r'[\\/*?:"<>|]'), '_')
          .replaceAll(' ', '_');
      final tempFilename =
          '${trustAbbreviation}_Receipt_${receiptNumber}_${financialYear}_$safeName.pdf';
      tempFilePath = '${tempDir.path}/$tempFilename';
      final tempFile = File(tempFilePath);

      // 3. Write the generated bytes to the temporary file
      await tempFile.writeAsBytes(_generatedPdfBytes!);

      // 4. Navigate to the viewer page (after closing loading dialog)
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerPage(filePath: tempFilePath!),
          ),
        );
      }
    } catch (e) {
      print('Error preparing PDF for viewing: $e');
      viewError = 'Could not prepare PDF for viewing: ${e.toString()}';
      // Pop the dialog here if an error occurred before navigation attempt
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
    // No finally block needed for dialog pop, handled in success/error paths.

    // Show error message if viewing setup failed
    if (viewError != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(viewError)));
    }
  }

  // REVISED: Function to handle PERMANENT PDF download with permissions and specific folder
  Future<void> _downloadPdf() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    String? downloadError;

    try {
      // Prepare filename using the new format
      final trustAbbreviation =
          _selectedTrust == "PARAMANADI TRUST" ? "Paramanadi" : "Noolaatti";
      final billParts = _lastGeneratedBillNumber?.split('/');
      final receiptNumber =
          billParts?.isNotEmpty ?? false ? billParts![0] : 'UnknownReceiptNo';
      final financialYear =
          billParts?.length == 2 ? billParts![1] : 'UnknownFY';
      final safeName = _nameController.text
          .trim() // Trim whitespace first
          .replaceAll(RegExp(r'[\\/*?:"<>|]'), '_')
          .replaceAll(' ', '_');
      final filename =
          '${trustAbbreviation}_Receipt_${receiptNumber}_${financialYear}_$safeName.pdf';

      // Detect Android version
      int sdkInt = 30;
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        sdkInt = androidInfo.version.sdkInt;
      }

      if (Platform.isAndroid && sdkInt >= 29) {
        // Android 10+ (API 29+): Use MediaStore to save to Downloads/Receipts
        final tempDir = await getTemporaryDirectory();
        final tempFilePath = '${tempDir.path}/$filename';
        final tempFile = File(tempFilePath);
        await tempFile.writeAsBytes(_generatedPdfBytes!);

        final mediaStore = MediaStore();
        await mediaStore.saveFile(
          tempFilePath: tempFilePath,
          dirType: DirType.download,
          dirName: DirName.download,
        );
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF saved to Downloads: $filename')),
          );
        }
      } else if (Platform.isAndroid && sdkInt < 29) {
        // Android 9 and below: Request permission and save to Downloads/Receipts
        PermissionStatus status = await Permission.storage.request();

        if (!status.isGranted) {
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Storage permission denied. Cannot download file.',
                ),
              ),
            );
          }
          throw Exception('Storage permission denied.');
        }

        final downloadsDir = Directory('/storage/emulated/0/Download/Receipts');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }

        final filePath = '${downloadsDir.path}/$filename';
        final file = File(filePath);
        await file.writeAsBytes(_generatedPdfBytes!);

        // Trigger media scan to make file visible in file manager
        try {
          final result = await MethodChannel(
            'com.example.certificate_app/media_scan',
          ).invokeMethod('scanFile', {'path': filePath});
          print('Media scan result: $result');
        } catch (e) {
          print('Error triggering media scan: $e');
        }

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved to Downloads/Receipts: $filename'),
            ),
          );
        }
      } else {
        // Fallback for other platforms: Save to app documents
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final receiptsDir = Directory('${appDocDir.path}/Receipts');
        if (!await receiptsDir.exists()) {
          await receiptsDir.create(recursive: true);
        }
        final filePath = '${receiptsDir.path}/$filename';
        final file = File(filePath);
        await file.writeAsBytes(_generatedPdfBytes!);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF saved to app documents: $filename')),
          );
        }
      }
    } catch (e) {
      downloadError = downloadError ?? 'Could not save PDF: ${e.toString()}';
      print('Error saving PDF locally or other error: $e');
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(downloadError)));
      }
    }
  }

  // Function to handle PDF sharing - CORRECTED
  Future<void> _sharePdf() async {
    if (_generatedPdfBytes == null || _lastGeneratedBillNumber == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No PDF generated or bill number missing!'),
          ),
        );
      }
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      // Use the new filename format
      final trustAbbreviation =
          _selectedTrust == "PARAMANADI TRUST" ? "Paramanadi" : "Noolaatti";
      final billParts = _lastGeneratedBillNumber?.split('/');
      final receiptNumber =
          billParts?.isNotEmpty ?? false ? billParts![0] : 'UnknownReceiptNo';
      final financialYear =
          billParts?.length == 2 ? billParts![1] : 'UnknownFY';
      final safeName = _nameController.text
          .trim() // Trim whitespace first
          .replaceAll(RegExp(r'[\\/*?:"<>|]'), '_')
          .replaceAll(' ', '_'); // Sanitize name
      final filename =
          '${trustAbbreviation}_Receipt_${receiptNumber}_${financialYear}_$safeName.pdf';
      final tempFilePath = '${tempDir.path}/$filename';
      final file = File(tempFilePath);

      // Ensure the directory exists (though tempDir usually does)
      await file.parent.create(recursive: true);

      // Write the file to the temporary directory
      await file.writeAsBytes(_generatedPdfBytes!);

      // Share the file from the temporary path using the sanitized filename
      final box = context.findRenderObject() as RenderBox?;
      // Ensure the 'name' parameter in XFile uses the sanitized filename
      final shareResult = await Share.shareXFiles(
        [XFile(tempFilePath, mimeType: 'application/pdf', name: filename)],
        text: 'Here is your donation Receipt.',
        subject: 'Donation Receipt',
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
      );

      if (shareResult.status == ShareResultStatus.success) {
        print('Receipt shared successfully.');
      } else {
        print('Receipt sharing dismissed or failed: ${shareResult.status}');
      }
    } catch (e) {
      print('Error sharing PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing PDF: $e')));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _purposeController.dispose();
    _amountController.dispose();
    _chequeNumberController.dispose();
    _otherRemarksController.dispose();
    _internalRemarksController.dispose();
    _authStateSubscription?.cancel(); // Cancel the auth subscription
    _profileChannel?.unsubscribe(); // Cancel the profile subscription
    super.dispose();
  }

  // --- Edit Mode Functions ---
  void _enterEditMode() {
    if (_editingCertificateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot edit. No receipt generated or selected.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Edit'),
          content: const Text(
            'You are about to edit the generated receipt. This will overwrite the existing data and PDF. Continue?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                setState(() {
                  _isEditMode = true;
                  // Optionally disable fields like Trust, Mobile if needed
                  // _generatedPdfBytes = null; // Optionally hide buttons during edit
                  // _certificateUrl = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Edit mode enabled. Modify the details and click "Update Receipt".',
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _cancelEditMode() {
    setState(() {
      _isEditMode = false;
      // Optionally clear form or reload original data here
      // For simplicity, just exit edit mode. User can regenerate if needed.
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Edit mode cancelled.')));
  }
  // --- End Edit Mode Functions ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Receipt'), // Updated AppBar Title
        // Remove actions to remove logout button from top right
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.logout),
        //     tooltip: 'Logout',
        //     onPressed: () async {
        //       // ... (logout logic remains the same)
        //     },
        //   ),
        // ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home), // Icon for Home
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                if (ModalRoute.of(context)?.settings.name != '/') {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
            ),
            // Add View Receipts ListTile here
            ListTile(
              leading: const Icon(Icons.receipt_long), // Icon for Receipts
              title: const Text('View Receipts'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushNamed(
                  context,
                  '/certificates',
                ); // Navigate to CertificatesPage
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('View Profiles'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profiles');
              },
            ),
            // Conditionally add Admin menu item
            if (_isAdmin)
              ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings,
                ), // Icon for Admin
                title: Text(
                  _pendingApprovalCount > 0
                      ? 'Approve Users ($_pendingApprovalCount)' // Show count if > 0
                      : 'Approve Users', // Don't show count if 0
                  style: TextStyle(
                    color:
                        _pendingApprovalCount > 0
                            ? Colors.red
                            : null, // Conditional color
                    fontWeight:
                        _pendingApprovalCount > 0
                            ? FontWeight.bold
                            : FontWeight.normal, // Conditional weight
                  ),
                ),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Navigator.pushNamed(context, '/approve_users').then((_) {
                    // Re-fetch count when returning from approve users screen
                    _fetchPendingApprovalCount();
                  }); // Navigate to new screen and refetch on return
                },
              ),
            // Conditionally add View Admins menu item
            if (_isAdmin)
              ListTile(
                leading: const Icon(
                  Icons.people, // Changed icon to Icons.people
                ), // Icon for View Admins
                title: const Text('View Admins'),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Navigator.pushNamed(
                    context,
                    '/view_admins',
                  ); // Navigate to the new screen
                },
              ),
            // Add Logout button to drawer
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(context); // Close drawer first
                try {
                  await Supabase.instance.client.auth.signOut();
                  if (!mounted) return;
                  // Navigate to login screen and remove all previous routes
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                } catch (e) {
                  print('Error signing out: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error signing out: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Center(
                child: Text(
                  'ஸ்ரீ:',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'NotoSansDevanagari',
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'ஶ்ரீமதே ராமாநுஜாய நம:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'NotoSansDevanagari',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Image.asset(
                  'assets/images/Thirumankaappu - Jeeyar matam_20250402_134630_0000.png',
                  height: 80,
                ),
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _selectedTrust,
                hint: const Text('Select Organisation Name'),
                items:
                    _trustOptions.map((String trust) {
                      return DropdownMenuItem<String>(
                        value: trust,
                        child: Text(trust),
                      );
                    }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedTrust = newValue;
                  });
                },
                validator:
                    (value) =>
                        value == null ? 'Please select an organisation' : null,
                decoration: const InputDecoration(
                  labelText: 'Name of the Organisation',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name of the Donor',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Please enter donor name'
                            : null,
              ),
              const SizedBox(height: 16),

              // --- Phone Field ---
              IntlPhoneField(
                key: ValueKey(
                  _isEditMode,
                ), // Add key to force rebuild on mode change if needed
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  border: const OutlineInputBorder(borderSide: BorderSide()),
                  suffixIcon:
                      _isFetchingDonor
                          ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                          : null,
                ),
                // Use initial values only in edit mode and if they exist
                initialCountryCode:
                    _isEditMode ? _initialCountryCodeString : 'IN',
                // Set initialValue which expects the number part without country code
                initialValue: _isEditMode ? _initialPhoneNumberString : null,
                onChanged: (phone) {
                  // This updates the _phoneNumber state variable used in _submitForm
                  // Ensure it's updated even if the initial value was set
                  print('IntlPhoneField onChanged: $phone');
                  setState(() {
                    _phoneNumber = phone;
                    if (_isEditMode) {
                      // Only set flag if in edit mode
                      _phoneNumberManuallyChanged = true;
                    }
                  });
                  // Only fetch donor details on change if NOT in edit mode
                  if (!_isEditMode) {
                    _fetchDonorDetails(phone);
                  }
                },
                validator: (phoneNumber) {
                  // Skip validation in edit mode if the number wasn't manually changed
                  if (_isEditMode && !_phoneNumberManuallyChanged) {
                    print(
                      "Skipping phone validation in edit mode (unchanged).",
                    );
                    return null;
                  }

                  // --- Original Validation Logic ---
                  if (phoneNumber == null || phoneNumber.number.isEmpty) {
                    return 'Please enter a mobile number';
                  }
                  // Enforce max length of 15 digits for all numbers
                  if (phoneNumber.number.length > 15) {
                    return 'Mobile number is too long';
                  }
                  // First, check if the number is considered valid by the package
                  if (!phoneNumber.isValidNumber()) {
                    // Add specific check for India (IN) length if package validation fails
                    if (phoneNumber.countryISOCode == 'IN' &&
                        phoneNumber.number.length == 10) {
                      // If it's IN and 10 digits, override the package's potential failure
                      return null;
                    }
                    // Otherwise, return the package's validation error
                    return 'Please enter a valid mobile number';
                  }
                  // Add an explicit length check for India even if isValidNumber passes, as a safeguard
                  if (phoneNumber.countryISOCode == 'IN' &&
                      phoneNumber.number.length != 10) {
                    return 'Indian mobile number must be 10 digits';
                  }
                  // If all checks pass, the number is valid
                  return null; // Return null only if valid
                },
                // Keep autovalidateMode as is or change if needed
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 16),

              // Removed debug text for phone number value
              // Text('Phone Number value: ${_phoneNumber?.number}'),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                  counterText: "", // Hide counter
                ),
                // maxLength: 200, // Limit address length - REMOVED
                maxLines: 3,
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Please enter an address'
                            : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (Optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  // Use a more standard email regex
                  if (value != null &&
                      value.isNotEmpty &&
                      !RegExp(
                        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                      ).hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String?>(
                value: _selectedOfferingType,
                hint: const Text('Select Nature (Optional if Purpose filled)'),
                items:
                    _offeringTypeOptions.map((String? type) {
                      return DropdownMenuItem<String?>(
                        value: type,
                        child: Text(type ?? 'Clear Selection'),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedOfferingType = newValue;
                  });
                  // Removed explicit validation call from here
                  // Validation will now only happen on form submission
                },
                decoration: const InputDecoration(
                  labelText: 'Nature of Donation (Optional if purpose is fees)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _purposeController,
                decoration: const InputDecoration(
                  labelText:
                      'Purpose of Donation (Optional if Nature has been selected)',
                  border: OutlineInputBorder(),
                  counterText: "", // Hide the default counter
                ),
                // maxLength: 140, // Add character limit - REMOVED
                onChanged: (value) {
                  if (_selectedOfferingType == null) {
                    _formKey.currentState?.validate();
                  }
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedModeOfTransfer,
                hint: const Text('Select Mode of Donation'),
                items:
                    _modeOfTransferOptions.map((String mode) {
                      return DropdownMenuItem<String>(
                        value: mode,
                        child: Text(mode),
                      );
                    }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedModeOfTransfer = newValue;
                    _showChequeField = newValue == 'Cheque';
                    if (!_showChequeField) {
                      _chequeNumberController.clear();
                    }
                  });
                },
                validator:
                    (value) => value == null ? 'Please select a mode' : null,
                decoration: const InputDecoration(
                  labelText: 'Mode of Donation',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              if (_showChequeField)
                TextFormField(
                  controller: _chequeNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Cheque Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (_showChequeField && (value == null || value.isEmpty)) {
                      return 'Please enter the cheque number';
                    }
                    return null;
                  },
                ),
              if (_showChequeField)
                TextFormField(
                  controller: _bankController,
                  decoration: const InputDecoration(
                    labelText: 'Bank Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_showChequeField && (value == null || value.isEmpty)) {
                      return 'Please enter the bank name';
                    }
                    return null;
                  },
                ),
              if (_showChequeField) const SizedBox(height: 16),

              TextFormField(
                controller: _otherRemarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks (Optional - Displayed on Receipt)',
                  border: OutlineInputBorder(),
                  counterText: "", // Hide counter
                ),
                // maxLength: 150, // Limit remarks length - REMOVED
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _internalRemarksController,
                decoration: const InputDecoration(
                  labelText:
                      'Internal Remarks (Optional - Not Displayed on Receipt)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              Center(
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : Row(
                          // Use Row for Generate/Update and Cancel buttons
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              icon: Icon(
                                _isEditMode
                                    ? Icons.update
                                    : Icons.picture_as_pdf,
                                color: Colors.white,
                              ),
                              label: Text(
                                _isEditMode
                                    ? 'Update Receipt'
                                    : 'Generate Receipt',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed: _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _isEditMode
                                        ? Colors.orange[800]
                                        : Colors.blue[800],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 15,
                                ),
                              ),
                            ),
                            if (_isEditMode) // Show Cancel button only in edit mode
                              const SizedBox(width: 15), // Correct placement
                            if (_isEditMode)
                              ElevatedButton(
                                onPressed: _cancelEditMode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[600],
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 15,
                                  ),
                                ),
                                child: const Text(
                                  'Cancel Edit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
              ),
              const SizedBox(height: 20),

              // Only show Download/Share/View/Edit buttons if NOT in edit mode and PDF exists
              if (_generatedPdfBytes != null &&
                  !_isEditMode) // Corrected condition
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 10.0,
                      bottom: 20.0,
                    ), // Correct Padding
                    child: Row(
                      // Ensure Wrap is inside Padding
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.download, color: Colors.white),
                          label: const Text(
                            'Download',
                            style: TextStyle(color: Colors.white),
                          ),
                          onPressed: _downloadPdf,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.share, color: Colors.white),
                          label: const Text(
                            'Share',
                            style: TextStyle(color: Colors.white),
                          ),
                          onPressed: _sharePdf,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[700],
                          ),
                        ),
                        if (_certificateUrl != null &&
                            _certificateUrl!.isNotEmpty)
                          ElevatedButton.icon(
                            icon: const Icon(
                              Icons.visibility,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'View',
                              style: TextStyle(color: Colors.white),
                            ),
                            onPressed: _viewPdf,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
