import 'dart:typed_data';
import 'dart:io'; // Added for File and Platform
import 'package:path_provider/path_provider.dart'; // Added for directories
import 'dart:typed_data';
import 'dart:io'; // Added for File and Platform
import 'package:path_provider/path_provider.dart'; // Added for directories
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'pdf_viewer_page.dart'; // Import the new viewer page
import '../utils/pdf_generator.dart'; // Import the PDF generator
import 'package:permission_handler/permission_handler.dart'; // Import permission handler
import 'package:device_info_plus/device_info_plus.dart'; // Import device info
import 'package:media_store_plus/media_store_plus.dart'; // Import media_store_plus
import 'package:flutter/services.dart'; // Import MethodChannel for media scan
import '../utils/storage_permission.dart'; // Import storage permission utility
import 'home_screen.dart'; // Import HomeScreen

// Correct Class Definition
class CertificatesPage extends StatefulWidget {
  const CertificatesPage({super.key}); // Correct Constructor

  @override
  State<CertificatesPage> createState() => _CertificatesPageState();
}

class _CertificatesPageState extends State<CertificatesPage> {
  List<dynamic> _certificates = [];
  bool _loading = true;

  String _search = ''; // Reverted name
  String? _selectedTrust;
  String? _selectedCountry;
  String _selectedSearchColumn =
      'all'; // Added missing state variable for search column

  final List<String> _trustOptions = [
    "PARAMANADI TRUST",
    "NOOLAATTI PALA KALAI ORPPU MAIYAM",
  ];

  final List<String> _countryOptions = [
    "IN", // India
    "US", // United States
    "UK", // United Kingdom
    "Other",
  ];

  @override
  void initState() {
    super.initState();
    _fetchCertificates(); // Call directly
  }

  // CORRECTED: Fetch certificates with proper filtering (Reverted name change)
  Future<void> _fetchCertificates() async {
    setState(() {
      _loading = true;
    });

    try {
      // Start base query and select immediately
      var query =
          Supabase.instance.client
              .from('certificates')
              .select(); // Returns PostgrestTransformBuilder

      // Apply filters conditionally by chaining them onto the result of select()
      if (_search.isNotEmpty) {
        // Use reverted name
        if (_selectedSearchColumn == 'all') {
          query = query.or(
            'name.ilike.%$_search%,mobile_number.ilike.%$_search%,bill_number.ilike.%$_search%',
          );
        } else {
          query = query.ilike(_selectedSearchColumn, '%$_search%');
        }
      }

      if (_selectedTrust != null && _selectedTrust!.isNotEmpty) {
        query = query.eq('trust', _selectedTrust!);
      }

      // Chain order at the end
      final data = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _certificates = data;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error fetching certificates: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching certificates: ${e.toString()}'),
          ),
        );
      }
    }
  }

  // REWRITTEN: Function to download PDF temporarily and navigate to viewer
  Future<void> _viewPdf(
    String billNumber,
    String financialYear,
    String name, // Added name for filename consistency
  ) async {
    // Show loading indicator (optional but good UX)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    final pdfPath =
        'certificates/$financialYear/${billNumber.replaceAll('/', '_')}.pdf';
    // String? viewError; // REMOVED duplicate
    // String? tempFilePath; // REMOVED duplicate
    Map<String, dynamic>? certificateData; // To hold the full data
    String? viewError; // Moved error variable up
    String? tempFilePath; // Moved path variable up

    try {
      // 1. Find the certificate data safely
      try {
        // Add try-catch around the loop and potential access/cast issues
        for (final cert in _certificates) {
          // Check if cert is actually a Map before accessing keys
          if (cert is Map<String, dynamic> &&
              cert['bill_number'] == billNumber &&
              cert['financial_year'] == financialYear) {
            certificateData = cert; // Assign if checks pass
            break;
          }
        }
      } catch (e) {
        print("Error processing certificate list item during search: $e");
        // Rethrow or handle appropriately
        throw Exception("Internal error processing certificate data.");
      }

      if (certificateData == null) {
        throw Exception(
          'Certificate data not found locally for $billNumber / $financialYear',
        );
      }

      // Create a copy to avoid modifying the original list item state
      final Map<String, dynamic> dataForPdf = Map.from(certificateData);

      // Ensure amount is double for the generator (operate on the copy)
      final rawAmount = dataForPdf['amount']; // Check the raw value first
      if (rawAmount is int) {
        dataForPdf['amount'] = rawAmount.toDouble();
      } else if (rawAmount is String) {
        dataForPdf['amount'] = double.tryParse(rawAmount) ?? 0.0;
      } else if (rawAmount is double) {
        dataForPdf['amount'] = rawAmount; // Already double
      } else {
        // Handle null or other unexpected types
        print(
          "Warning: Certificate amount was null or unexpected type, defaulting to 0.0",
        );
        dataForPdf['amount'] = 0.0;
      }

      // Add similar checks for other critical fields if necessary (Example)
      dataForPdf['name'] = dataForPdf['name']?.toString() ?? 'N/A';
      dataForPdf['address'] = dataForPdf['address']?.toString() ?? '';
      dataForPdf['mobile_number'] =
          dataForPdf['mobile_number']?.toString() ?? '';
      dataForPdf['date'] =
          dataForPdf['date']?.toString() ?? ''; // Ensure date is string
      dataForPdf['trust'] = dataForPdf['trust']?.toString() ?? 'UNKNOWN';
      // Add checks for all fields used in pdf_generator.dart

      print("--- Data passed to generateCertificatePdf (View) ---");
      print(dataForPdf); // Print the processed data
      print("----------------------------------------------------");

      // 2. Generate the PDF bytes using the function with the processed copy
      final Uint8List pdfBytes = await generateCertificatePdf(dataForPdf);

      // 3. Get temporary directory
      final tempDir = await getTemporaryDirectory();

      // 3. Create a unique temporary file path using the correct format
      final trustName = certificateData['trust'] as String? ?? 'UNKNOWN';
      final trustAbbreviation =
          trustName == "PARAMANADI TRUST" ? "Paramanadi" : "Noolaatti";
      final safeBillNumber = billNumber.replaceAll('/', '_');
      final safeFinancialYear = financialYear.replaceAll(
        RegExp(r'[\\/*?:"<>|]'),
        '_',
      );
      final safeName = name
          .replaceAll(RegExp(r'[\\/*?:"<>|]'), '_')
          .replaceAll(' ', '_');
      // Use the correct format for the temporary filename as well
      final tempFilename =
          '${trustAbbreviation}_Receipt_${safeBillNumber}_${safeFinancialYear}_$safeName.pdf';
      tempFilePath = '${tempDir.path}/$tempFilename';
      final tempFile = File(tempFilePath);

      // 4. Write the generated bytes to the temporary file
      await tempFile.writeAsBytes(pdfBytes);

      // 5. Navigate to the viewer page (after closing loading dialog)
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
      print('Error generating or preparing PDF for viewing: $e');
      viewError = 'Could not generate/prepare PDF for viewing: ${e.toString()}';
      // Pop the dialog here if an error occurred before navigation attempt
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }

    // Show error message if viewing setup failed
    if (viewError != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(viewError)));
    }
  }

  // REVISED: Function to handle PERMANENT PDF download with permissions and specific folder
  Future<void> _downloadPdf(
    String billNumber,
    String financialYear,
    String name,
  ) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    final pdfPath =
        'certificates/$financialYear/${billNumber.replaceAll('/', '_')}.pdf';
    String? downloadError;

    try {
      // 1. Download the bytes from storage
      final Uint8List fileBytes = await Supabase.instance.client.storage
          .from('certificates')
          .download(pdfPath);

      // 2. Prepare filename
      Map<String, dynamic>? certificateDataForFilename;
      for (final cert in _certificates) {
        if (cert['bill_number'] == billNumber &&
            cert['financial_year'] == financialYear) {
          certificateDataForFilename = cert as Map<String, dynamic>;
          break;
        }
      }
      final trustName =
          certificateDataForFilename?['trust'] as String? ?? 'UNKNOWN';
      // Corrected typo and simplified abbreviation logic
      String trustAbbreviation =
          trustName == "PARAMANADI TRUST" ? "Paramanadi" : "Noolaatti";

      final safeBillNumber = billNumber.replaceAll('/', '_');
      // Ensure financialYear is safe for filenames (though usually like '2025-26', should be fine)
      final safeFinancialYear = financialYear.replaceAll(
        RegExp(r'[\\/*?:"<>|]'),
        '_',
      );
      final safeName = name
          .replaceAll(RegExp(r'[\\/*?:"<>|]'), '_')
          .replaceAll(' ', '_');
      // Updated filename format including the financial year
      final filename =
          '${trustAbbreviation}_Receipt_${safeBillNumber}_${safeFinancialYear}_$safeName.pdf';

      // 3. Detect Android version
      int sdkInt = 30;
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        sdkInt = androidInfo.version.sdkInt;
      }

      if (Platform.isAndroid && sdkInt >= 29) {
        // Android 10+ (API 29+): Use MediaStore to save to Downloads/Receipts
        // Write to temporary file first
        final tempDir = await getTemporaryDirectory();
        final tempFilePath = '${tempDir.path}/$filename';
        final tempFile = File(tempFilePath);
        await tempFile.writeAsBytes(fileBytes);

        // Use MediaStore to move the temp file to public Downloads/Receipts
        final mediaStore = MediaStore();
        await mediaStore.saveFile(
          tempFilePath: tempFilePath,
          dirType: DirType.download,
          dirName: DirName.download, // Save to root Downloads for now
        );
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'PDF saved to Downloads: $filename',
              ), // Update message
            ),
          );
        }
      } else if (Platform.isAndroid && sdkInt < 29) {
        // Android 9 and below: Request permission and save to Downloads/Receipts
        print(
          "Attempting download on Android 9 or below (SDK $sdkInt)... Requesting permission.",
        );
        PermissionStatus status = await Permission.storage.request();

        // Add a small delay in case the dialog needs time
        await Future.delayed(const Duration(milliseconds: 200));
        // Re-check status after requesting
        status = await Permission.storage.status;
        print("Permission status after request: $status");

        if (!status.isGranted) {
          print("Permission explicitly denied or restricted.");
          // Try opening settings if permanently denied
          if (status.isPermanentlyDenied && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Storage permission permanently denied. Please enable it in app settings.',
                ),
                duration: Duration(seconds: 5),
              ),
            );
            await openAppSettings(); // Requires permission_handler >= 6.0.0
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Storage permission denied. Cannot download file.',
                ),
              ),
            );
          }
          if (mounted)
            Navigator.of(context).pop(); // Close loading dialog before throwing
          throw Exception('Storage permission denied.');
        }

        print("Permission granted. Proceeding with save.");
        // Ensure the path exists
        final downloadsDir = Directory('/storage/emulated/0/Download/Receipts');
        try {
          if (!await downloadsDir.exists()) {
            print("Creating directory: ${downloadsDir.path}");
            await downloadsDir.create(recursive: true);
          }
        } catch (e) {
          print("Error creating directory: $e");
          if (mounted) Navigator.of(context).pop();
          throw Exception("Could not create download directory.");
        }

        final filePath = '${downloadsDir.path}/$filename';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

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
        await file.writeAsBytes(fileBytes);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF saved to app documents: $filename')),
          );
        }
      }
    } on StorageException catch (e) {
      downloadError = 'Storage error: ${e.message}';
      if (e.message.contains('Object not found')) {
        downloadError = 'PDF not found in storage.';
      }
      print('Error downloading PDF from storage: ${e.message}');
    } catch (e) {
      downloadError = downloadError ?? 'Could not save PDF: ${e.toString()}';
      print('Error saving PDF locally or other error: $e');
    } finally {
      // Ensure loading dialog is closed if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      // Show error message if download failed
      if (downloadError != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(downloadError)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reverted to original structure
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Receipts'), // Original Title
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchCertificates, // Original action
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search Receipts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        maxLines: 2,
                        minLines: 1,
                        decoration: InputDecoration(
                          labelText: 'Enter search term',
                          hintText: 'Search universal or specific columns',
                          prefixIcon: const Icon(Icons.search, size: 28),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          filled: true,
                          fillColor: Colors.blue[50],
                        ),
                        style: const TextStyle(fontSize: 16),
                        onChanged: (value) {
                          setState(() {
                            _search = value.trim();
                          });
                          _fetchCertificates();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedSearchColumn,
                        decoration: InputDecoration(
                          labelText: 'Search Column',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          filled: true,
                          fillColor: Colors.blue[50],
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: 'all',
                            child: Text('All Columns'),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'name',
                            child: Text('Name'),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'mobile_number',
                            child: Text('Mobile Number'),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'bill_number',
                            child: Text('Bill Number'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedSearchColumn = value ?? 'all';
                          });
                          _fetchCertificates();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedTrust,
                  decoration: InputDecoration(
                    labelText: 'Filter by Organisation',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    filled: true,
                    fillColor: Colors.blue[50],
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Organisations'),
                    ),
                    ..._trustOptions.map((String trust) {
                      return DropdownMenuItem<String>(
                        value: trust,
                        child: Text(trust),
                      );
                    }).toList(),
                  ],
                  onChanged: (newValue) {
                    setState(() {
                      _selectedTrust = newValue;
                    });
                    _fetchCertificates();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _certificates.isEmpty
                    ? const Center(
                      child: Text('No receipts found.'),
                    ) // Updated text
                    : ListView.builder(
                      itemCount: _certificates.length,
                      itemBuilder: (context, index) {
                        final certificate = _certificates[index];
                        // Safely access data with null checks
                        final billNumber =
                            certificate['bill_number'] as String? ?? 'N/A';
                        final financialYear =
                            certificate['financial_year'] as String? ?? 'N/A';
                        final name = certificate['name'] as String? ?? 'N/A';
                        final amount =
                            certificate['amount']?.toStringAsFixed(2) ??
                            '0.00'; // Format amount
                        final trust =
                            certificate['trust'] as String? ??
                            'Unknown Organisations';
                        final dateStr = certificate['date'] as String?;
                        String formattedDate = 'N/A';
                        if (dateStr != null) {
                          try {
                            // Assuming date is stored like 'dd-MM-yyyy' from home screen
                            final date = DateFormat(
                              'dd-MM-yyyy',
                            ).parse(dateStr);
                            formattedDate = DateFormat(
                              'dd-MMM-yyyy',
                            ).format(date); // Format as DD-Mon-YYYY
                          } catch (e) {
                            // Fallback for potential ISO format 'YYYY-MM-DD'
                            try {
                              final date = DateTime.parse(dateStr);
                              formattedDate = DateFormat(
                                'dd-MMM-yyyy',
                              ).format(date);
                            } catch (e2) {
                              print(
                                "Error parsing date (tried dd-MM-yyyy and ISO): $dateStr, Error: $e2",
                              );
                              formattedDate =
                                  dateStr; // Fallback to original string
                            }
                          }
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          child: ListTile(
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              // Use Column for multiple lines
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Receipt: $billNumber | Amount: ₹$amount'),
                                Text(
                                  'Org.: $trust | Date: $formattedDate',
                                ), // Add Trust and Date
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize:
                                  MainAxisSize.min, // Keep buttons compact
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.visibility,
                                    color: Colors.blue,
                                  ),
                                  tooltip: 'View PDF',
                                  // Disable button if needed info is missing
                                  onPressed:
                                      (billNumber == 'N/A' ||
                                              financialYear == 'N/A')
                                          ? null
                                          : () => _viewPdf(
                                            // Pass name as well
                                            billNumber,
                                            financialYear,
                                            name,
                                          ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.download,
                                    color: Colors.green,
                                  ),
                                  tooltip: 'Download PDF',
                                  // Disable button if needed info is missing
                                  onPressed:
                                      (billNumber == 'N/A' ||
                                              financialYear == 'N/A' ||
                                              name == 'N/A')
                                          ? null
                                          : () => _downloadPdf(
                                            billNumber,
                                            financialYear,
                                            name,
                                          ),
                                ),
                                IconButton(
                                  // ADD EDIT BUTTON
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.orange,
                                  ),
                                  tooltip: 'Edit Receipt',
                                  onPressed:
                                      (billNumber == 'N/A' ||
                                              financialYear == 'N/A')
                                          ? null
                                          : () {
                                            // Find the full certificate data again
                                            Map<String, dynamic>? certToEdit;
                                            for (final cert in _certificates) {
                                              if (cert
                                                      is Map<String, dynamic> &&
                                                  cert['bill_number'] ==
                                                      billNumber &&
                                                  cert['financial_year'] ==
                                                      financialYear) {
                                                certToEdit = cert;
                                                break;
                                              }
                                            }
                                            if (certToEdit != null) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) => HomeScreen(
                                                        initialData: certToEdit,
                                                      ),
                                                ),
                                              ).then(
                                                (_) => _fetchCertificates(),
                                              ); // Refresh list after returning
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Could not find certificate data to edit.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
