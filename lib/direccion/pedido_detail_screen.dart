import 'dart:async';

import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../operaciones/remision_tracking.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/contacto_card.dart';
import 'comercial_service.dart';
import 'pedido.dart';
import 'pedido_detail_widgets.dart';

const _red = AppColors.error;

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
  late Future<(Cliente, EstadoCuenta, ClienteContacto?)> _future;
  late Future<List<RemisionResumen>> _remisionesFuture;
  late Future<Obra?> _obraFuture;
  bool _submitting = false;

  /// `widget.pedido` is a snapshot from whenever this screen was opened —
  /// `volumenEntregadoM3`/`volumenPendienteM3`/`estatusGeneral` change
  /// server-side as remisiones get firmadas (possibly from a different
  /// conductor's device, so nothing local triggers a refetch), so this is
  /// kept current by [_pedidoTimer] the same way "Ubicación en vivo" polls
  /// each remisión's ruta below.
  Pedido? _pedidoOverride;
  Pedido get _pedido => _pedidoOverride ?? widget.pedido;
  Timer? _pedidoTimer;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _remisionesFuture = OperacionesService.remisionesPorPedido(widget.pedido.id);
    _obraFuture = _cargarObra();
    _pedidoTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refrescarPedido());
  }

  /// Best-effort, kept separate from [_future] so a failed obra lookup only
  /// means "Ubicación en vivo" has no destino for its ETA/progress — not a
  /// broken pedido-detail screen (same reasoning as `_remisionesFuture`).
  Future<Obra?> _cargarObra() async {
    try {
      return await ComercialService.obtenerObra(widget.pedido.obraId);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _pedidoTimer?.cancel();
    super.dispose();
  }

  Future<void> _refrescarPedido() async {
    try {
      final pedido = await ComercialService.obtenerPedido(widget.pedido.id);
      if (!mounted) return;
      setState(() => _pedidoOverride = pedido);
    } on AuthException {
      // Best-effort background refresh — a failed poll just tries again in
      // 15s, no need to surface an error for it.
    }
  }

  Future<(Cliente, EstadoCuenta, ClienteContacto?)> _load() async {
    final results = await Future.wait([
      ComercialService.obtenerCliente(widget.pedido.clienteId),
      ComercialService.estadoCuenta(widget.pedido.clienteId),
      ComercialService.contactoParaEntrega(
        obraId: widget.pedido.obraId,
        clienteId: widget.pedido.clienteId,
      ),
    ]);
    return (results[0] as Cliente, results[1] as EstadoCuenta, results[2] as ClienteContacto?);
  }

  Future<void> _autorizarPago(String resultado, {String? motivo}) async {
    setState(() => _submitting = true);
    try {
      await ComercialService.autorizarPago(widget.pedido.id, resultado: resultado, motivo: motivo);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;
      AppSnack.error(context, e.message);
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
      AppSnack.error(context, e.message);
      setState(() => _submitting = false);
    }
  }

  Future<void> _confirmarRechazo({required bool esLogistica}) async {
    final motivoController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final fieldFillColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);

    final motivo = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Motivo del rechazo', style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
          content: TextField(
            controller: motivoController,
            autofocus: true,
            maxLines: 3,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Explica por qué se rechaza...',
              hintStyle: TextStyle(color: mutedColor),
              filled: true,
              fillColor: fieldFillColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar', style: TextStyle(color: mutedColor, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final text = motivoController.text.trim();
                if (text.isEmpty) return;
                Navigator.of(context).pop(text);
              },
              child: const Text('Rechazar', style: TextStyle(fontWeight: FontWeight.w700)),
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
    final pedido = _pedido;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.12);

    final puedeAutorizarLogistica = AuthService.permisos.contains(permisoAutorizarLogistica);

    return Scaffold(
      appBar: AppBar(
        title: Text(pedido.folio),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<(Cliente, EstadoCuenta, ClienteContacto?)>(
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

          final (cliente, estadoCuenta, contacto) = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              SummaryCard(pedido: pedido, cardColor: cardColor, borderColor: borderColor, textColor: textColor, mutedColor: mutedColor),
              if (contacto != null) ...[
                const SizedBox(height: 16),
                ContactoCard(
                  nombre: contacto.nombre,
                  cargo: contacto.cargo,
                  telefono: contacto.telefono,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ],
              const SizedBox(height: 20),
              EstadoCuentaCard(
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
              LiveTrackingSection(
                remisionesFuture: _remisionesFuture,
                obraFuture: _obraFuture,
                isDark: isDark,
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              const SizedBox(height: 28),
              Text('Autorización de pago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 12),
              AutorizacionSection(
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
                AutorizacionSection(
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
