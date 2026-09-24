import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/auth_service.dart';
import '../finanzas/comision.dart';
import '../theme/app_colors.dart';
import 'asesor_comercial_widgets.dart';

final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

/// Formats a backend `yyyy-MM-dd` as e.g. "1 sep 2026", falling back to the
/// raw string if it doesn't parse.
String fechaCorta(String? iso) {
  if (iso == null) return '—';
  final fecha = DateTime.tryParse(iso);
  return fecha == null ? iso : DateFormat('d MMM y', 'es').format(fecha);
}

String periodoTexto(ComisionPeriodo p) => '${fechaCorta(p.fechaInicio)} – ${fechaCorta(p.fechaFin)}';

/// `ComisionesScreen`'s "Proyección" section: loading/error/empty states,
/// then the projected-total summary plus one card per pedido.
class ProyeccionSection extends StatelessWidget {
  final Future<List<ComisionProyectada>> future;
  final VoidCallback onRetry;

  const ProyeccionSection({super.key, required this.future, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.08);

    return FutureBuilder<List<ComisionProyectada>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return ErrorState(
            message: snapshot.error is AuthException
                ? (snapshot.error as AuthException).message
                : 'No se pudo cargar la proyección de comisiones',
            onRetry: onRetry,
            cardColor: cardColor,
            borderColor: borderColor,
            mutedColor: mutedColor,
          );
        }

        final items = snapshot.data!;
        if (items.isEmpty) {
          return EmptyState(
            message: 'No tienes pedidos en espera de comisión en este momento.',
            icon: Icons.hourglass_empty_rounded,
            cardColor: cardColor,
            borderColor: borderColor,
            mutedColor: mutedColor,
          );
        }

        final total = items.fold<double>(0, (sum, i) => sum + i.comisionProyectada);
        return Column(
          children: [
            ResumenProyeccionCard(
              total: total,
              pedidos: items.length,
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
            const SizedBox(height: 16),
            for (final item in items) ...[
              ProyeccionCard(
                item: item,
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

/// `ComisionesScreen`'s "Historial" section: loading/error/empty states,
/// then the por cobrar/cobrado summary plus one tappable card per corte.
class HistorialSection extends StatelessWidget {
  final Future<List<ComisionPeriodo>> future;
  final VoidCallback onRetry;
  final ValueChanged<ComisionPeriodo> onPeriodoTap;

  const HistorialSection({super.key, required this.future, required this.onRetry, required this.onPeriodoTap});

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.08);

    return FutureBuilder<List<ComisionPeriodo>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return ErrorState(
            message: snapshot.error is AuthException
                ? (snapshot.error as AuthException).message
                : 'No se pudieron cargar las comisiones',
            onRetry: onRetry,
            cardColor: cardColor,
            borderColor: borderColor,
            mutedColor: mutedColor,
          );
        }

        final periodos = snapshot.data!;
        if (periodos.isEmpty) {
          return EmptyState(
            message: 'Aún no tienes cortes de comisión procesados',
            icon: Icons.account_balance_wallet_outlined,
            cardColor: cardColor,
            borderColor: borderColor,
            mutedColor: mutedColor,
          );
        }

        final pendientePago = periodos
            .where(
              (p) => !p.estatus.toLowerCase().startsWith('pagad') && !p.estatus.toLowerCase().startsWith('cancelad'),
            )
            .fold<double>(0, (sum, p) => sum + p.totalComisiones);
        final pagado = periodos
            .where((p) => p.estatus.toLowerCase().startsWith('pagad'))
            .fold<double>(0, (sum, p) => sum + p.totalComisiones);

        return Column(
          children: [
            ResumenComisionesCard(
              pendientePago: pendientePago,
              pagado: pagado,
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
            const SizedBox(height: 16),
            for (final periodo in periodos) ...[
              PeriodoCard(
                periodo: periodo,
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                mutedColor: mutedColor,
                onTap: () => onPeriodoTap(periodo),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

/// Projected total plus a prominent disclaimer — the one thing this card
/// must get across is that none of this is authorized money yet.
class ResumenProyeccionCard extends StatelessWidget {
  final double total;
  final int pedidos;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const ResumenProyeccionCard({
    super.key,
    required this.total,
    required this.pedidos,
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
          Text('Comisión proyectada', style: TextStyle(fontSize: 12.5, color: mutedColor)),
          const SizedBox(height: 4),
          Text(
            _moneda.format(total),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textColor),
          ),
          Text(pedidos == 1 ? '1 pedido' : '$pedidos pedidos', style: TextStyle(fontSize: 13, color: mutedColor)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Esto es una PROYECCIÓN, no una comisión autorizada ni garantizada. '
                    'Los montos pueden cambiar hasta que el cliente liquide el pedido y '
                    'Finanzas procese el corte real.',
                    style: TextStyle(fontSize: 12.5, height: 1.35, color: textColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProyeccionCard extends StatelessWidget {
  final ComisionProyectada item;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const ProyeccionCard({
    super.key,
    required this.item,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = proyeccionEstatusColor(item.estatus);
    final fecha = item.fechaPedido;
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.folio,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(item.clienteNombre, style: TextStyle(fontSize: 13, color: mutedColor)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _moneda.format(item.comisionProyectada),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  proyeccionEstatusLabel(item.estatus),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
                ),
              ),
              const Spacer(),
              Text(
                fecha == null ? '—' : DateFormat('d MMM y', 'es').format(fecha),
                style: TextStyle(fontSize: 12.5, color: mutedColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ResumenComisionesCard extends StatelessWidget {
  final double pendientePago;
  final double pagado;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const ResumenComisionesCard({
    super.key,
    required this.pendientePago,
    required this.pagado,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget bloque(String label, double monto, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: mutedColor)),
          const SizedBox(height: 4),
          Text(
            _moneda.format(monto),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [bloque('Por cobrar', pendientePago, textColor), bloque('Cobrado', pagado, AppColors.success)],
      ),
    );
  }
}

class PeriodoCard extends StatelessWidget {
  final ComisionPeriodo periodo;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const PeriodoCard({
    super.key,
    required this.periodo,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pedidos = periodo.detalle.length;
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      periodoTexto(periodo),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                    ),
                  ),
                  ComisionEstatusChip(estatus: periodo.estatus),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pedidos == 1 ? '1 pedido' : '$pedidos pedidos',
                      style: TextStyle(fontSize: 13, color: mutedColor),
                    ),
                  ),
                  Text(
                    _moneda.format(periodo.totalComisiones),
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textColor),
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

class ComisionEstatusChip extends StatelessWidget {
  final String estatus;

  const ComisionEstatusChip({super.key, required this.estatus});

  @override
  Widget build(BuildContext context) {
    final color = comisionEstatusColor(estatus);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
      child: Text(
        comisionEstatusLabel(estatus),
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
