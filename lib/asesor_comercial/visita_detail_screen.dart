import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import '../direccion/comercial_service.dart';
import '../direccion/pedido.dart';
import '../theme/app_colors.dart';
import '../widgets/contacto_card.dart';
import '../widgets/evidencia_viewer_screen.dart';
import '../widgets/field_group.dart';
import 'asesor_comercial_widgets.dart';
import 'cotizacion_form_screen.dart';
import 'obra_location_view_screen.dart';
import 'solicitud_diseno_screen.dart';
import 'visita.dart';
import 'visita_checkin_screen.dart';

/// Detail for a single Visita. There's no `GET /visitas/{id}` in
/// `comercial-service`, so this screen works off the [Visita] passed in from
/// the list and the fresh copy [VisitaCheckinScreen] returns after check-in
/// — never re-fetches. Always pops with `true` so `VisitasScreen` refreshes
/// (cheap even when nothing changed). `Visita` itself carries no dirección —
/// only `obraNombre`, not the obra's address — so this screen makes its own
/// best-effort `ComercialService.obtenerObra` call for that, plus the
/// coordinates the embedded map thumbnail needs.
class VisitaDetailScreen extends StatefulWidget {
  final Visita visita;

  const VisitaDetailScreen({super.key, required this.visita});

  @override
  State<VisitaDetailScreen> createState() => _VisitaDetailScreenState();
}

class _VisitaDetailScreenState extends State<VisitaDetailScreen> {
  late Visita _visita;
  Obra? _obra;

  @override
  void initState() {
    super.initState();
    _visita = widget.visita;
    _cargarObra();
  }

  Future<void> _cargarObra() async {
    final obraId = _visita.obraId;
    if (obraId == null) return;
    try {
      final obra = await ComercialService.obtenerObra(obraId);
      if (mounted) setState(() => _obra = obra);
    } catch (_) {
      // Best-effort — the rest of the screen already works off the Visita
      // alone, so a failed lookup just means no dirección/"Cómo llegar" for
      // this visit, not a broken screen.
    }
  }

  void _verUbicacion() {
    final obra = _obra;
    if (obra == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ObraLocationViewScreen(obra: obra)),
    );
  }

  Future<void> _registrarCheckin() async {
    final actualizada = await Navigator.of(context).push<Visita>(
      MaterialPageRoute(builder: (context) => VisitaCheckinScreen(visita: _visita)),
    );
    if (actualizada != null) setState(() => _visita = actualizada);
  }

  void _solicitarDisenoEspecial() {
    final clienteId = _visita.clienteId;
    if (clienteId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SolicitudDisenoScreen(clienteId: clienteId, obraId: _visita.obraId),
      ),
    );
  }

  void _generarCotizacion() {
    final clienteId = _visita.clienteId;
    if (clienteId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CotizacionFormScreen(
          clienteId: clienteId,
          clienteNombre: _visita.clienteNombre ?? 'Cliente sin nombre',
          obraId: _visita.obraId,
          obraNombre: _visita.obraNombre,
          obraPlantaId: _obra?.plantaId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.10);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visita'),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          FieldGroup(
            cardColor: cardColor,
            borderColor: borderColor,
            expand: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _visita.obraNombre ?? 'Obra sin nombre',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textColor),
                      ),
                    ),
                    EstatusChip(estatus: _visita.estatus),
                  ],
                ),
                if (_visita.clienteNombre != null) ...[
                  const SizedBox(height: 6),
                  Text(_visita.clienteNombre!, style: TextStyle(fontSize: 13.5, color: mutedColor)),
                ],
                const SizedBox(height: 12),
                Text('Fecha: ${_visita.fechaVisita}', style: TextStyle(fontSize: 13, color: mutedColor)),
                if (_visita.horaCheckin != null)
                  Text('Check-in: ${_visita.horaCheckin}', style: TextStyle(fontSize: 13, color: mutedColor)),
                if (_visita.volumenAproximado != null)
                  Text('Volumen aproximado: ${_visita.volumenAproximado} m³', style: TextStyle(fontSize: 13, color: mutedColor)),
              ],
            ),
          ),
          if (_obra != null) ...[
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _verUbicacion,
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A static map "thumbnail" — gestures disabled since
                    // it's embedded in this scrolling ListView (same reason
                    // `pedido_detail_widgets.dart`'s LiveTrackingCard
                    // disables them), tapping opens the interactive
                    // fullscreen view instead. Read-only; no marker drag,
                    // unlike `ObraLocationPickerScreen`.
                    SizedBox(
                      height: 140,
                      child: IgnorePointer(
                        child: GoogleMapsMapView(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(latitude: _obra!.latitud, longitude: _obra!.longitud),
                            zoom: 15,
                          ),
                          initialMapColorScheme: isDark ? MapColorScheme.dark : MapColorScheme.light,
                          initialScrollGesturesEnabled: false,
                          initialZoomGesturesEnabled: false,
                          initialRotateGesturesEnabled: false,
                          initialTiltGesturesEnabled: false,
                          onViewCreated: (controller) {
                            controller.addMarkers([
                              MarkerOptions(position: LatLng(latitude: _obra!.latitud, longitude: _obra!.longitud)),
                            ]);
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 18, color: mutedColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _direccionCompleta(_obra!),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_visita.contactoNombre != null) ...[
            const SizedBox(height: 16),
            ContactoCard(
              nombre: _visita.contactoNombre!,
              telefono: _visita.contactoTelefono,
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
          ],
          if (_visita.fotoEvidenciaUrl != null) ...[
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EvidenciaViewerScreen(url: _visita.fotoEvidenciaUrl!, label: 'Evidencia de check-in'),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(_visita.fotoEvidenciaUrl!, height: 140, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_visita.estatus == 'asignada')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _registrarCheckin,
                icon: const Icon(Icons.my_location),
                label: const Text('Registrar check-in'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          if (_visita.estatus == 'visitada' && _visita.clienteId != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _generarCotizacion,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Generar cotización'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
          if (_visita.clienteId != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _solicitarDisenoEspecial,
                icon: const Icon(Icons.science_outlined),
                label: const Text('Solicitar diseño especial'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Joins whatever address pieces [obra] actually has (`direccion` is
/// required by `ObraFormScreen` now, but `colonia`/`ciudad` stay optional),
/// falling back to the raw coordinates if even `direccion` came back empty
/// — an obra registered before this app started requiring dirección text.
String _direccionCompleta(Obra obra) {
  final partes = [obra.direccion, obra.colonia, obra.ciudad].where((p) => p != null && p.isNotEmpty);
  if (partes.isEmpty) return '${obra.latitud.toStringAsFixed(5)}, ${obra.longitud.toStringAsFixed(5)}';
  return partes.join(', ');
}
