import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../comercial/pedido.dart';
import '../../finanzas/facturacion.dart';
import '../../theme/app_colors.dart';
import '../../widgets/info_pill.dart';

// Catalogs and labels below are copied from the web panel so both show the
// same values.

/// `condicionPago` options of the web's "Convertir cotización en pedido".
const condicionPagoOpciones = {
  'liquidado': 'Liquidado',
  'anticipo': 'Anticipo',
  'credito': 'Crédito',
  'liquidar_obra': 'Liquidar en obra',
};

String condicionPagoLabel(String condicionPago, {int? diasCredito}) {
  final label = condicionPagoOpciones[condicionPago] ?? _capitalizar(condicionPago);
  return condicionPago == 'credito' && diasCredito != null ? '$label · $diasCredito días' : label;
}

/// Pedido `formaPago` and the anticipo's `metodoPago` share this catalog.
const metodoPagoOpciones = {
  'efectivo': 'Efectivo',
  'transferencia': 'Transferencia',
  'tarjeta_debito': 'Tarjeta de débito',
  'tarjeta_credito': 'Tarjeta de crédito',
};

/// Anticipo `cuentaDestino` options.
const cuentaDestinoOpciones = {
  'empresa': 'Empresa',
  'ing_carlos': 'Ing. Carlos',
  'no_fiscal': 'No fiscal',
  'otra': 'Otra',
};

String _capitalizar(String texto) => texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);

/// Any backend estatus shown the web's way: capitalized, `_` → space.
String estatusTexto(String? estatus) =>
    estatus == null || estatus.isEmpty ? '—' : _capitalizar(estatus).replaceAll('_', ' ');

/// The web's tone rule: rechazado → error, pendiente/parcial → warning,
/// anything else → success.
Color estatusTono(String? estatus) {
  final e = (estatus ?? '').toLowerCase();
  if (e.isEmpty) return AppColors.warning;
  if (e.contains('rechaz')) return AppColors.error;
  if (e.contains('pendiente') || e.contains('parcial')) return AppColors.warning;
  return AppColors.success;
}

bool pedidoPendiente(Pedido p) => [p.estatusGeneral, p.estatusPagoAutorizacion, p.estatusLogisticaAutorizacion]
    .any((e) => e.toLowerCase().contains('pendiente'));

bool pedidoEnProceso(Pedido p) {
  final e = p.estatusGeneral.toLowerCase();
  return e.contains('parcial') || e.contains('programado') || e.contains('proceso');
}

bool pedidoCompletado(Pedido p) => p.estatusGeneral.toLowerCase() == 'completo';

/// "Pagado" once payments cover the total (±0.01), as on the web. Null when
/// the payments summary didn't load, so the badge is skipped instead of
/// guessing.
bool? pedidoPagado(Pedido p, Map<int, double>? pagado) {
  if (pagado == null) return null;
  return (p.montoTotal ?? 0) - (pagado[p.id] ?? 0) <= 0.01;
}

const _facturaLabels = {
  'pendiente_facturar': ('Factura pendiente', AppColors.warning),
  'solicitado_contabilidad': ('Factura solicitada', AppColors.warning),
  'facturado': ('Facturado', AppColors.success),
  'enviado_cliente': ('Factura enviada', AppColors.success),
  'requiere_correccion': ('Requiere corrección', AppColors.error),
};

const _prefacturaLabels = {
  'borrador': 'Pref. borrador',
  'enviada': 'Pref. enviada',
  'confirmada_cliente': 'Pref. confirmada',
  'facturada': 'Pref. facturada',
};

/// The web's "Facturación" badge: the factura if there is one, else the
/// prefactura, else "Sin prefactura".
(String, Color) facturacionBadge(PedidoFacturacionResumen? r) {
  if (r == null) return ('Sin prefactura', AppColors.neutral);
  if (r.facturaId != null) {
    return _facturaLabels[r.facturaEstatus] ?? (estatusTexto(r.facturaEstatus ?? 'facturado'), AppColors.success);
  }
  if (r.prefacturaId != null) {
    final estatus = r.prefacturaEstatus ?? '';
    final color = switch (estatus) {
      'enviada' => AppColors.warning,
      'confirmada_cliente' || 'facturada' => AppColors.success,
      _ => AppColors.neutral,
    };
    return (_prefacturaLabels[estatus] ?? 'Prefactura ${estatusTexto(estatus)}', color);
  }
  return ('Sin prefactura', AppColors.neutral);
}

String fechaCorta(String? iso) {
  final fecha = iso == null ? null : DateTime.tryParse(iso);
  return fecha == null ? (iso ?? '—') : DateFormat('d MMM y', 'es').format(fecha);
}

class EstatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const EstatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class PedidoAsesorCard extends StatelessWidget {
  final Pedido pedido;
  final bool? pagado;

  /// Null while finanzas' summary isn't available — the badge is skipped.
  final (String, Color)? facturacion;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const PedidoAsesorCard({
    super.key,
    required this.pedido,
    required this.pagado,
    required this.facturacion,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(p.folio, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
                  ),
                  EstatusBadge(label: estatusTexto(p.estatusGeneral), color: estatusTono(p.estatusGeneral)),
                ],
              ),
              const SizedBox(height: 4),
              Text(p.clienteNombre, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor)),
              Text(p.obraNombre, style: TextStyle(fontSize: 13, color: mutedColor)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoPill(
                    icon: Icons.water_drop_outlined,
                    text: '${p.volumenSolicitadoM3} m³',
                    mutedColor: mutedColor,
                    textColor: textColor,
                  ),
                  if (p.fechaProgramada != null)
                    InfoPill(
                      icon: Icons.event_outlined,
                      text: fechaCorta(p.fechaProgramada),
                      mutedColor: mutedColor,
                      textColor: textColor,
                    ),
                  if (p.formaPago != null)
                    InfoPill(
                      icon: Icons.payments_outlined,
                      text: metodoPagoOpciones[p.formaPago] ?? estatusTexto(p.formaPago),
                      mutedColor: mutedColor,
                      textColor: textColor,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (pagado != null)
                    EstatusBadge(
                      label: pagado! ? 'Pagado' : 'Pendiente de pago',
                      color: pagado! ? AppColors.success : AppColors.warning,
                    ),
                  if (facturacion != null) EstatusBadge(label: facturacion!.$1, color: facturacion!.$2),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Autorizacion(
                      titulo: 'Aut. pago',
                      estatus: p.estatusPagoAutorizacion,
                      mutedColor: mutedColor,
                    ),
                  ),
                  Expanded(
                    child: _Autorizacion(
                      titulo: 'Aut. logística',
                      estatus: p.estatusLogisticaAutorizacion,
                      mutedColor: mutedColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Autorizacion extends StatelessWidget {
  final String titulo;
  final String estatus;
  final Color mutedColor;

  const _Autorizacion({required this.titulo, required this.estatus, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    final color = estatusTono(estatus);
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$titulo: ${estatusTexto(estatus)}',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: mutedColor),
          ),
        ),
      ],
    );
  }
}
