import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart'; // For PDF viewing
import 'package:share_plus/share_plus.dart'; // For sharing

class PdfViewerPage extends StatefulWidget {
  final String filePath;

  const PdfViewerPage({super.key, required this.filePath});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  late PdfControllerPinch _pdfController;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePdf();
  }

  Future<void> _initializePdf() async {
    try {
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(widget.filePath),
      );
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading PDF: $e");
      setState(() {
        _error = "Failed to load PDF: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    // Attempt to delete the temporary file when the viewer is closed
    try {
      final tempFile = File(widget.filePath);
      if (tempFile.existsSync()) {
        tempFile.delete();
        print("Deleted temporary file: ${widget.filePath}");
      }
    } catch (e) {
      print("Error deleting temporary file: $e");
    }
    super.dispose();
  }

  Future<void> _sharePdf() async {
    try {
      final file = XFile(widget.filePath); // share_plus uses XFile
      await Share.shareXFiles([file], text: 'Sharing Certificate Receipt');
    } catch (e) {
      print("Error sharing PDF: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing PDF: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Viewer'),
        actions: [
          if (!_isLoading && _error == null) // Only show share if PDF loaded
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share PDF',
              onPressed: _sharePdf,
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text('Error: $_error'))
              : PdfViewPinch(controller: _pdfController),
    );
  }
}
