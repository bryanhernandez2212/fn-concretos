import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../operaciones/remision_tracking.dart';
import 'comercial_service.dart';
import 'pedido.dart';

const _accentYellow = Color(0xFFFFCC00);
const _green = Color(0xFF4CAF50);
const _red = Color(0xFFEF5350);

/// Detail view for a single Pedido: summary, the client's credit info (with
/// a loud warning that estado-de-cuenta is a stub — finanzas-service
/// doesn't exist yet, see vistas.md), and Aprobar/Rechazar actions for
/// whichever authorization step(s) the current user's permisos allow.
///
/// Pops `true` when an action succeeds, so [AutorizacionesScreen] knows to
/// refresh its tray.
class PedidoDetailScreen extends StatefulWidget {
  final Pedido pedido;

  const PedidoDetailScreen({super.key, required this.pedido});

  @override
  State<PedidoDetailScreen> createState() => _PedidoDetailScreenState();
}

class _PedidoDetailScreenState extends State<PedidoDetailScreen> {
  late Future<(Cliente, EstadoCuenta)> _future;
  late Future<List<RemisionResumen>> _remisionesFuture;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _remisionesFuture = OperacionesService.remisionesPorPedido(widget.pedido.id);
  }

  Future<(Cliente, EstadoCuenta)> _load() async {
    final results = await Future.wait([
      ComercialService.obtenerCliente(widget.pedido.clienteId),
      ComercialService.estadoCuenta(widget.pedido.clienteId),
    ]);
    return (results[0] as Cliente, results[1] as EstadoCuenta);
  }

  Future<void> _autorizarPago(String resultado, {String? motivo}) async {
    setState(() => _submitting = true);
    try {
      await ComercialService.autorizarPago(widget.pedido.id, resultado: resultado, motivo: motivo);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _submitting = false);
    }
  }

  Future<void> _autorizarLogistica(String resultado, {String? motivo}) async {
    setState(() => _submitting = true);
    try {
      await ComercialService.autorizarLogistica(widget.pedido.id, resultado: resultado, motivo: motivo);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _submitting = false);
    }
  }

  Future<void> _confirmarRechazo({required bool esLogistica}) async {
    final motivoController = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Motivo del rechazo'),
          content: TextField(
            controller: motivoController,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Explica por qué se rechaza...'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
              onPressed: () {
                final text = motivoController.text.trim();
                if (text.isEmpty) return;
                Navigator.of(context).pop(text);
              },
              child: const Text('Rechazar'),
            ),
          ],
        );
      },
    );
    if (motivo == null) return;
    if (esLogistica) {
      await _autorizarLogistica('rechazado', motivo: motivo);
    } else {
      await _autorizarPago('rechazado', motivo: motivo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pedido = widget.pedido;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.12);

    final puedeAutorizarLogistica = AuthService.permisos.contains(permisoAutorizarLogistica);

    return Scaffold(
      appBar: AppBar(
        title: Text(pedido.folio),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : _accentYellow,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<(Cliente, EstadoCuenta)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error is AuthException ? (snapshot.error as AuthException).message : 'No se pudo cargar el pedido',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: mutedColor),
                ),
              ),
            );
          }

          final (cliente, estadoCuenta) = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              _SummaryCard(pedido: pedido, cardColor: cardColor, borderColor: borderColor, textColor: textColor, mutedColor: mutedColor),
              const SizedBox(height: 20),
              _EstadoCuentaCard(
                cliente: cliente,
                estadoCuenta: estadoCuenta,
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              const SizedBox(height: 28),
              Text('Ubicación en vivo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 12),
              _LiveTrackingSection(
                remisionesFuture: _remisionesFuture,
                isDark: isDark,
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              const SizedBox(height: 28),
              Text('Autorización de pago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 12),
              _AutorizacionSection(
                estatus: pedido.estatusPagoAutorizacion,
                submitting: _submitting,
                onAprobar: () => _autorizarPago('aprobado'),
                onRechazar: () => _confirmarRechazo(esLogistica: false),
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              if (puedeAutorizarLogistica) ...[
                const SizedBox(height: 28),
                Text('Autorización de logística', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 12),
                _AutorizacionSection(
                  estatus: pedido.estatusLogisticaAutorizacion,
                  submitting: _submitting,
                  onAprobar: () => _autorizarLogistica('aprobado'),
                  onRechazar: () => _confirmarRechazo(esLogistica: true),
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Pedido pedido;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const _SummaryCard({
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
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pedido.obraNombre, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 2),
          Text(pedido.clienteNombre, style: TextStyle(fontSize: 13.5, color: mutedColor)),
          const SizedBox(height: 14),
          _Line(icon: Icons.water_drop_outlined, text: '${pedido.volumenSolicitadoM3} m³ · ${pedido.tipoServicio}', textColor: textColor, mutedColor: mutedColor),
          const SizedBox(height: 8),
          _Line(icon: Icons.payments_outlined, text: 'Condición: ${pedido.condicionPago}${pedido.diasCredito != null ? ' · ${pedido.diasCredito} días' : ''}', textColor: textColor, mutedColor: mutedColor),
          if (pedido.fechaProgramada != null) ...[
            const SizedBox(height: 8),
            _Line(icon: Icons.event_outlined, text: 'Programada: ${pedido.fechaProgramada}', textColor: textColor, mutedColor: mutedColor),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color textColor;
  final Color mutedColor;

  const _Line({required this.icon, required this.text, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: mutedColor),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, color: textColor))),
      ],
    );
  }
}

/// Shows the client's límite de crédito / días de crédito on file, plus a
/// loud warning that the live estado-de-cuenta check isn't real yet — the
/// backend proxy to finanzas-service always answers `disponible=false`
/// (see vistas.md). Approving credit here is still "flying blind" on the
/// client's actual balance.
class _EstadoCuentaCard extends StatelessWidget {
  final Cliente cliente;
  final EstadoCuenta estadoCuenta;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const _EstadoCuentaCard({
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
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Crédito del cliente', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatBlock(
                  label: 'Límite de crédito',
                  value: '\$${cliente.limiteCredito.toStringAsFixed(0)}',
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ),
              Expanded(
                child: _StatBlock(
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
                color: const Color(0xFFFFA000).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFA000), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Saldo en tiempo real no disponible (${estadoCuenta.mensaje ?? 'finanzas-service aún no existe'}). Los datos de arriba son los capturados en el expediente del cliente, no un saldo verificado.',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFFFFA000), fontWeight: FontWeight.w600),
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
                  child: _StatBlock(
                    label: 'Saldo actual',
                    value: '\$${estadoCuenta.saldoActual.toStringAsFixed(0)}',
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                ),
                Expanded(
                  child: _StatBlock(
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

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color mutedColor;

  const _StatBlock({required this.label, required this.value, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: mutedColor)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
      ],
    );
  }
}

/// Either the Aprobar/Rechazar buttons (when `estatus == 'pendiente'`) or a
/// static chip showing the already-recorded result.
class _AutorizacionSection extends StatelessWidget {
  final String estatus;
  final bool submitting;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;
  final Color textColor;
  final Color mutedColor;

  const _AutorizacionSection({
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
      final color = aprobado ? _green : (estatus == 'rechazado' ? _red : mutedColor);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(aprobado ? Icons.check_circle_outline : Icons.cancel_outlined, size: 18, color: color),
            const SizedBox(width: 8),
            Text(estatus, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Rechazar', style: TextStyle(fontWeight: FontWeight.w700)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: submitting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Aprobar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

/// Loads the pedido's remisiones and shows one [_LiveTrackingCard] per
/// remisión found (a pedido can have both an olla and a bomba remisión, per
/// `AsignacionOllaBomba`). Kept in its own `FutureBuilder`, separate from
/// [_PedidoDetailScreenState._future], so a tracking failure never blocks
/// the rest of the pedido detail from loading.
class _LiveTrackingSection extends StatelessWidget {
  final Future<List<RemisionResumen>> remisionesFuture;
  final bool isDark;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const _LiveTrackingSection({
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

        final remisiones = snapshot.hasError ? const <RemisionResumen>[] : snapshot.data!;
        if (remisiones.isEmpty) {
          return _PlaceholderCard(
            text: snapshot.hasError
                ? (snapshot.error is AuthException ? (snapshot.error as AuthException).message : 'No se pudo cargar la remisión')
                : 'Aún no hay una remisión generada para este pedido.',
            cardColor: cardColor,
            borderColor: borderColor,
            mutedColor: mutedColor,
          );
        }

        return Column(
          children: [
            for (final remision in remisiones) ...[
              _LiveTrackingCard(
                remisionId: remision.id,
                folioRemision: remision.folioRemision,
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

class _PlaceholderCard extends StatelessWidget {
  final String text;
  final Color cardColor;
  final Color borderColor;
  final Color mutedColor;

  const _PlaceholderCard({required this.text, required this.cardColor, required this.borderColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
      child: Text(text, style: TextStyle(fontSize: 13.5, color: mutedColor)),
    );
  }
}

/// One remisión's live map: current position (marker) plus its recorrido
/// (polyline), refreshed every 15s via `GET /remisiones/{id}/ruta` until the
/// remisión reaches a terminal estatus.
class _LiveTrackingCard extends StatefulWidget {
  final int remisionId;
  final String folioRemision;
  final bool isDark;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const _LiveTrackingCard({
    required this.remisionId,
    required this.folioRemision,
    required this.isDark,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  State<_LiveTrackingCard> createState() => _LiveTrackingCardState();
}

class _LiveTrackingCardState extends State<_LiveTrackingCard> {
  static const _terminales = {'entregado', 'con_incidencia'};

  RutaRemision? _ruta;
  String? _errorText;
  GoogleMapViewController? _mapController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
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

    final posicion = LatLng(latitude: ultima.latitud, longitude: ultima.longitud);
    await controller.clearMarkers();
    await controller.addMarkers([MarkerOptions(position: posicion)]);

    if (ruta.historial.length > 1) {
      await controller.clearPolylines();
      await controller.addPolylines([
        PolylineOptions(
          points: ruta.historial.map((p) => LatLng(latitude: p.latitud, longitude: p.longitud)).toList(),
          strokeColor: _accentYellow,
        ),
      ]);
    }

    await controller.animateCamera(CameraUpdate.newLatLng(posicion));
  }

  @override
  Widget build(BuildContext context) {
    final ruta = _ruta;

    return Container(
      decoration: BoxDecoration(color: widget.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: widget.borderColor)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(Icons.local_shipping_outlined, size: 18, color: widget.mutedColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.folioRemision,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: widget.textColor),
                  ),
                ),
                if (ruta != null)
                  Text(ruta.estatus, style: TextStyle(fontSize: 12.5, color: widget.mutedColor)),
              ],
            ),
          ),
          if (_errorText != null && ruta == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(_errorText!, style: TextStyle(fontSize: 13, color: widget.mutedColor)),
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
                  target: LatLng(latitude: ruta.ultimaUbicacion!.latitud, longitude: ruta.ultimaUbicacion!.longitud),
                  zoom: 15,
                ),
                initialMapColorScheme: widget.isDark ? MapColorScheme.dark : MapColorScheme.light,
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
