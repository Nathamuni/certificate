import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

Future<bool> requestStoragePermission() async {
  if (!Platform.isAndroid) return true;

  final androidInfo = await DeviceInfoPlugin().androidInfo;
  // Request standard storage permission for all relevant Android versions
  // Note: For Android 11+ (API 30+), direct access to Downloads might be restricted.
  // Saving to app-specific directory (getApplicationDocumentsDirectory) is more reliable
  // or use MediaStore API for public Downloads folder.
  // However, requesting Permission.storage often works for Downloads on many devices/versions.

  var status = await Permission.storage.request();

  if (status.isPermanentlyDenied) {
    // Optional: Guide user to settings if permanently denied
    // openAppSettings();
    print("Storage permission permanently denied.");
  }

  return status.isGranted;
}
