import 'package:get_it/get_it.dart';

import '../database/database.dart';
import 'app_database_service.dart';

final getIt = GetIt.instance;

void initServiceLocators() {
  getIt.registerSingleton<AppDatabase>(AppDatabaseService.database);
}
