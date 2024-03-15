import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class PdfFinder {
  static Future<PermissionStatus> checkPermissions() async {
    return await Permission.storage.request();
  }

  static Future<List<String>> findPdfFiles(String directoryPath) async {
    List<String> foundPdfPaths = [];
    if (!Directory(directoryPath).existsSync()) {
      print('Directory does not exist: $directoryPath');
      return foundPdfPaths;
    }
    try {
      final entities = await Directory(directoryPath).list();
      await for (var entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          foundPdfPaths.add(entity.path);
        } else if (entity is Directory) {
          try {
            await entity.list().toList();
            List<String> subPaths = await findPdfFiles(entity.path);
            foundPdfPaths.addAll(subPaths);
          } catch (e) {
            print('Skipping inaccessible directory: ${entity.path}');
          }
        }
      }
    } catch (e) {
      print('Error while listing directory contents: $e');
    }
    return foundPdfPaths;
  }
}
