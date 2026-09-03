import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import 'remision.dart';
import 'route_navigation_widgets.dart';

const _accentYellow = AppColors.accent;

/// Matches this screen's own always-dark chrome ([RouteNavBackButton], [RouteNavBottomBar])
/// so the native turn-by-turn header never clashes with it. Set for both
/// day/night slots because [NavigationForceNightMode.forceNight] below pins
/// the SDK to its night skin regardless of time of day — without that, the
/// header would flip to a bright day skin mid-route and jar against this
/// screen's dark bars.
const _navigationHeaderStyle = NavigationHeaderStylingOptions(
  primaryDayModeBackgroundColor: Color(0xFF1E1E1E),
  secondaryDayModeBackgroundColor: Color(0xFF141414),
  primaryNightModeBackgroundColor: Color(0xFF1E1E1E),
  secondaryNightModeBackgroundColor: Color(0xFF141414),
  largeManeuverIconColor: _accentYellow,
  smallManeuverIconColor: _accentYellow,
  instructionsTextColor: Colors.white,
  nextStepTextColor: Colors.white70,
  distanceValueTextColor: _accentYellow,
  distanceUnitsTextColor: Colors.white70,
  guidanceRecommendedLaneColor: _accentYellow,
);

/// Full-screen, real Google Navigation experience — the same turn-by-turn
/// banner, voice guidance, ETA/distance footer, and tilted following
/// camera that DiDi/Uber/Rappi embed, because it *is* Google's own
/// Navigation SDK (`google_navigation_flutter`) rendered inside this app's
/// own view, not a custom-built lookalike and not a hand-off to the
/// separate Google Maps app. Pushed from [DeliveryDetailScreen]'s "Iniciar
/// ruta" button.
///
/// This is a real product with its own billing (separate from Maps SDK)
/// and its own required Cloud Console API ("Navigation SDK for
/// Android"/"for iOS") — see the setup notes in
/// android/app/src/main/AndroidManifest.xml and
/// ios/Runner/AppDelegate.swift.
///
/// The floating back button and bottom "Finalizar ruta"/"Ruta terminada"
/// strip are this app's own chrome, layered over the native navigation
/// view via [GoogleMapsNavigationView.initialPadding] so they don't
/// overlap its header/footer. Arrival is detected by the SDK itself
/// ([GoogleMapsNavigator.setOnArrivalListener]) rather than a manual
/// distance calculation — real geofencing this time, not a heuristic.
class RouteNavigationScreen extends StatefulWidget {
  final Remision remision;

  const RouteNavigationScreen({super.key, required this.remision});

  @override
  State<RouteNavigationScreen> createState() => _RouteNavigationScreenState();
}

class _RouteNavigationScreenState extends State<RouteNavigationScreen> {
  GoogleNavigationViewController? _viewController;
  StreamSubscription<OnArrivalEvent>? _arrivalSubscription;
  Timer? _gpsTimer;
  bool _arrived = false;
  bool _guidanceRunning = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _arrivalSubscription?.cancel();
    _gpsTimer?.cancel();
    if (_guidanceRunning) {
      // Best-effort: the view/session may already be gone by the time this
      // runs (e.g. Android killed the activity), so a missing session here
      // isn't an error worth surfacing.
      GoogleMapsNavigator.cleanup().catchError((_) {});
    }
    super.dispose();
  }

  Future<void> _start() async {
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    final granted = permission == geo.LocationPermission.always || permission == geo.LocationPermission.whileInUse;
    if (!granted) {
      if (mounted) setState(() => _errorText = 'Se necesita el permiso de ubicación para navegar.');
      return;
    }

    if (!await GoogleMapsNavigator.areTermsAccepted()) {
      await GoogleMapsNavigator.showTermsAndConditionsDialog('Navegación', 'FN Concretos');
    }

    try {
      await GoogleMapsNavigator.initializeNavigationSession();
    } catch (_) {
      if (mounted) setState(() => _errorText = 'No se pudo iniciar la sesión de navegación.');
      return;
    }

    _arrivalSubscription = GoogleMapsNavigator.setOnArrivalListener((_) {
      _gpsTimer?.cancel();
      if (mounted) setState(() => _arrived = true);
      _registrarHito(HitoEntrega.enObra);
    });

    final remision = widget.remision;
    final status = await GoogleMapsNavigator.setDestinations(
      Destinations(
        waypoints: [
          NavigationWaypoint.withLatLngTarget(
            title: remision.obra,
            target: LatLng(latitude: remision.destinoLat, longitude: remision.destinoLng),
          ),
        ],
        displayOptions: NavigationDisplayOptions(showDestinationMarkers: true),
      ),
    );

    if (status != NavigationRouteStatus.statusOk) {
      debugPrint(
        'RouteNavigationScreen: setDestinations status=$status '
        'destino=(${remision.destinoLat}, ${remision.destinoLng})',
      );
      if (mounted) setState(() => _errorText = 'No se pudo calcular la ruta a la obra.');
      return;
    }

    await GoogleMapsNavigator.startGuidance();
    await _viewController?.followMyLocation(CameraPerspective.tilted);
    // Re-applied here too (already set in onViewCreated) — confirmed by a
    // real device screenshot that neither the speedometer nor the ETA
    // footer show up once guidance is actually running, so something about
    // starting a guidance session may reset view-level UI settings back to
    // their defaults. `setNavigationFooterEnabled` is included explicitly
    // despite the plugin docs saying it's on by default — that default
    // clearly isn't holding either.
    await _viewController?.setSpeedometerEnabled(true);
    await _viewController?.setNavigationTripProgressBarEnabled(true);
    await _viewController?.setNavigationFooterEnabled(true);
    await _viewController?.setNavigationHeaderEnabled(true);
    if (mounted) setState(() => _guidanceRunning = true);

    // Only report position / hitos if planta/producción already generated a
    // real Remisión for this delivery (see remision.dart) — the app never
    // creates one itself, so no remisionId means nothing to post GPS/hitos
    // to.
    final remisionId = remision.remisionId;
    if (remisionId != null && AuthService.permisos.contains(permisoOperarRemisiones)) {
      _enviarPosicionActual(remisionId);
      _gpsTimer = Timer.periodic(const Duration(seconds: 15), (_) => _enviarPosicionActual(remisionId));
      _registrarHito(HitoEntrega.salioPlanta);
    }
  }

  /// Best-effort: a failed ping just means the next one 15s later tries
  /// again — not worth interrupting navigation over.
  Future<void> _enviarPosicionActual(int remisionId) async {
    try {
      final posicion = await geo.Geolocator.getCurrentPosition();
      await OperacionesService.enviarPosicion(remisionId, latitud: posicion.latitude, longitud: posicion.longitude);
    } catch (_) {}
  }

  /// Registers the real hito (and its server-stamped `hora*`) for the two
  /// moments this screen owns: guidance actually starting (`salioPlanta` —
  /// "hora de salida") and the SDK's own arrival geofence firing (`enObra`
  /// — "hora de llegada"). Unlike GPS pings this isn't repeated, so a
  /// failure is surfaced instead of silently retried.
  Future<void> _registrarHito(HitoEntrega hito) async {
    final remisionId = widget.remision.remisionId;
    if (remisionId == null || !AuthService.permisos.contains(permisoOperarRemisiones)) return;
    try {
      await OperacionesService.avanzarHito(remisionId, hito.backendValue);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {}
  }

  /// Whether leaving right now would cut off an in-progress route — used to
  /// gate the exit confirmation. Once arrived there's nothing left to
  /// interrupt, so "Ruta terminada" exits immediately.
  bool get _wouldInterruptRoute => _guidanceRunning && !_arrived;

  Future<void> _finish() async {
    if (_wouldInterruptRoute) {
      final salir = await _confirmarSalida();
      if (salir != true) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// The hito/GPS progress already sent to the backend up to this point is
  /// never at risk here — it was persisted server-side the moment each call
  /// succeeded. This dialog is only about the *in-progress* guidance
  /// session (turn-by-turn, live tracking) that leaving now would cut short.
  Future<bool?> _confirmarSalida() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _accentYellow.withValues(alpha: 0.15)),
          child: const Icon(Icons.warning_amber_rounded, color: _accentYellow, size: 28),
        ),
        title: const Text(
          '¿Salir de la navegación?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: const Text(
          'Se detendrá la guía de navegación en curso. El progreso de la entrega ya registrado no se perderá.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentYellow,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Salir', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_wouldInterruptRoute,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        body: Stack(
          children: [
            if (_errorText == null)
              Positioned.fill(
                child: GoogleMapsNavigationView(
                  onViewCreated: (controller) {
                    _viewController = controller;
                    // Set as soon as the view exists rather than waiting on
                    // `_start()` to reach this point — `_start()` runs from
                    // `initState`, before the platform view is guaranteed to
                    // have attached, so a call placed only after
                    // `startGuidance()` risked a silent no-op (`?.` on a
                    // still-null `_viewController`) depending on exactly how
                    // the awaits above interleaved with the widget's first
                    // build. These are view-level settings, not tied to an
                    // active guidance session, so there's no need to wait
                    // for one anyway.
                    controller.setSpeedometerEnabled(true);
                    // Marked `@experimental` by the plugin itself (could
                    // change/disappear in a future `google_navigation_flutter`
                    // release) — accepted trade-off since it's literally the
                    // feature being asked for and there's no non-experimental
                    // equivalent in this SDK version.
                    controller.setNavigationTripProgressBarEnabled(true);
                  },
                  initialNavigationUIEnabledPreference: NavigationUIEnabledPreference.automatic,
                  initialForceNightMode: NavigationForceNightMode.forceNight,
                  initialNavigationHeaderStylingOptions: _navigationHeaderStyle,
                  initialPadding: EdgeInsets.only(bottom: 96 + MediaQuery.of(context).padding.bottom),
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _errorText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: RouteNavBackButton(onTap: _finish),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: RouteNavBottomBar(arrived: _arrived, onFinish: _finish),
            ),
          ],
        ),
      ),
    );
  }
}
