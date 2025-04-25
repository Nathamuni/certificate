import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// import 'package:number_to_words_english/number_to_words_english.dart'; // REMOVE incorrect package
// import 'package:indian_currency_to_word/indian_currency_to_word.dart' as icw; // REVERTING: Remove import for now

// Function to generate the certificate PDF
Future<Uint8List> generateCertificatePdf(Map<String, dynamic> data) async {
  final pdf = pw.Document();

  // --- Load Assets ---
  final regularFontData = await rootBundle.load(
    "assets/fonts/OpenSans-Regular.ttf",
  );
  final regularFont = pw.Font.ttf(regularFontData);
  final boldFontData = await rootBundle.load("assets/fonts/OpenSans-Bold.ttf");
  final boldFont = pw.Font.ttf(boldFontData);

  final headerImageData = await rootBundle.load(
    'assets/images/Thirumankaappu - Jeeyar matam_20250402_134630_0000.png',
  );
  final signImageData = await rootBundle.load('assets/images/sign.png');
  final logo1Data = await rootBundle.load('assets/images/logo.png');
  final logo2Data = await rootBundle.load('assets/images/logo2.png');

  final headerImage = pw.MemoryImage(headerImageData.buffer.asUint8List());
  final signImage = pw.MemoryImage(signImageData.buffer.asUint8List());
  final logo1 = pw.MemoryImage(logo1Data.buffer.asUint8List());
  final logo2 = pw.MemoryImage(logo2Data.buffer.asUint8List());

  final selectedLogo = data['trust'] == "PARAMANADI TRUST" ? logo2 : logo1;
  final trustTitle = (data['trust'] as String?)?.toUpperCase() ?? '';

  // --- Define Styles (Significantly Increased Sizes) ---
  final baseStyle = pw.TextStyle(
    font: regularFont,
    fontSize: 14,
  ); // Increased base
  final boldStyle = pw.TextStyle(
    font: boldFont,
    fontSize: 14,
  ); // Increased base
  final headerSymbolStyle = pw.TextStyle(
    font: regularFont,
    fontSize: 18,
  ); // Increased
  final headerMainStyle = pw.TextStyle(
    font: boldFont, // Use bold for main header
    fontSize: 18, // Increased significantly
    fontWeight: pw.FontWeight.bold,
  );
  final trustTitleStyle = pw.TextStyle(
    font: boldFont,
    fontSize: 18, // Slightly reduced to accommodate larger logo
  );
  final addressStyle = pw.TextStyle(
    font: regularFont,
    fontSize: 14, // Increased significantly
  );
  final linkStyle = pw.TextStyle(
    font: regularFont,
    fontSize: 14, // Increased significantly
    color: PdfColors.blue,
    decoration: pw.TextDecoration.underline,
  );
  // **STYLE for Donation Receipt Title** (Kept relatively smaller)
  final receiptDetailsTitleStyle = pw.TextStyle(
    font: boldFont,
    fontSize: 18, // Kept moderate, smaller than Trust Title
    fontWeight: pw.FontWeight.bold,
  );
  final billLabelStyle = pw.TextStyle(
    font: boldFont,
    fontSize: 16, // Increased significantly
  );
  final billValueStyle = pw.TextStyle(
    font: regularFont,
    fontSize: 16, // Increased significantly
  );
  final userLabelStyle = pw.TextStyle(
    font: boldFont,
    fontSize: 15, // Slightly reduced
  );
  final userValueStyle = pw.TextStyle(
    font: regularFont,
    fontSize: 15, // Slightly reduced
  );
  final signatureTextStyle = pw.TextStyle(
    font: boldFont,
    fontSize: 12,
  ); // Increased
  final footerStyle = pw.TextStyle(
    font: regularFont,
    fontSize: 10,
  ); // Increased

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      // --- Header Builder (Now Empty) ---
      header: (pw.Context context) {
        // Return an empty container to avoid repeating header content
        return pw.Container();
      },
      // --- Footer Builder (Now Empty) ---
      footer: (pw.Context context) {
        // Return an empty container to avoid repeating footer content
        return pw.Container();
      },
      // --- Build Function (Content flows across pages) ---
      build: (pw.Context context) {
        // --- Prepare Amount (Get value once) ---
        double? amountValue = data['amount'] as double?;
        if (amountValue == 0) {
          amountValue = null;
        }
        // REVERTING: Removed amountInWords calculation for now

        // Return a list of widgets for the main content body
        return <pw.Widget>[
          // --- START: Moved Header Content ---
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // --- Top Header ---
              pw.Center(child: pw.Text('Sri:', style: headerSymbolStyle)),
              pw.Center(
                child: pw.Text(
                  'Srimathe Ramanujaya Namaha',
                  style: headerMainStyle,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Center(child: pw.Image(headerImage, height: 70)),
              pw.SizedBox(height: 10),
              // --- Trust Info Header ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.start,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: data['trust'] == "PARAMANADI TRUST" ? 140 : 190,
                    height: data['trust'] == "PARAMANADI TRUST" ? 140 : 190,
                    margin: const pw.EdgeInsets.only(right: 20),
                    child: pw.Image(selectedLogo, fit: pw.BoxFit.contain),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Center(
                        child: pw.Text(trustTitle, style: trustTitleStyle),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Center(
                        child: pw.Text(
                          '1-39/1-32, Agraharam Street,\nThiruvellarai, Trichy-621009.',
                          style: addressStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Center(
                        child: pw.Text(
                          'E-Mail: secretary@paramanadi.org',
                          style: addressStyle,
                        ),
                      ),
                      pw.Center(
                        child: pw.UrlLink(
                          destination:
                              data['trust'] == "PARAMANADI TRUST"
                                  ? 'https://www.paramanadi.org/'
                                  : 'https://www.paramanadi.org/noolaatti/',
                          child: pw.Text(
                            data['trust'] == "PARAMANADI TRUST"
                                ? 'https://www.paramanadi.org'
                                : 'https://www.paramanadi.org/noolaatti',
                            style: linkStyle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Conditional spacing based on trust
              pw.SizedBox(
                height:
                    data['trust'] == "NOOLAATTI PALA KALAI ORPPU MAIYAM"
                        ? 2
                        : 5,
              ),
            ],
          ),
          // --- END: Moved Header Content ---

          // --- Donation Receipt Title ---
          pw.Center(
            child: pw.Text('Donation Receipt', style: receiptDetailsTitleStyle),
          ),
          pw.SizedBox(height: 5), // Reduced spacing
          // --- Divider ---
          pw.Divider(
            height: 1,
            thickness: 1.5, // Slightly thicker divider
          ),
          pw.SizedBox(height: 3), // Further reduced spacing
          // --- Receipt Number and Date ---
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Receipt No. : ${data['bill_number']}',
                style: billLabelStyle,
              ),
              pw.Text('Date: ${data['date']}', style: billLabelStyle),
            ],
          ),
          pw.SizedBox(height: 4), // Further reduced spacing
          // --- Donor Details ---
          _buildDetailRow(
            'Name of the Donor',
            data['name'] ?? '',
            userLabelStyle,
            userValueStyle,
          ),
          _buildDetailRow(
            'Address',
            data['address'] ?? '',
            userLabelStyle,
            userValueStyle,
          ),
          _buildDetailRow(
            'Mobile Number',
            data['mobile_number'] ?? '',
            userLabelStyle,
            userValueStyle,
          ),
          if (data['offering_type'] != null && data['offering_type'].isNotEmpty)
            _buildDetailRow(
              'Nature of Donation',
              data['offering_type'],
              userLabelStyle,
              userValueStyle,
            ),
          if (data['purpose'] != null && data['purpose'].isNotEmpty)
            _buildDetailRow(
              'Purpose of Donation',
              data['purpose'],
              userLabelStyle,
              userValueStyle,
            ),
          // Conditional Amount Row
          if (amountValue != null && amountValue > 0)
            _buildDetailRow(
              'Amount',
              'Rs. ${amountValue.toStringAsFixed(2)}',
              userLabelStyle,
              userValueStyle,
            ),
          _buildDetailRow(
            'Mode of Donation',
            data['transfer_mode'] ?? '',
            userLabelStyle,
            userValueStyle,
          ),
          if (data['transfer_mode'] == 'Cheque' &&
              data['cheque_number'] != null &&
              data['cheque_number'].isNotEmpty)
            _buildDetailRow(
              'Cheque Number',
              data['cheque_number'],
              userLabelStyle,
              userValueStyle,
            ),
          if (data['transfer_mode'] == 'Cheque' &&
              data['bank'] != null &&
              data['bank'].isNotEmpty)
            _buildDetailRow(
              'Bank',
              data['bank'],
              userLabelStyle,
              userValueStyle,
            ),
          if (data['other_remarks'] != null && data['other_remarks'].isNotEmpty)
            _buildDetailRow(
              'Remarks',
              data['other_remarks'],
              userLabelStyle,
              userValueStyle,
            ),

          // --- Amount in Words and Signature ---
          pw.SizedBox(height: 20), // Add some space before this section
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              // Left side: Received text and Amount in words (conditional)
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Received With Thanks', style: userLabelStyle),
                    // Add amount in words if amount is greater than 0
                    if (amountValue != null && amountValue > 0)
                      pw.Container(
                        decoration: pw.BoxDecoration(border: pw.Border.all()),
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              '${formatIndianCurrency(amountValue)} Only',
                              style: boldStyle,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 20), // Space between left and right
              // Right side: Signature
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Regards', style: signatureTextStyle),
                  pw.SizedBox(height: 5),
                  pw.Container(
                    width: 100,
                    height: 50,
                    child: pw.Image(signImage, fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'R. Ranganathan, Secretary',
                    style: signatureTextStyle,
                  ),
                ], // End Children of Right Column
              ), // End Right Column
            ], // End Children of Row
          ), // End Row <-- ADDED MISSING PARENTHESIS HERE
          // --- START: Moved Footer Content ---
          // Add a spacer to push the footer to the bottom if needed,
          // but MultiPage usually handles this. Let's add it just in case.
          pw.Spacer(), // Pushes content below it to the end of the page/document
          pw.Divider(thickness: 0.5),
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(
              'Front Desk: +91 93456 12860 | Admin: +91 93455 70750 | Secretary: +91 8838850650',
              style: footerStyle,
            ),
          ),

          // --- END: Moved Footer Content ---
        ]; // End of build list
      }, // End of build function
    ), // End of MultiPage
  ); // End of pdf.addPage

  return pdf.save();
}

String formatIndianCurrency(double amount) {
  if (amount > 9999999) {
    return "Amount too large";
  }

  // Helper maps for number to words conversion
  const unitsMap = {
    0: 'Zero',
    1: 'One',
    2: 'Two',
    3: 'Three',
    4: 'Four',
    5: 'Five',
    6: 'Six',
    7: 'Seven',
    8: 'Eight',
    9: 'Nine',
    10: 'Ten',
    11: 'Eleven',
    12: 'Twelve',
    13: 'Thirteen',
    14: 'Fourteen',
    15: 'Fifteen',
    16: 'Sixteen',
    17: 'Seventeen',
    18: 'Eighteen',
    19: 'Nineteen',
  };

  const tensMap = {
    2: 'Twenty',
    3: 'Thirty',
    4: 'Forty',
    5: 'Fifty',
    6: 'Sixty',
    7: 'Seventy',
    8: 'Eighty',
    9: 'Ninety',
  };

  String twoDigitToWords(int n) {
    if (n < 20) {
      return unitsMap[n]!;
    }
    int tens = n ~/ 10;
    int units = n % 10;
    if (units == 0) {
      return tensMap[tens]!;
    }
    return '${tensMap[tens]!} ${unitsMap[units]!}';
  }

  String threeDigitToWords(int n) {
    int hundreds = n ~/ 100;
    int remainder = n % 100;
    String result = '';
    if (hundreds > 0) {
      result = '${unitsMap[hundreds]!} Hundred';
      if (remainder > 0) {
        result += ' and ';
      }
    }
    if (remainder > 0) {
      result += twoDigitToWords(remainder);
    }
    return result;
  }

  List<String> parts = ['A sum of Rupees'];

  int lakhs = (amount ~/ 100000);
  if (lakhs > 0) {
    parts.add('${threeDigitToWords(lakhs)} Lakh${lakhs > 1 ? 's' : ''}');
    amount = amount % 100000;
  }

  int thousands = (amount ~/ 1000);
  if (thousands > 0) {
    parts.add('${threeDigitToWords(thousands)} Thousand');
    amount = amount % 1000;
  }

  int hundreds = (amount ~/ 100);
  if (hundreds > 0) {
    parts.add('${unitsMap[hundreds]!} Hundred');
    amount = amount % 100;
  }

  int remainder = amount.toInt();
  if (remainder > 0) {
    if (parts.length > 1) {
      parts.add('and');
    }
    parts.add(twoDigitToWords(remainder));
  }

  return parts.join(' ');
}

// Helper function remains unchanged
pw.Widget _buildDetailRow(
  String label,
  String value,
  pw.TextStyle labelStyle,
  pw.TextStyle valueStyle,
) {
  if (label == 'Amount' && value == 'Rs. 0.00') {
    return pw.SizedBox(); // Return empty SizedBox if amount is 0
  }
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(
      vertical: 1.5, // Reduced vertical padding
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Increased width significantly for larger font
        pw.SizedBox(
          width: 170,
          child: pw.Text(label, style: labelStyle),
        ), // Increased width
        pw.Text(':  ', style: labelStyle), // Added space after colon
        pw.Expanded(child: pw.Text(value, style: valueStyle)),
      ],
    ),
  );
}

// REMOVED Custom Indian Word Formatting Function
