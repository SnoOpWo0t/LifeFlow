/// Opens the device's database: a file in the app's private folder on
/// Android/desktop, IndexedDB in the browser.
library;

export 'open_local_db_io.dart'
    if (dart.library.js_interop) 'open_local_db_web.dart';
