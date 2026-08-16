import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../operaciones/remision_tracking.dart';
import 'comercial_service.dart';
import 'pedido.dart';
import 'pedido_detail_widgets.dart';

const _accentYellow = Color(0xFFFFCC00);
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
              SummaryCard(pedido: pedido, cardColor: cardColor, borderColor: borderColor, textColor: textColor, mutedColor: mutedColor),
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
