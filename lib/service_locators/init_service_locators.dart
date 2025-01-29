import 'package:get_it/get_it.dart';

import '../database/database.dart';
import 'app_database_service.dart';

final getIt = GetIt.instance;

void initServiceLocator() {
  getIt.registerSingleton<AppDatabase>(AppDatabaseService.database);
}
