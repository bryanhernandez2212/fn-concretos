import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import 'remision.dart';

const _accentYellow = Color(0xFFFFCC00);

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
    final granted =
        permission == geo.LocationPermission.always || permission == geo.LocationPermission.whileInUse;
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
      if (mounted) setState(() => _arrived = true);
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
      if (mounted) setState(() => _errorText = 'No se pudo calcular la ruta a la obra.');
      return;
    }

    await GoogleMapsNavigator.startGuidance();
    await _viewController?.followMyLocation(CameraPerspective.tilted);
    if (mounted) setState(() => _guidanceRunning = true);
  }

  void _finish() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_errorText == null)
            Positioned.fill(
              child: GoogleMapsNavigationView(
                onViewCreated: (controller) => _viewController = controller,
                initialNavigationUIEnabledPreference: NavigationUIEnabledPreference.automatic,
                initialPadding: EdgeInsets.only(
                  bottom: 96 + MediaQuery.of(context).padding.bottom,
                ),
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
              child: _BackButton(onTap: _finish),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomBar(arrived: _arrived, onFinish: _finish),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
    );
  }
}

/// This app's own exit affordance, sitting below the native navigation
/// view's own header/footer chrome (see [initialPadding] above). Always
/// tappable — arrival flips its look from a quiet outline to a filled
/// "Ruta terminada", but either state pops back to the delivery detail.
class _BottomBar extends StatelessWidget {
  final bool arrived;
  final VoidCallback onFinish;

  const _BottomBar({required this.arrived, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: arrived
            ? ElevatedButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.check_circle, color: Colors.black),
                label: const Text('Ruta terminada', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentYellow,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )
            : OutlinedButton(
                onPressed: onFinish,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Finalizar ruta', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
      ),
    );
  }
}

