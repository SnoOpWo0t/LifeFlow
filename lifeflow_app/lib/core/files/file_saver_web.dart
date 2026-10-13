import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Returns null: the browser shows its own download notification.
Future<String?> saveBytes(
  List<int> bytes,
  String filename,
  String mimeType,
) async {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body!.append(link);
  link.click();
  link.remove();
  web.URL.revokeObjectURL(url);
  return null;
}
