import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../database/database.dart';
import '../sync/sync_manager.dart';
import '../services/background_save_queue_service.dart';
import '../services/analytics/analytics_facade.dart';
import '../services/analytics/logger_analytics_client.dart';
import 'app_database_service.dart';

final getIt = GetIt.instance;

void initServiceLocators() {
  getIt.registerSingleton<AppDatabase>(AppDatabaseService.database);
  getIt.registerSingleton<SyncManager>(SyncManager());
  getIt.registerSingleton<BackgroundSaveQueueService>(
    BackgroundSaveQueueService(),
  );
  getIt.registerSingleton<AnalyticsFacade>(
    AnalyticsFacade(
      logger: kDebugMode ? LoggerAnalyticsClient() : null,
    ),
  );
}
