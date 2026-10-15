import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/constants/app_config.dart';
import 'data/repositories/badge_repository.dart';
import 'data/repositories/catalogue_repository.dart';
import 'data/repositories/library_repository.dart';
import 'data/repositories/planner_repository.dart';
import 'data/repositories/question_repository.dart';
import 'data/repositories/quiz_history_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/streak_repository.dart';
import 'data/sources/local/hive_store.dart';
import 'data/sources/remote/firebase_bootstrap.dart';
import 'data/sources/remote/firestore_catalogue_source.dart';
import 'data/sources/remote/firestore_question_source.dart';
import 'data/sources/remote/storage_file_source.dart';
import 'services/ad_service.dart';
import 'services/analytics_service.dart';
import 'services/badge_service.dart';
import 'services/download_service.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';
import 'services/planner_service.dart';
import 'services/streak_service.dart';
import 'state/catalogue_controller.dart';
import 'state/library_controller.dart';
import 'state/planner_controller.dart';
import 'state/quiz_controller.dart';
import 'state/shell_controller.dart';
import 'state/settings_controller.dart';
import 'state/streak_controller.dart';

/// Application entry point.
///
/// Startup order matters:
///   1. bindings + orientation + date symbols (needed by `intl` for si/ta)
///   2. Firebase (optional, never fatal)
///   3. Hive boxes
///   4. build repositories -> services -> controllers
///   5. `runApp`, then kick off catalogue/streak warm-up in the background so the
///      first frame is never blocked by the network.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Sinhala (si) and Tamil (ta) month/day names for `DateFormat`.
  await initializeDateFormatting();

  final AppDependencies deps = await AppDependencies.create();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsController>.value(value: deps.settings),
        ChangeNotifierProvider<CatalogueController>.value(value: deps.catalogue),
        ChangeNotifierProvider<LibraryController>.value(value: deps.library),
        ChangeNotifierProvider<StreakController>.value(value: deps.streak),
        ChangeNotifierProvider<PlannerController>.value(value: deps.planner),
        ChangeNotifierProvider<QuizController>.value(value: deps.quiz),
        // The download service is exposed directly (it is a ChangeNotifier used
        // by cards for per-item progress) as well as through LibraryController.
        Provider<DownloadService>.value(value: deps.downloads),
        ChangeNotifierProvider<ShellController>(create: (_) => ShellController()),
        // Exposed so Settings can perform a genuine "erase everything" (every
        // Hive box), not just a cache clear.
        Provider<HiveStore>.value(value: deps.store),
      ],
      child: const SriEduApp(),
    ),
  );
}

/// Everything the widget tree needs, constructed once.
///
/// Hand-rolled dependency injection (no `get_it`) keeps the graph visible in one
/// place and costs nothing at runtime.
class AppDependencies {
  AppDependencies._({
    required this.settings,
    required this.catalogue,
    required this.library,
    required this.streak,
    required this.planner,
    required this.quiz,
    required this.downloads,
    required this.store,
  });

  final SettingsController settings;
  final CatalogueController catalogue;
  final LibraryController library;
  final StreakController streak;
  final PlannerController planner;
  final QuizController quiz;
  final DownloadService downloads;
  final HiveStore store;

  static Future<AppDependencies> create() async {
    // 1. Firebase (no-op unless USE_FIREBASE=true).
    final bool firebaseUp = await FirebaseBootstrap.initialise();
    AnalyticsService.instance.configure();
    debugPrint('[SriEdu] firebase=$firebaseUp adsEnabled=${AppConfig.adsEnabled}');

    // 2. Storage.
    final HiveStore store = await HiveStore.open();

    // 3. Repositories.
    final SettingsRepository settingsRepo = SettingsRepository(store);
    final LibraryRepository libraryRepo = LibraryRepository(store);
    final StreakRepository streakRepo = StreakRepository(store);
    final BadgeRepository badgeRepo = BadgeRepository(store);
    final QuizHistoryRepository quizHistoryRepo = QuizHistoryRepository(store);
    final PlannerRepository plannerRepo = PlannerRepository(store);
    final CatalogueRepository catalogueRepo = CatalogueRepository(
      store: store,
      remote: AppConfig.useFirebase ? FirestoreCatalogueSource() : null,
    );
    final QuestionRepository questionRepo = QuestionRepository(
      remote: AppConfig.useFirebase ? FirestoreQuestionSource() : null,
    );

    // 4. Services.
    final NotificationService notifications = NotificationService();
    await notifications.initialise();

    final PlannerService plannerService = PlannerService(
      repository: plannerRepo,
      notifications: notifications,
    );
    final StreakService streakService = StreakService(streakRepo);
    final BadgeService badgeService = BadgeService(
      badges: badgeRepo,
      quizHistory: quizHistoryRepo,
      library: libraryRepo,
      planner: plannerRepo,
    );

    final AdService ads = AdService.instance;
    await ads.initialise();

    // `streakController` is referenced by the badge callback below but created
    // afterwards: the closure only runs at download time, so `late` is safe here.
    late final StreakController streakController;
    final DownloadService downloadService = DownloadService(
      library: libraryRepo,
      settings: settingsRepo,
      files: StorageFileSource(),
      ads: ads,
      onBadgeCheck: () => streakController.checkBadges(),
    );

    final FcmService fcm = FcmService(notifications: notifications);
    unawaited(fcm.initialise());

    // 5. Controllers.
    final SettingsController settingsController = SettingsController(
      repository: settingsRepo,
      planner: plannerService,
      fcm: fcm,
    );
    final CatalogueController catalogueController =
        CatalogueController(catalogueRepo);
    final LibraryController libraryController = LibraryController(
      repository: libraryRepo,
      catalogue: catalogueRepo,
      downloads: downloadService,
    );
    streakController = StreakController(
      streak: streakService,
      badges: badgeService,
      catalogue: catalogueRepo,
    );
    final PlannerController plannerController = PlannerController(plannerService);
    final QuizController quizController = QuizController(
      questions: questionRepo,
      history: quizHistoryRepo,
    );

    // 6. Warm-up: fire and forget. The UI shows skeletons until these resolve,
    //    and none of them can throw into the widget tree.
    unawaited(catalogueController.load());
    unawaited(streakController.initialise());
    unawaited(libraryController.refreshStorage());
    unawaited(ads.preloadInterstitial());

    return AppDependencies._(
      settings: settingsController,
      catalogue: catalogueController,
      library: libraryController,
      streak: streakController,
      planner: plannerController,
      quiz: quizController,
      downloads: downloadService,
      store: store,
    );
  }
}
