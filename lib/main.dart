import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'auth/splash_screen.dart';
import 'deliveries/delivery_detail_screen.dart';
import 'deliveries/entregas_service.dart';
import 'deliveries/navigation_live_update.dart';
import 'notifications/notificaciones_screen.dart';
import 'notifications/onesignal_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

/// So [_handleNotificationClick]/[_handleRouteNotificationTap] can push a
/// screen from a notification tap, which fires outside any screen's own
/// `BuildContext` (app closed, backgrounded, or cold-started straight from
/// the tap).
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OneSignalService.initialize();
  OneSignalService.registerClickListener(_handleNotificationClick);
  // Warm-resume case for the Android Live Update notification (see
  // NavigationLiveUpdate) — the app was already running, so MainActivity
  // pushes this straight away via onNewIntent rather than Dart having to
  // poll for it.
  NavigationLiveUpdate.registerNotificationTapListener(_handleRouteNotificationTap);
  runApp(const MyApp());
  // Cold-start case: this app instance may have just been launched by
  // tapping that same notification — ask once now that the widget tree is
  // building (see NavigationLiveUpdate.consumeLaunchRemisionId for why this
  // can't just be pushed from native like the warm-resume case above).
  final remisionId = await NavigationLiveUpdate.consumeLaunchRemisionId();
  if (remisionId != null) _handleRouteNotificationTap(remisionId);
}

/// Backend doesn't send `referenciaTipo`/`referenciaId` on the push payload
/// yet (see `OneSignalService.registerClickListener`), so there's nothing
/// to deep-link to — this opens the in-app notification inbox instead of
/// leaving the tap a no-op, and can branch on `referenciaTipo`/`referenciaId`
/// once the backend adds them.
Future<void> _handleNotificationClick(String? referenciaTipo, String? referenciaId) async {
  final nav = await _navigatorReady();
  nav?.push(MaterialPageRoute(builder: (_) => const NotificacionesScreen()));
}

/// Deep-links the Android Live Update notification (see
/// `deliveries/navigation_live_update.dart`) to that delivery's detail
/// screen — reconnecting straight into the live map/guidance session isn't
/// attempted (uncertain whether the Navigation SDK can safely resume one),
/// so this is as close as tapping the notification gets; "Regresar a la
/// ruta" from here re-opens the map normally. A remisión that can no longer
/// be resolved (deleted, network hiccup) just leaves the tap a no-op rather
/// than showing a broken screen.
Future<void> _handleRouteNotificationTap(int remisionId) async {
  final nav = await _navigatorReady();
  if (nav == null) return;
  try {
    final remision = await EntregasService.remisionPorId(remisionId);
    if (remision == null) return;
    nav.push(MaterialPageRoute(builder: (_) => DeliveryDetailScreen(remision: remision)));
  } catch (_) {}
}

/// A cold start via notification tap can deliver before `runApp`'s first
/// frame attaches the navigator — wait briefly rather than drop it.
Future<NavigatorState?> _navigatorReady() async {
  var nav = navigatorKey.currentState;
  var attempts = 0;
  while (nav == null && attempts < 20) {
    await Future.delayed(const Duration(milliseconds: 100));
    nav = navigatorKey.currentState;
    attempts++;
  }
  return nav;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'FN Concretos',
          theme: ThemeData(
            fontFamily: 'Roboto',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFFCC00),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.grey[50],
          ),
          darkTheme: ThemeData(
            fontFamily: 'Roboto',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFFCC00),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF121212),
          ),
          themeMode: currentMode,
          debugShowCheckedModeBanner: false,
          // App copy is hardcoded Spanish everywhere already — force the
          // locale to match instead of following the device's, so things
          // like the date picker calendar aren't in English out of the box.
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
        );
      },
    );
  }
}
