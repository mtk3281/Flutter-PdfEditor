import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';

class FileFinder {
  static Future<PermissionStatus> checkPermissions() async {
    return await Permission.manageExternalStorage.request();
  }

  static Future<Map<String, List<String>>> findFiles(
      String directoryPath, List<String> extensions) async {
    final foundFiles = <String, List<String>>{};
    final extensionsSet = extensions.map((ext) => ext.toLowerCase()).toSet();

    if (!(await Directory(directoryPath).exists())) {
      print('Directory does not exist: $directoryPath');
      return foundFiles;
    }

    try {
      final entities = await Directory(directoryPath).list().toList();

      // Process each entity concurrently
      await Future.forEach(entities, (entity) async {
        if (entity is File) {
          final extension = entity.path.split('.').last.toLowerCase();
          if (foundFiles.containsKey(extension)) {
            foundFiles
                .putIfAbsent(extension, () => [])
                .add(entity.path); // Add to extension-specific list
          }
        } else if (entity is Directory) {
          try {
            final subPaths = await findFiles(entity.path, extensions);
            for (var ext in subPaths.keys) {
              foundFiles
                  .putIfAbsent(ext, () => [])
                  .addAll(subPaths[ext]!); // Merge subdirectory results
            }
          } catch (e) {
            print('Skipping inaccessible directory: ${entity.path}');
          }
        }
      });
    } catch (e) {
      print('Error while listing directory contents: $e');
    }
    return foundFiles;
  }
}
