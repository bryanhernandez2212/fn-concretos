import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import '../auth/auth_service.dart';
import '../direccion/comercial_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/field_group.dart';
import 'obra_location_picker_screen.dart';
import 'visita_form_screen.dart';

/// Registers a new Obra (job site) for [clienteId] — the last step of Asesor
/// Comercial's "agregar obra" flow (`ClientePickerScreen` picks or creates
/// the cliente first, since `POST /obras` requires a `clientePrincipalId`).
/// `latitud`/`longitud` are required, not just a nice-to-have: they're what
/// `route_navigation_screen.dart`'s turn-by-turn navigation sends
/// conductores to, so a device-current-position guess isn't good enough —
/// the advisor pins the obra's exact spot on [ObraLocationPickerScreen]'s
/// interactive map, the in-app equivalent of dropping a pin in Google Maps.
/// On success, hands off to [VisitaFormScreen] — the advisor is usually
/// standing at the site they just registered, so logging the visita is
/// almost always the next thing they want to do.
class ObraFormScreen extends StatefulWidget {
  final int clienteId;
  final String clienteNombre;

  const ObraFormScreen({super.key, required this.clienteId, required this.clienteNombre});

  @override
  State<ObraFormScreen> createState() => _ObraFormScreenState();
}

class _ObraFormScreenState extends State<ObraFormScreen> {
  final _nombreController = TextEditingController();
  final _direccionController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _coloniaController = TextEditingController();
  final _mapsLinkController = TextEditingController();
  final _geocoding = Geocoding();
  LatLng? _ubicacion;
  bool _autocompletando = false;
  bool _enviando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _direccionController.dispose();
    _ciudadController.dispose();
    _coloniaController.dispose();
    _mapsLinkController.dispose();
    super.dispose();
  }

  Future<void> _elegirUbicacion() async {
    final elegida = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (context) => ObraLocationPickerScreen(initial: _ubicacion)),
    );
    if (elegida == null) return;
    setState(() => _ubicacion = elegida);
    await _autocompletarDesdeUbicacion(elegida);
  }

  /// Fills dirección/ciudad/colonia from the picked pin via the OS's native
  /// reverse-geocoder (no Google API key needed, unlike the Maps/Navigation
  /// SDKs — sidesteps that access gap entirely), so the advisor doesn't have
  /// to retype what the pin already implies. Only fills fields still empty,
  /// so it never clobbers something the advisor already typed by hand; the
  /// Maps link is regenerated every time since it's meant to always mirror
  /// the current pin, not independent input.
  Future<void> _autocompletarDesdeUbicacion(LatLng posicion) async {
    _mapsLinkController.text = 'https://www.google.com/maps/search/?api=1&query=${posicion.latitude},${posicion.longitude}';
    setState(() => _autocompletando = true);
    try {
      final lugares = await _geocoding.placemarkFromCoordinates(posicion.latitude, posicion.longitude);
      if (lugares.isEmpty) return;
      final lugar = lugares.first;
      final calle = (lugar.street?.isNotEmpty ?? false)
          ? lugar.street!
          : [lugar.thoroughfare, lugar.subThoroughfare].where((s) => s != null && s.isNotEmpty).join(' ');
      if (_direccionController.text.trim().isEmpty && calle.isNotEmpty) _direccionController.text = calle;
      if (_ciudadController.text.trim().isEmpty && (lugar.locality?.isNotEmpty ?? false)) {
        _ciudadController.text = lugar.locality!;
      }
      if (_coloniaController.text.trim().isEmpty && (lugar.subLocality?.isNotEmpty ?? false)) {
        _coloniaController.text = lugar.subLocality!;
      }
    } catch (_) {
      // Best-effort: the coordinates are already captured either way, so a
      // failed reverse-geocode just leaves the address fields for the
      // advisor to fill by hand instead of blocking the flow.
    } finally {
      if (mounted) setState(() => _autocompletando = false);
    }
  }

  Future<void> _submit() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      AppSnack.error(context, 'Ingresa el nombre de la obra');
      return;
    }
    final ubicacion = _ubicacion;
    if (ubicacion == null) {
      AppSnack.error(context, 'Marca la ubicación exacta de la obra en el mapa');
      return;
    }

    setState(() => _enviando = true);
    try {
      final obra = await ComercialService.crearObra(
        nombre: nombre,
        clientePrincipalId: widget.clienteId,
        direccion: _direccionController.text.trim(),
        ciudad: _ciudadController.text.trim(),
        colonia: _coloniaController.text.trim(),
        googleMapsLink: _mapsLinkController.text.trim(),
        latitud: ubicacion.latitude,
        longitud: ubicacion.longitude,
      );
      if (!mounted) return;
      AppSnack.success(context, 'Obra registrada');
      // The advisor is usually standing at the site they just registered —
      // offer to log the visita right away instead of making them find
      // their way back through "Nueva visita" separately. Skippable: the
      // VisitaFormScreen's own back arrow pops without creating one, and
      // registering the obra alone is still a complete action.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VisitaFormScreen(
            clienteId: widget.clienteId,
            clienteNombre: widget.clienteNombre,
            obraId: obra.id,
            obraNombre: obra.nombre,
          ),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo registrar la obra');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  InputDecoration _decoration(String hint, Color mutedColor, Color fillColor) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: mutedColor),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.10);
    final fillColor = AppColors.border(context, alpha: 0.06);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar obra'),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
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
                Text('Cliente', style: TextStyle(fontSize: 12, color: mutedColor)),
                const SizedBox(height: 4),
                Text(widget.clienteNombre, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nombreController,
            style: TextStyle(color: textColor),
            decoration: _decoration('Nombre de la obra', mutedColor, fillColor),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _direccionController,
            style: TextStyle(color: textColor),
            decoration: _decoration('Dirección', mutedColor, fillColor),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ciudadController,
                  style: TextStyle(color: textColor),
                  decoration: _decoration('Ciudad', mutedColor, fillColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _coloniaController,
                  style: TextStyle(color: textColor),
                  decoration: _decoration('Colonia', mutedColor, fillColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mapsLinkController,
            keyboardType: TextInputType.url,
            style: TextStyle(color: textColor),
            decoration: _decoration('Link de Google Maps (opcional)', mutedColor, fillColor),
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _elegirUbicacion,
            child: FieldGroup(
              cardColor: cardColor,
              borderColor: borderColor,
              expand: true,
              child: Row(
                children: [
                  Icon(
                    _ubicacion == null ? Icons.location_off_outlined : Icons.location_on_outlined,
                    color: _ubicacion == null ? mutedColor : AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _ubicacion == null
                          ? 'Marcar ubicación exacta en el mapa'
                          : '${_ubicacion!.latitude.toStringAsFixed(5)}, ${_ubicacion!.longitude.toStringAsFixed(5)}',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor),
                    ),
                  ),
                  if (_autocompletando)
                    const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Icon(Icons.chevron_right, color: mutedColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _enviando ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _enviando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                  : const Text('Registrar obra', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
