import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../asesor_comercial/cotizacion.dart' show Cotizacion, formaPagoLabel, tipoLineaLabel;
import '../theme/app_colors.dart';
import 'pedido.dart';

const _green = AppColors.success;
const _red = AppColors.error;

/// Shows the client's límite de crédito / días de crédito on file, plus a
/// loud warning that the live estado-de-cuenta check isn't real yet — the
/// backend proxy to finanzas-service always answers `disponible=false`
/// (see vistas.md). Approving credit here is still "flying blind" on the
/// client's actual balance.
final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

/// The pedido's partidas and total — what Dirección is actually being asked
/// to extend credit for, next to the cliente's credit card below it.
/// [nombresProducto] is a best-effort `productoId` → nombre lookup (see
/// `PedidoDetailScreen._cargarNombresProducto`); a partida it can't resolve
/// falls back to its descripción, or just its tipoLinea label.
///
/// [cotizacion], once loaded, supplies the subtotal/descuento/IVA/total
/// breakdown and its `montoTotal` becomes the shown Total; until then (or
/// if it never loads) this falls back to [Pedido.montoTotal], the partida
/// sum — likely pre-IVA, so it's labeled "Subtotal" rather than "Total".
class MontosPedidoCard extends StatelessWidget {
  final Pedido pedido;
  final Map<int, String> nombresProducto;
  final Cotizacion? cotizacion;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const MontosPedidoCard({
    super.key,
    required this.pedido,
    required this.nombresProducto,
    this.cotizacion,
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
            'Montos del pedido',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(height: 12),
          for (final item in pedido.productos) ...[
            _partida(item),
            const SizedBox(height: 10),
          ],
          Divider(color: borderColor, height: 12),
          const SizedBox(height: 4),
          ..._totales(),
        ],
      ),
    );
  }

  List<Widget> _totales() {
    final c = cotizacion;
    final sumaPartidas = pedido.montoTotal;
    if (c == null) {
      return [_renglonMonto('Subtotal', sumaPartidas, destacado: true)];
    }
    final ivaLabel = c.porcentajeIva == null ? 'IVA' : 'IVA (${_porcentaje(c.porcentajeIva!)})';
    return [
      _renglonMonto('Subtotal', c.subtotal ?? sumaPartidas),
      if (c.porcentajeDescuento > 0) _renglon('Descuento', _porcentaje(c.porcentajeDescuento)),
      if (c.iva != null) _renglonMonto(ivaLabel, c.iva),
      const SizedBox(height: 4),
      _renglonMonto('Total', c.montoTotal, destacado: true),
    ];
  }

  String _porcentaje(double valor) =>
      '${valor == valor.roundToDouble() ? valor.toStringAsFixed(0) : valor.toStringAsFixed(2)}%';

  Widget _renglonMonto(String label, double? monto, {bool destacado = false}) =>
      _renglon(label, monto == null ? 'Sin monto' : _moneda.format(monto), destacado: destacado);

  Widget _renglon(String label, String valor, {bool destacado = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: destacado
                  ? TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)
                  : TextStyle(fontSize: 13, color: mutedColor),
            ),
          ),
          Text(
            valor,
            style: destacado
                ? TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textColor)
                : TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _partida(PedidoItem item) {
    final nombre = (item.productoId != null ? nombresProducto[item.productoId] : null) ?? item.descripcion;
    final detalle = [
      if (item.volumenSolicitadoM3 != null) '${item.volumenSolicitadoM3} m³',
      if (item.precioUnitario != null) '${_moneda.format(item.precioUnitario)} c/u',
    ].join(' × ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre == null ? tipoLineaLabel(item.tipoLinea) : '${tipoLineaLabel(item.tipoLinea)} · $nombre',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor),
              ),
              if (detalle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(detalle, style: TextStyle(fontSize: 12.5, color: mutedColor)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          item.precioTotal == null ? '—' : _moneda.format(item.precioTotal),
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor),
        ),
      ],
    );
  }
}

/// How the cliente pays (efectivo/factura) — its own card rather than a row
/// inside [MontosPedidoCard]. Sourced from the pedido's cotización, since
/// `PedidoResponse` doesn't echo `formaPago` (see
/// `PedidoDetailScreen._cargarFormaPago`).
class FormaPagoCard extends StatelessWidget {
  final String formaPago;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const FormaPagoCard({
    super.key,
    required this.formaPago,
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
      child: Row(
        children: [
          Icon(Icons.receipt_long_outlined, size: 22, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Forma de pago',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
            ),
          ),
          Text(
            formaPagoLabel(formaPago),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
          ),
        ],
      ),
    );
  }
}

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
