import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../operaciones/remision_tracking.dart';
import '../theme/app_colors.dart';
import 'pedido.dart';
import 'vehicle_marker_icon.dart';

const _accentYellow = AppColors.accent;
const _green = AppColors.success;
const _red = AppColors.error;

class SummaryCard extends StatelessWidget {
  final Pedido pedido;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const SummaryCard({
    super.key,
    required this.pedido,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pedido.obraNombre,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            pedido.clienteNombre,
            style: TextStyle(fontSize: 13.5, color: mutedColor),
          ),
          const SizedBox(height: 14),
          Line(
            icon: Icons.water_drop_outlined,
            text: '${pedido.volumenSolicitadoM3} m³ · ${pedido.tipoServicio}',
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 8),
          Line(
            icon: Icons.payments_outlined,
            text:
                'Condición: ${pedido.condicionPago}${pedido.diasCredito != null ? ' · ${pedido.diasCredito} días' : ''}',
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          if (pedido.fechaProgramada != null) ...[
            const SizedBox(height: 8),
            Line(
              icon: Icons.event_outlined,
              text: 'Programada: ${pedido.fechaProgramada}',
              textColor: textColor,
              mutedColor: mutedColor,
            ),
          ],
          if (pedido.estatusGeneral == 'parcial' ||
              pedido.estatusGeneral == 'completo' ||
              pedido.volumenEntregadoM3 > 0) ...[
            const SizedBox(height: 14),
            _EntregaProgress(
              pedido: pedido,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
          ],
        ],
      ),
    );
  }
}

/// Delivery progress bar — `volumenEntregadoM3`/`estatusGeneral` update in
/// real time as each remisión gets firmada (the signature flow triggers
/// `comercial-service`'s internal entrega-tracking on the backend), so this
/// reflects actual accumulated delivery, not a static request snapshot.
class _EntregaProgress extends StatelessWidget {
  final Pedido pedido;
  final Color textColor;
  final Color mutedColor;

  const _EntregaProgress({
    required this.pedido,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final completo = pedido.estatusGeneral == 'completo';
    final color = completo ? _green : _accentYellow;
    final fraction = pedido.volumenSolicitadoM3 > 0
        ? (pedido.volumenEntregadoM3 / pedido.volumenSolicitadoM3).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Entrega',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
            if (completo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Completo',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: mutedColor.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${pedido.volumenEntregadoM3} / ${pedido.volumenSolicitadoM3} m³ entregado',
          style: TextStyle(fontSize: 12.5, color: mutedColor),
        ),
      ],
    );
  }
}

class Line extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color textColor;
  final Color mutedColor;

  const Line({
    super.key,
    required this.icon,
    required this.text,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: mutedColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13.5, color: textColor)),
        ),
      ],
    );
  }
}

/// Shows the client's límite de crédito / días de crédito on file, plus a
/// loud warning that the live estado-de-cuenta check isn't real yet — the
/// backend proxy to finanzas-service always answers `disponible=false`
/// (see vistas.md). Approving credit here is still "flying blind" on the
/// client's actual balance.
class EstadoCuentaCard extends StatelessWidget {
  final Cliente cliente;
  final EstadoCuenta estadoCuenta;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const EstadoCuentaCard({
    super.key,
    required this.cliente,
    required this.estadoCuenta,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Crédito del cliente',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: 'Límite de crédito',
                  value: '\$${cliente.limiteCredito.toStringAsFixed(0)}',
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'Días de crédito',
                  value: '${cliente.diasCredito}',
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ),
            ],
          ),
          if (!estadoCuenta.disponible) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Saldo en tiempo real no disponible (${estadoCuenta.mensaje ?? 'finanzas-service aún no existe'}). Los datos de arriba son los capturados en el expediente del cliente, no un saldo verificado.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: StatBlock(
                    label: 'Saldo actual',
                    value: '\$${estadoCuenta.saldoActual.toStringAsFixed(0)}',
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                ),
                Expanded(
                  child: StatBlock(
                    label: estadoCuenta.moroso ? 'Moroso' : 'Al corriente',
                    value: estadoCuenta.moroso ? 'Sí' : 'No',
                    textColor: estadoCuenta.moroso ? _red : _green,
                    mutedColor: mutedColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color mutedColor;

  const StatBlock({
    super.key,
    required this.label,
    required this.value,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: mutedColor)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

/// Either the Aprobar/Rechazar buttons (when `estatus == 'pendiente'`) or a
/// static chip showing the already-recorded result.
class AutorizacionSection extends StatelessWidget {
  final String estatus;
  final bool submitting;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;
  final Color textColor;
  final Color mutedColor;

  const AutorizacionSection({
    super.key,
    required this.estatus,
    required this.submitting,
    required this.onAprobar,
    required this.onRechazar,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    if (estatus != 'pendiente') {
      final aprobado = estatus == 'aprobado';
      final color = aprobado
          ? _green
          : (estatus == 'rechazado' ? _red : mutedColor);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              aprobado ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              estatus,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: submitting ? null : onRechazar,
            style: OutlinedButton.styleFrom(
              foregroundColor: _red,
              side: const BorderSide(color: _red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Rechazar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: submitting ? null : onAprobar,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Aprobar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Loads the pedido's remisiones and shows one [LiveTrackingCard] per
/// remisión found (a pedido can have both an olla and a bomba remisión, per
/// `AsignacionOllaBomba`). Kept in its own `FutureBuilder`, separate from
/// the screen's main future, so a tracking failure never blocks the rest of
/// the pedido detail from loading.
class LiveTrackingSection extends StatelessWidget {
  final Future<List<RemisionResumen>> remisionesFuture;
  final bool isDark;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const LiveTrackingSection({
    super.key,
    required this.remisionesFuture,
    required this.isDark,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RemisionResumen>>(
      future: remisionesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final remisiones = snapshot.hasError
            ? const <RemisionResumen>[]
            : snapshot.data!;
        if (remisiones.isEmpty) {
          return PlaceholderCard(
            text: snapshot.hasError
                ? (snapshot.error is AuthException
                      ? (snapshot.error as AuthException).message
                      : 'No se pudo cargar la remisión')
                : 'Aún no hay una remisión generada para este pedido.',
            cardColor: cardColor,
            borderColor: borderColor,
            mutedColor: mutedColor,
          );
        }

        return Column(
          children: [
            for (final remision in remisiones) ...[
              LiveTrackingCard(
                remisionId: remision.id,
                folioRemision: remision.folioRemision,
                conductorId: remision.conductorId,
                volumen: remision.metrosCargados ?? remision.metrosSolicitados,
                isDark: isDark,
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              if (remision != remisiones.last) const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }
}

class PlaceholderCard extends StatelessWidget {
  final String text;
  final Color cardColor;
  final Color borderColor;
  final Color mutedColor;

  const PlaceholderCard({
    super.key,
    required this.text,
    required this.cardColor,
    required this.borderColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(text, style: TextStyle(fontSize: 13.5, color: mutedColor)),
    );
  }
}

/// One remisión's live map: current position (marker) plus its recorrido
/// (polyline), refreshed every 15s via `GET /remisiones/{id}/ruta` until the
/// remisión reaches a terminal estatus.
class LiveTrackingCard extends StatefulWidget {
  final int remisionId;
  final String folioRemision;

  /// The driver assigned to this specific remisión — a pedido can be split
  /// across several (e.g. 40 m³ as 4 trucks of 10 m³ each), so Dirección
  /// needs to see which conductor carries which remisión, not just one
  /// combined pedido total. No employee-name lookup exists in this app yet,
  /// so this shows the raw id rather than fabricating a name.
  final int? conductorId;

  /// This remisión's own volume (`metrosCargados` once loaded, else
  /// `metrosSolicitados`) — not the pedido's total.
  final double? volumen;

  final bool isDark;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const LiveTrackingCard({
    super.key,
    required this.remisionId,
    required this.folioRemision,
    required this.conductorId,
    required this.volumen,
    required this.isDark,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  State<LiveTrackingCard> createState() => _LiveTrackingCardState();
}

class _LiveTrackingCardState extends State<LiveTrackingCard> {
  static const _terminales = {'entregado', 'con_incidencia'};

  RutaRemision? _ruta;
  String? _errorText;
  GoogleMapViewController? _mapController;
  Timer? _timer;

  /// Heading for the marker icon, degrees clockwise from north. Kept across
  /// polls rather than recomputed from scratch each time, since a poll with
  /// fewer than two `historial` points (e.g. right after the truck stops
  /// briefly) shouldn't snap the icon back to facing north.
  double _rotation = 0;

  /// Live marker/polyline, updated in place (`updateMarkers`/
  /// `updatePolylines`) rather than cleared and re-added every poll — that's
  /// what lets [glideMarkerTo] slide the truck smoothly between GPS pings
  /// instead of it snapping to the new position every 15s.
  Marker? _marker;
  Polyline? _polyline;
  Timer? _glide;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glide?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final ruta = await OperacionesService.rutaRemision(widget.remisionId);
      if (!mounted) return;
      setState(() {
        _ruta = ruta;
        _errorText = null;
      });
      await _updateMapOverlays(ruta);
      if (_terminales.contains(ruta.estatus)) _timer?.cancel();
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorText = e.message);
    }
  }

  Future<void> _updateMapOverlays(RutaRemision ruta) async {
    final controller = _mapController;
    final ultima = ruta.ultimaUbicacion;
    if (controller == null || ultima == null) return;

    final posicion = LatLng(
      latitude: ultima.latitud,
      longitude: ultima.longitud,
    );
    if (ruta.historial.length > 1) {
      _rotation = bearingBetween(
        ruta.historial[ruta.historial.length - 2],
        ruta.historial[ruta.historial.length - 1],
      );
    }

    final marcadorPrevio = _marker;
    if (marcadorPrevio == null) {
      final nuevos = await controller.addMarkers([
        MarkerOptions(
          position: posicion,
          icon: await VehicleMarkerIcon.forColor(_accentYellow),
          anchor: VehicleMarkerIcon.anchor,
          rotation: _rotation,
        ),
      ]);
      if (nuevos.isNotEmpty && nuevos.first != null) _marker = nuevos.first;
    } else {
      _glide?.cancel();
      _glide = glideMarkerTo(
        controller,
        marcadorPrevio,
        toPosition: posicion,
        toRotation: _rotation,
        duration: const Duration(seconds: 15),
        onUpdate: (updated) => _marker = updated,
      );
    }

    if (ruta.historial.length > 1) {
      final puntos = ruta.historial
          .map((p) => LatLng(latitude: p.latitud, longitude: p.longitud))
          .toList();
      final polilineaPrevia = _polyline;
      if (polilineaPrevia == null) {
        final nuevas = await controller.addPolylines([
          PolylineOptions(points: puntos, strokeColor: _accentYellow),
        ]);
        if (nuevas.isNotEmpty && nuevas.first != null) {
          _polyline = nuevas.first;
        }
      } else {
        final actualizadas = await controller.updatePolylines([
          polilineaPrevia.copyWith(
            options: polilineaPrevia.options.copyWith(points: puntos),
          ),
        ]);
        if (actualizadas.isNotEmpty && actualizadas.first != null) {
          _polyline = actualizadas.first;
        }
      }
    }

    // Recenters every poll — this preview has its own gestures disabled (see
    // the `GoogleMapsMapView` below), so there's no user pan/zoom for this
    // to fight, unlike `RutasActivasScreen`'s fully-interactive map.
    await controller.animateCamera(CameraUpdate.newLatLng(posicion));
  }

  @override
  Widget build(BuildContext context) {
    final ruta = _ruta;

    return Container(
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 18,
                      color: widget.mutedColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.folioRemision,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: widget.textColor,
                        ),
                      ),
                    ),
                    if (ruta != null)
                      Text(
                        ruta.estatus,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: widget.mutedColor,
                        ),
                      ),
                    if (ruta?.ultimaUbicacion != null)
                      IconButton(
                        tooltip: 'Ver en pantalla completa',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.fullscreen, color: widget.mutedColor),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LiveTrackingFullscreenScreen(
                                remisionId: widget.remisionId,
                                folioRemision: widget.folioRemision,
                                conductorId: widget.conductorId,
                                volumen: widget.volumen,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                if (widget.conductorId != null || widget.volumen != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(
                      [
                        if (widget.conductorId != null)
                          'Conductor #${widget.conductorId}',
                        if (widget.volumen != null) '${widget.volumen} m³',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: widget.mutedColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_errorText != null && ruta == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                _errorText!,
                style: TextStyle(fontSize: 13, color: widget.mutedColor),
              ),
            )
          else if (ruta == null)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (ruta.ultimaUbicacion == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Esperando la primera señal GPS de este viaje.',
                style: TextStyle(fontSize: 13, color: widget.mutedColor),
              ),
            )
          else
            SizedBox(
              height: 220,
              child: GoogleMapsMapView(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    latitude: ruta.ultimaUbicacion!.latitud,
                    longitude: ruta.ultimaUbicacion!.longitud,
                  ),
                  zoom: 15,
                ),
                initialMapColorScheme: widget.isDark
                    ? MapColorScheme.dark
                    : MapColorScheme.light,
                // Read-only preview embedded in a scrolling ListView — a map
                // that captures pan/zoom gestures fights the list's own
                // vertical scroll for the gesture arena, causing a visible
                // wobble whenever the drag direction reverses. It's just a
                // live-position glance, not something meant to be explored
                // in place, so its own gestures are disabled entirely.
                initialScrollGesturesEnabled: false,
                initialZoomGesturesEnabled: false,
                initialRotateGesturesEnabled: false,
                initialTiltGesturesEnabled: false,
                onViewCreated: (controller) {
                  _mapController = controller;
                  _updateMapOverlays(ruta);
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen, fully interactive version of one [LiveTrackingCard]'s map —
/// opened via its "Ver en pantalla completa" button. Runs its own poll/marker
/// logic rather than sharing `_LiveTrackingCardState`'s: the embedded card's
/// `GoogleMapsMapView` is a distinct native platform view from this one, so
/// each needs its own `GoogleMapViewController` and overlay updates anyway.
class LiveTrackingFullscreenScreen extends StatefulWidget {
  final int remisionId;
  final String folioRemision;
  final int? conductorId;
  final double? volumen;

  const LiveTrackingFullscreenScreen({
    super.key,
    required this.remisionId,
    required this.folioRemision,
    required this.conductorId,
    required this.volumen,
  });

  @override
  State<LiveTrackingFullscreenScreen> createState() =>
      _LiveTrackingFullscreenScreenState();
}

class _LiveTrackingFullscreenScreenState
    extends State<LiveTrackingFullscreenScreen> {
  static const _terminales = {'entregado', 'con_incidencia'};

  RutaRemision? _ruta;
  String? _errorText;
  GoogleMapViewController? _mapController;
  Timer? _timer;
  double _rotation = 0;

  /// Live marker/polyline, updated in place (`updateMarkers`/
  /// `updatePolylines`) rather than cleared and re-added every poll — that's
  /// what lets [glideMarkerTo] slide the truck smoothly between GPS pings
  /// instead of it snapping to the new position every 15s.
  Marker? _marker;
  Polyline? _polyline;
  Timer? _glide;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glide?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final ruta = await OperacionesService.rutaRemision(widget.remisionId);
      if (!mounted) return;
      setState(() {
        _ruta = ruta;
        _errorText = null;
      });
      await _updateMapOverlays(ruta);
      if (_terminales.contains(ruta.estatus)) _timer?.cancel();
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorText = e.message);
    }
  }

  Future<void> _updateMapOverlays(
    RutaRemision ruta, {
    bool moverCamara = false,
  }) async {
    final controller = _mapController;
    final ultima = ruta.ultimaUbicacion;
    if (controller == null || ultima == null) return;

    final posicion = LatLng(
      latitude: ultima.latitud,
      longitude: ultima.longitud,
    );
    if (ruta.historial.length > 1) {
      _rotation = bearingBetween(
        ruta.historial[ruta.historial.length - 2],
        ruta.historial[ruta.historial.length - 1],
      );
    }

    final marcadorPrevio = _marker;
    if (marcadorPrevio == null) {
      final nuevos = await controller.addMarkers([
        MarkerOptions(
          position: posicion,
          icon: await VehicleMarkerIcon.forColor(_accentYellow),
          anchor: VehicleMarkerIcon.anchor,
          rotation: _rotation,
        ),
      ]);
      if (nuevos.isNotEmpty && nuevos.first != null) _marker = nuevos.first;
    } else {
      _glide?.cancel();
      _glide = glideMarkerTo(
        controller,
        marcadorPrevio,
        toPosition: posicion,
        toRotation: _rotation,
        duration: const Duration(seconds: 15),
        onUpdate: (updated) => _marker = updated,
      );
    }

    if (ruta.historial.length > 1) {
      final puntos = ruta.historial
          .map((p) => LatLng(latitude: p.latitud, longitude: p.longitud))
          .toList();
      final polilineaPrevia = _polyline;
      if (polilineaPrevia == null) {
        final nuevas = await controller.addPolylines([
          PolylineOptions(
            points: puntos,
            strokeColor: _accentYellow,
            strokeWidth: 4,
          ),
        ]);
        if (nuevas.isNotEmpty && nuevas.first != null) {
          _polyline = nuevas.first;
        }
      } else {
        final actualizadas = await controller.updatePolylines([
          polilineaPrevia.copyWith(
            options: polilineaPrevia.options.copyWith(points: puntos),
          ),
        ]);
        if (actualizadas.isNotEmpty && actualizadas.first != null) {
          _polyline = actualizadas.first;
        }
      }
    }

    // Only recenters on load/first fix — once open, the user is expected to
    // pan/zoom freely (unlike the embedded card, gestures are enabled here),
    // so re-centering on every 15s poll would fight that.
    if (moverCamara) {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(posicion, 16));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ruta = _ruta;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.folioRemision),
            if (widget.conductorId != null || widget.volumen != null)
              Text(
                [
                  if (widget.conductorId != null)
                    'Conductor #${widget.conductorId}',
                  if (widget.volumen != null) '${widget.volumen} m³',
                ].join(' · '),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          if (ruta?.ultimaUbicacion != null)
            IconButton(
              tooltip: 'Centrar',
              icon: const Icon(Icons.my_location),
              onPressed: () => _updateMapOverlays(ruta!, moverCamara: true),
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_errorText != null && ruta == null) {
            return Center(
              child: Text(_errorText!, textAlign: TextAlign.center),
            );
          }
          if (ruta == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ruta.ultimaUbicacion == null) {
            return const Center(
              child: Text('Esperando la primera señal GPS de este viaje.'),
            );
          }
          return GoogleMapsMapView(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                latitude: ruta.ultimaUbicacion!.latitud,
                longitude: ruta.ultimaUbicacion!.longitud,
              ),
              zoom: 16,
            ),
            initialMapColorScheme: isDark
                ? MapColorScheme.dark
                : MapColorScheme.light,
            onViewCreated: (controller) {
              _mapController = controller;
              _updateMapOverlays(ruta, moverCamara: true);
            },
          );
        },
      ),
    );
  }
}
