import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';

class FileFinder {
  // Renamed class for broader functionality

  static Future<PermissionStatus> checkPermissions() async {
    return await Permission.manageExternalStorage.request();
  }

  static Future<List<String>> findFiles(
      String directoryPath, List<String> extensions) async {
    List<String> foundFilePaths = [];
    if (!(await Directory(directoryPath).exists())) {
      print('Directory does not exist: $directoryPath');
      return foundFilePaths;
    }

    try {
      final entities = await Directory(directoryPath).list().toList();

      // Process each entity concurrently
      await Future.forEach(entities, (entity) async {
        if (entity is File) {
          final extension = entity.path.split('.').last.toLowerCase();
          if (extensions.contains(extension)) {
            foundFilePaths.add(entity.path);
          }
        } else if (entity is Directory) {
          try {
            final subPaths = await findFiles(entity.path, extensions);
            foundFilePaths.addAll(subPaths);
          } catch (e) {
            print('Skipping inaccessible directory: ${entity.path}');
          }
        }
      });
    } catch (e) {
      print('Error while listing directory contents: $e');
    }
    return foundFilePaths;
  }
}
