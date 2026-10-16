import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/constants/api_endpoints.dart';
import 'core/services/zendesk_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/error_detector.dart';
import 'features/settings/providers/pos_settings_provider.dart';
import 'routes/app_router.dart';

import 'core/providers/sync_providers.dart';
import 'core/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  
  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    await PushNotificationService.initialize();
  } catch (e) {
    debugPrint('Firebase/Notification initialization error: $e');
  }

  await ApiEndpoints.initialize();
  debugPrint('API base URL → ${ApiEndpoints.baseUrl}');

  // Initialize Zendesk
  await ZendeskService.initialize();

  // Initialize global error detection
  ErrorDetector.initialize();

  // Fix Status Bar globally
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Default black icons for white bg
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const ProviderScope(child: RetailVerseApp()));
}

class RetailVerseApp extends ConsumerWidget {
  const RetailVerseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize background sync service to listen for connectivity changes
    ref.watch(syncServiceProvider);
    
    final settings = ref.watch(posSettingsProvider);

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        });

        return MaterialApp.router(
          title: 'Retail Verse',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: scaffoldMessengerKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
          scrollBehavior: const _NoStretchScrollBehavior(),
          routerConfig: appRouter,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final fs = settings.fontScale;
            final safeFs =
                fs.isFinite && fs > 0 ? fs.clamp(0.8, 2.0) : 1.0;
            return Listener(
              onPointerDown: (event) {
                final currentFocus = FocusManager.instance.primaryFocus;
                if (currentFocus != null &&
                    currentFocus.context != null &&
                    currentFocus.context!.mounted) {
                  final renderObject = currentFocus.context!.findRenderObject();
                  if (renderObject is RenderBox && renderObject.hasSize) {
                    final position = renderObject.localToGlobal(Offset.zero);
                    final bounds = position & renderObject.size;
                    if (!bounds.contains(event.position)) {
                      currentFocus.unfocus();
                    }
                  }
                }
              },
              behavior: HitTestBehavior.translucent,
              child: MediaQuery(
                data: mq.copyWith(
                  textScaler: TextScaler.linear(safeFs),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
        );
      },
    );
  }
}

class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
