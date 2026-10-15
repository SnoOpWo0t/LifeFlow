import 'package:sembast_web/sembast_web.dart';

import 'local_db.dart';

Future<LocalDb> openLocalDb() => LocalDb.open(databaseFactoryWeb, 'lifeflow');
