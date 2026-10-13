import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Returns the saved file's path so the app can tell the user where it went.
Future<String?> saveBytes(
  List<int> bytes,
  String filename,
  String mimeType,
) async {
  Directory? dir;
  try {
    dir = await getDownloadsDirectory();
  } catch (_) {
    // Not available on every platform.
  }
  dir ??= await getApplicationDocumentsDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
