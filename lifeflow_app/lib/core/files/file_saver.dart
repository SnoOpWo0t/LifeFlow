/// Save downloaded bytes as a file the user can open.
/// Web: triggers a normal browser download. Mobile/desktop: writes to the
/// Downloads (or documents) folder and returns the file path.
export 'file_saver_io.dart' if (dart.library.js_interop) 'file_saver_web.dart';
