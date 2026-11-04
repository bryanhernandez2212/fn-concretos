import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../catalogo/conciliacion_agregados.dart';
import '../../finanzas/conciliacion_proveedor.dart';
import '../../theme/app_colors.dart';
import '../../widgets/info_pill.dart';

/// Estatus chip matching the pattern in `ordenes_compra_widgets.dart`.
class EstatusAgregadoChip extends StatelessWidget {
  final String estatus;

  const EstatusAgregadoChip({super.key, required this.estatus});

  @override
  Widget build(BuildContext context) {
    final color = _colorEstatus(estatus);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _etiquetaEstatus(estatus),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

Color _colorEstatus(String estatus) {
  final e = estatus.toLowerCase();
  if (e == 'activo' || e == 'active') return AppColors.success;
  if (e == 'inactivo' || e == 'inactive' || e == 'baja') return AppColors.error;
  return AppColors.neutral;
}

String _etiquetaEstatus(String estatus) {
  const conocidos = {
    'activo': 'Activo',
    'active': 'Activo',
    'inactivo': 'Inactivo',
    'inactive': 'Inactivo',
    'baja': 'Baja',
  };
  final conocido = conocidos[estatus.toLowerCase()];
  if (conocido != null) return conocido;
  if (estatus.isEmpty) return 'Sin estatus';
  final texto = estatus.replaceAll('_', ' ');
  return texto[0].toUpperCase() + texto.substring(1);
}

/// Card for a material in the list.
class MaterialCard extends StatelessWidget {
  final MaterialAgregado material;
  final VoidCallback onTap;

  const MaterialCard({super.key, required this.material, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _AgregadoCard(
      nombre: material.nombre,
      estatus: material.estatus,
      icon: Icons.terrain,
      pills: [
        if (material.unidad.isNotEmpty) _PillData(Icons.straighten, material.unidad),
        if (material.descripcion != null && material.descripcion!.isNotEmpty)
          _PillData(Icons.notes, material.descripcion!),
      ],
      onTap: onTap,
    );
  }
}

/// Card for an insumo in the list.
class InsumoCard extends StatelessWidget {
  final InsumoAgregado insumo;
  final VoidCallback onTap;

  const InsumoCard({super.key, required this.insumo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _AgregadoCard(
      nombre: insumo.nombre,
      estatus: insumo.estatus,
      icon: Icons.build_circle_outlined,
      pills: [
        if (insumo.unidad.isNotEmpty) _PillData(Icons.straighten, insumo.unidad),
        if (insumo.categoria != null && insumo.categoria!.isNotEmpty)
          _PillData(Icons.category_outlined, insumo.categoria!),
      ],
      onTap: onTap,
    );
  }
}

/// Card for a servicio in the list.
class ServicioCard extends StatelessWidget {
  final ServicioAgregado servicio;
  final VoidCallback onTap;

  const ServicioCard({super.key, required this.servicio, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _AgregadoCard(
      nombre: servicio.nombre,
      estatus: servicio.estatus,
      icon: Icons.miscellaneous_services,
      pills: [
        if (servicio.descripcion != null && servicio.descripcion!.isNotEmpty)
          _PillData(Icons.notes, servicio.descripcion!),
      ],
      onTap: onTap,
    );
  }
}

/// Internal helper to avoid duplicating card layout across Material/Insumo/
/// Servicio cards — same shape as [OrdenCompraCard].
class _PillData {
  final IconData icon;
  final String text;
  const _PillData(this.icon, this.text);
}

class _AgregadoCard extends StatelessWidget {
  final String nombre;
  final String estatus;
  final IconData icon;
  final List<_PillData> pills;
  final VoidCallback onTap;

  const _AgregadoCard({
    required this.nombre,
    required this.estatus,
    required this.icon,
    required this.pills,
    required this.onTap,
  });

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
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withValues(alpha: 0.14),
                    ),
                    child: Icon(icon, color: AppColors.accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nombre,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  EstatusAgregadoChip(estatus: estatus),
                ],
              ),
              if (pills.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in pills)
                      InfoPill(
                        icon: p.icon,
                        text: p.text.length > 30 ? '${p.text.substring(0, 28)}…' : p.text,
                        mutedColor: mutedColor,
                        textColor: textColor,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty/error placeholder matching `OrdenesCompraMensaje`.
class AgregadosMensaje extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String mensaje;
  final VoidCallback? onRetry;

  const AgregadosMensaje({
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

class AgregadoErrorPlaceholder extends StatelessWidget {
  final String mensaje;
  final VoidCallback? onRetry;

  const AgregadoErrorPlaceholder({
    super.key,
    required this.mensaje,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AgregadosMensaje(
      icon: Icons.error_outline,
      iconColor: AppColors.error,
      mensaje: mensaje,
      onRetry: onRetry,
    );
  }
}

class AgregadoVacioPlaceholder extends StatelessWidget {
  final String tipo;
  final String busqueda;
  final VoidCallback? onCrear;

  const AgregadoVacioPlaceholder({
    super.key,
    required this.tipo,
    this.busqueda = '',
    this.onCrear,
  });

  @override
  Widget build(BuildContext context) {
    return AgregadosMensaje(
      icon: Icons.inventory_2_outlined,
      mensaje: busqueda.isNotEmpty
          ? 'No se encontraron $tipo que coincidan con "$busqueda"'
          : 'No hay $tipo registrados aún',
    );
  }
}

/// Label/value row used in the detail screen's cards — same as [OrdenDatoRow].
class AgregadoDatoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const AgregadoDatoRow({
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

/// Section card with a title, matching `OrdenSeccion`.
class AgregadoSeccion extends StatelessWidget {
  final String titulo;
  final List<Widget> children;

  const AgregadoSeccion({super.key, required this.titulo, required this.children});

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

final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

/// Estatus chip for supplier reconciliations (`ConciliacionProveedor`).
Color colorEstatusConciliacion(String estatus) {
  final e = estatus.toLowerCase();
  if (e == 'aprobado' || e == 'pagado' || e == 'conciliado') return AppColors.success;
  if (e == 'con_diferencia' || e == 'diferencia' || e == 'pendiente') return AppColors.warning;
  if (e == 'cancelado' || e == 'rechazado') return AppColors.error;
  return AppColors.neutral;
}

String etiquetaEstatusConciliacion(String estatus) {
  if (estatus.isEmpty) return 'Borrador';
  final e = estatus.toLowerCase();
  switch (e) {
    case 'borrador':
      return 'Borrador';
    case 'conciliado':
      return 'Conciliado';
    case 'con_diferencia':
      return 'Con diferencia';
    case 'aprobado':
      return 'Aprobado';
    case 'pagado':
      return 'Pagado';
    case 'cancelado':
      return 'Cancelado';
    default:
      final t = estatus.replaceAll('_', ' ');
      return t[0].toUpperCase() + t.substring(1);
  }
}

/// Estatus chip for supplier reconciliations (`ConciliacionProveedor`).
class EstatusConciliacionChip extends StatelessWidget {
  final String estatus;

  const EstatusConciliacionChip({super.key, required this.estatus});

  @override
  Widget build(BuildContext context) {
    final color = colorEstatusConciliacion(estatus);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        etiquetaEstatusConciliacion(estatus),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// Card representing a `ConciliacionProveedor` in the Vales de Entrada list.
class ConciliacionProveedorCard extends StatelessWidget {
  final ConciliacionProveedor conciliacion;
  final VoidCallback onTap;

  const ConciliacionProveedorCard({
    super.key,
    required this.conciliacion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final hasDiferencias = conciliacion.diferenciasDetectadas != null &&
        conciliacion.diferenciasDetectadas!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: ID/Folio & Estatus
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long, size: 20, color: Colors.amber),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Conciliación #${conciliacion.id}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            conciliacion.proveedorNombre,
                            style: TextStyle(fontSize: 13, color: mutedColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    EstatusConciliacionChip(estatus: conciliacion.estatus),
                  ],
                ),
                const SizedBox(height: 12),

                // Period
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: mutedColor),
                    const SizedBox(width: 6),
                    Text(
                      '${conciliacion.periodoInicio}  →  ${conciliacion.periodoFin}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textColor),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Metrics row: viajes, arena, grava, agua
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (conciliacion.totalViajes != null)
                      InfoPill(
                        icon: Icons.local_shipping_outlined,
                        text: '${conciliacion.totalViajes} viajes',
                        mutedColor: mutedColor,
                        textColor: textColor,
                      ),
                    if (conciliacion.totalArena != null && conciliacion.totalArena! > 0)
                      InfoPill(
                        icon: Icons.grain,
                        text: '${conciliacion.totalArena!.toStringAsFixed(1)} m³ arena',
                        mutedColor: mutedColor,
                        textColor: textColor,
                      ),
                    if (conciliacion.totalGrava != null && conciliacion.totalGrava! > 0)
                      InfoPill(
                        icon: Icons.landscape_outlined,
                        text: '${conciliacion.totalGrava!.toStringAsFixed(1)} m³ grava',
                        mutedColor: mutedColor,
                        textColor: textColor,
                      ),
                    if (conciliacion.totalAgua != null && conciliacion.totalAgua! > 0)
                      InfoPill(
                        icon: Icons.water_drop_outlined,
                        text: '${conciliacion.totalAgua!.toStringAsFixed(1)} m³ agua',
                        mutedColor: mutedColor,
                        textColor: textColor,
                      ),
                  ],
                ),

                if (hasDiferencias) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            conciliacion.diferenciasDetectadas!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.warning,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Total a pagar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total a pagar',
                      style: TextStyle(fontSize: 13, color: mutedColor, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      conciliacion.totalAPagar != null
                          ? _moneda.format(conciliacion.totalAPagar)
                          : '\$0.00',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tile representing a line item in a reconciliation detail.
class DetalleConciliacionTile extends StatelessWidget {
  final ConciliacionDetalle detalle;

  const DetalleConciliacionTile({super.key, required this.detalle});

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final diff = detalle.diferenciaMonto ?? 0;
    final hasDiff = diff.abs() > 0.001;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Vale #${detalle.valeId ?? '—'}  ↔  Entrada #${detalle.entradaId ?? '—'}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              if (detalle.estatus != null)
                EstatusConciliacionChip(estatus: detalle.estatus!),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (detalle.observaciones != null && detalle.observaciones!.isNotEmpty)
                Expanded(
                  child: Text(
                    detalle.observaciones!,
                    style: TextStyle(fontSize: 12, color: mutedColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                Expanded(
                  child: Text(
                    'Sin observaciones',
                    style: TextStyle(fontSize: 12, color: mutedColor.withValues(alpha: 0.5)),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                'Dif: ${_moneda.format(diff)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: hasDiff ? AppColors.warning : AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Estatus chip for a `ValeEntradaMaterial`.
class EstatusValeChip extends StatelessWidget {
  final String estatus;
  final VoidCallback? onTap;

  const EstatusValeChip({super.key, required this.estatus, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = colorEstatusVale(estatus);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            etiquetaEstatusVale(estatus),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 14, color: color),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: chip,
      );
    }
    return chip;
  }
}

Color colorEstatusVale(String estatus) {
  final e = estatus.toLowerCase();
  switch (e) {
    case 'conciliado':
    case 'autorizado_pago':
      return AppColors.success;
    case 'con_diferencia':
      return AppColors.warning;
    case 'registrado':
      return Colors.blue;
    default:
      return AppColors.neutral;
  }
}

String etiquetaEstatusVale(String estatus) {
  if (estatus.isEmpty) return 'Registrado';
  final e = estatus.toLowerCase();
  switch (e) {
    case 'registrado':
      return 'Registrado';
    case 'conciliado':
      return 'Conciliado';
    case 'con_diferencia':
      return 'Con diferencia';
    case 'autorizado_pago':
      return 'Autorizado pago';
    default:
      final t = estatus.replaceAll('_', ' ');
      return t[0].toUpperCase() + t.substring(1);
  }
}

/// Card representing a `ValeEntradaMaterial` in the Vales de Entrada list.
class ValeEntradaCard extends StatelessWidget {
  final ValeEntradaMaterial vale;
  final VoidCallback? onTap;
  final VoidCallback? onCambiarEstatus;

  const ValeEntradaCard({
    super.key,
    required this.vale,
    this.onTap,
    this.onCambiarEstatus,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);

    IconData iconMaterial;
    final matLower = (vale.material ?? '').toLowerCase();
    if (matLower.contains('agua')) {
      iconMaterial = Icons.water_drop_outlined;
    } else if (matLower.contains('grava')) {
      iconMaterial = Icons.landscape_outlined;
    } else {
      iconMaterial = Icons.grain;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Icon, Folio & Estatus
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(iconMaterial, color: Colors.amber, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vale.folioVale != null && vale.folioVale!.isNotEmpty
                                ? 'Folio: ${vale.folioVale}'
                                : 'Vale #${vale.id}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            vale.proveedorNombre ?? 'Proveedor #${vale.proveedorId}',
                            style: TextStyle(fontSize: 13, color: mutedColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    EstatusValeChip(
                      estatus: vale.estatus ?? 'registrado',
                      onTap: onCambiarEstatus,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Material and Quantity badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        vale.material ?? 'Material',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${vale.cantidad?.toStringAsFixed(1) ?? '0'} ${vale.unidad ?? 'm³'}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                    const Spacer(),
                    if (vale.fecha != null)
                      Text(
                        vale.fecha!,
                        style: TextStyle(fontSize: 12, color: mutedColor),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Info pills (viaje, placas, transportista, vinculada)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (vale.numeroViaje != null && vale.numeroViaje!.isNotEmpty)
                      InfoPill(
                        icon: Icons.tag,
                        text: 'Viaje ${vale.numeroViaje}',
                        mutedColor: mutedColor,
                        textColor: textColor,
                      ),
                    if (vale.placas != null && vale.placas!.isNotEmpty)
                      InfoPill(
                        icon: Icons.directions_car_outlined,
                        text: vale.placas!,
                        mutedColor: mutedColor,
                        textColor: textColor,
                      ),
                    if (vale.transportista != null && vale.transportista!.isNotEmpty)
                      InfoPill(
                        icon: Icons.person_outline,
                        text: vale.transportista!,
                        mutedColor: mutedColor,
                        textColor: textColor,
                      ),
                    if (vale.tieneEntradaVinculada == true)
                      InfoPill(
                        icon: Icons.link,
                        text: 'Entrada vinculada',
                        mutedColor: AppColors.success,
                        textColor: AppColors.success,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


