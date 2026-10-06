import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../finanzas/orden_compra.dart';
import '../../theme/app_colors.dart';
import '../../widgets/info_pill.dart';

final moneda = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

String fechaCorta(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class EstatusOrdenChip extends StatelessWidget {
  final String estatus;

  const EstatusOrdenChip({super.key, required this.estatus});

  @override
  Widget build(BuildContext context) {
    final color = colorEstatusOrdenCompra(estatus);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        etiquetaEstatusOrdenCompra(estatus),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// One orden de compra in the Compras tab's list.
class OrdenCompraCard extends StatelessWidget {
  final OrdenCompra orden;
  final VoidCallback onTap;

  const OrdenCompraCard({super.key, required this.orden, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    return Material(
      color: AppColors.card(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      orden.proveedorNombre,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  Text(
                    orden.folio,
                    style: TextStyle(fontSize: 12, color: mutedColor),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                moneda.format(orden.total),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoPill(
                    icon: Icons.calendar_today_outlined,
                    text: fechaCorta(orden.createdAt),
                    mutedColor: mutedColor,
                    textColor: textColor,
                  ),
                  if (orden.condicionPago != null &&
                      orden.condicionPago!.isNotEmpty)
                    InfoPill(
                      icon: Icons.payments_outlined,
                      text: orden.condicionPago!,
                      mutedColor: mutedColor,
                      textColor: textColor,
                    ),
                  if (orden.creadoPorUsuario != null)
                    InfoPill(
                      icon: Icons.person_outline,
                      text: orden.creadoPorUsuario!,
                      mutedColor: mutedColor,
                      textColor: textColor,
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

/// Empty/error placeholder card for the Compras list.
class OrdenesCompraMensaje extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String mensaje;
  final VoidCallback? onRetry;

  const OrdenesCompraMensaje({
    super.key,
    required this.icon,
    required this.mensaje,
    this.iconColor,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final mutedColor = AppColors.mutedText(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor ?? mutedColor, size: 28),
          const SizedBox(height: 10),
          Text(
            mensaje,
            style: TextStyle(fontSize: 13.5, color: mutedColor),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ],
      ),
    );
  }
}

/// Label/value row used in the detail screen's cards.
class OrdenDatoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const OrdenDatoRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.mutedText(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: bold ? 15 : 13.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: AppColors.text(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One partida: descripción, cantidad × precio unitario, total.
class OrdenItemRow extends StatelessWidget {
  final OrdenCompraItem item;
  final bool isLast;

  const OrdenItemRow({super.key, required this.item, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final mutedColor = AppColors.mutedText(context);
    final cantidad = item.cantidad % 1 == 0
        ? item.cantidad.toInt().toString()
        : item.cantidad.toString();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.descripcion.isEmpty
                          ? 'Sin descripción'
                          : item.descripcion,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$cantidad ${item.unidad ?? ''} × ${moneda.format(item.precioUnitario)}'
                          .replaceAll('  ', ' '),
                      style: TextStyle(fontSize: 12, color: mutedColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                moneda.format(item.total),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text(context),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: mutedColor.withValues(alpha: 0.15)),
      ],
    );
  }
}

/// A rounded card with a section title, used to group the detail screen.
class OrdenSeccion extends StatelessWidget {
  final String titulo;
  final List<Widget> children;

  const OrdenSeccion({super.key, required this.titulo, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.text(context),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}
