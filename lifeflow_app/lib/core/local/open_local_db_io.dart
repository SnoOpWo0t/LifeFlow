import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

import 'local_db.dart';

Future<LocalDb> openLocalDb() async {
  final dir = await getApplicationSupportDirectory();
  return LocalDb.open(databaseFactoryIo, '${dir.path}/lifeflow.db');
}
