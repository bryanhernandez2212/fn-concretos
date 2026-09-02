import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import '../direccion/pedido.dart';

/// Full-screen, interactive (pan/zoom left on) read-only view of an obra's
/// pinned location — opened by tapping the static map thumbnail on
/// `VisitaDetailScreen`. Unlike `ObraLocationPickerScreen`, nothing here is
/// editable and there's no confirm step; it's just a bigger look at the
/// same marker the thumbnail already shows, kept entirely in-app rather
/// than handing off to the external Google Maps app.
class ObraLocationViewScreen extends StatelessWidget {
  final Obra obra;

  const ObraLocationViewScreen({super.key, required this.obra});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final posicion = LatLng(latitude: obra.latitud, longitude: obra.longitud);

    return Scaffold(
      appBar: AppBar(
        title: Text(obra.nombre),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: GoogleMapsMapView(
        initialCameraPosition: CameraPosition(target: posicion, zoom: 17),
        initialMapColorScheme: isDark ? MapColorScheme.dark : MapColorScheme.light,
        onViewCreated: (controller) {
          controller.addMarkers([MarkerOptions(position: posicion)]);
        },
      ),
    );
  }
}
