import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';

class PdfFinder {
  static Future<PermissionStatus> checkPermissions() async {
    // AwesomeDialog(
    //                   context: BuildContext(' Please Grant Permission '),
    //                   dialogType: DialogType.info,
    //                   borderSide: const BorderSide(
    //                     color: Colors.green,
    //                     width: 2,
    //                   )
    return await Permission.manageExternalStorage.request();
    // return await Permission.storage.request();
  }

  static Future<List<String>> findPdfFiles(String directoryPath) async {
    List<String> foundPdfPaths = [];
    if (!Directory(directoryPath).existsSync()) {
      print('Directory does not exist: $directoryPath');
      return foundPdfPaths;
    }
    try {
      final entities = Directory(directoryPath).list();
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
