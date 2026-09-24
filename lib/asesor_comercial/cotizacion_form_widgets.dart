import 'package:flutter/material.dart';
import '../catalogo/planta.dart';
import '../catalogo/producto.dart';
import '../theme/app_colors.dart';
import '../widgets/field_group.dart';
import 'cotizacion.dart';

/// One editable línea/partida row. `tipoLinea` is [tipoLineaProducto],
/// [tipoLineaBombeo] or [tipoLineaServicio] only — never
/// [tipoLineaFleteVacio], which the backend generates itself and this app
/// must never resend (see `cotizacion.dart`). `productoId`/`tipoLinea`
/// aren't controllers (they're selections, not free text).
class PartidaControllers {
  final volumen = TextEditingController();
  final precio = TextEditingController();
  final descripcion = TextEditingController();
  String tipoLinea;
  int? productoId;

  PartidaControllers({this.tipoLinea = tipoLineaProducto});

  /// Existing `flete_vacio` líneas must be filtered out by the caller before
  /// reaching this factory — see `CotizacionFormScreen`'s edit-mode
  /// `initState`.
  factory PartidaControllers.from(CotizacionItem item) {
    final tipo = item.tipoLinea == tipoLineaBombeo || item.tipoLinea == tipoLineaServicio
        ? item.tipoLinea!
        : tipoLineaProducto;
    final c = PartidaControllers(tipoLinea: tipo);
    c.volumen.text = item.volumenM3 == null ? '' : '${item.volumenM3}';
    c.precio.text = '${item.precioUnitario}';
    c.descripcion.text = item.descripcion ?? '';
    c.productoId = item.productoId;
    return c;
  }

  void dispose() {
    volumen.dispose();
    precio.dispose();
    descripcion.dispose();
  }
}

/// Filled, borderless input decoration shared by `CotizacionFormScreen`'s
/// fields and [PartidaCard].
InputDecoration cotizacionFieldDecoration(String hint, Color mutedColor, Color fillColor) {
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

/// Client-side estimate only — the backend's own `precioTotal` per línea
/// (shown in `CotizacionDetailScreen` after saving) is authoritative. A
/// `producto` línea is precio × volumen; `bombeo`/`servicio` are typically
/// a flat fee, so just precio.
double importeEstimado(PartidaControllers item) {
  final precio = double.tryParse(item.precio.text.trim()) ?? 0;
  if (item.tipoLinea != tipoLineaProducto) return precio;
  final volumen = double.tryParse(item.volumen.text.trim()) ?? 0;
  return precio * volumen;
}

double sumaPorTipo(List<PartidaControllers> items, String tipoLinea) =>
    items.where((i) => i.tipoLinea == tipoLinea).fold(0.0, (sum, i) => sum + importeEstimado(i));

/// Mirrors the backend's own rule (see `cotizacion.dart`): one flete_vacio
/// per `producto` línea whose volumen doesn't divide evenly into the
/// planta's `capacidadReferenciaM3`, charged at `precioPorM3Vacio` for the
/// leftover (vacío) capacity. Preview only — needs a planta with both
/// fields set, otherwise there's nothing to estimate from.
double fleteVacioEstimado(List<PartidaControllers> items, Planta? planta) {
  final capacidad = planta?.capacidadReferenciaM3;
  final precioVacio = planta?.precioPorM3Vacio;
  if (capacidad == null || capacidad <= 0 || precioVacio == null) return 0;
  var total = 0.0;
  for (final item in items) {
    if (item.tipoLinea != tipoLineaProducto) continue;
    final volumen = double.tryParse(item.volumen.text.trim()) ?? 0;
    if (volumen <= 0) continue;
    final residuo = volumen % capacidad;
    if (residuo == 0) continue;
    total += (capacidad - residuo) * precioVacio;
  }
  return total;
}

/// One editable partida card. Mutates [item] directly (tipoLinea/productoId
/// selections) and calls [onChanged] so the owning screen can `setState` —
/// the running estimate/summary depend on it. [onQuitar] null hides the
/// remove button (the last remaining partida can't be removed).
class PartidaCard extends StatelessWidget {
  final int index;
  final PartidaControllers item;
  final List<Producto> productos;
  final VoidCallback? onQuitar;
  final ValueChanged<int?> onProductoSeleccionado;
  final VoidCallback onChanged;
  final Color textColor;
  final Color mutedColor;
  final Color cardColor;
  final Color borderColor;
  final Color fillColor;

  const PartidaCard({
    super.key,
    required this.index,
    required this.item,
    required this.productos,
    required this.onQuitar,
    required this.onProductoSeleccionado,
    required this.onChanged,
    required this.textColor,
    required this.mutedColor,
    required this.cardColor,
    required this.borderColor,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return FieldGroup(
      cardColor: cardColor,
      borderColor: borderColor,
      expand: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${index + 1}. ${tipoLineaLabel(item.tipoLinea)}',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textColor),
                ),
              ),
              if (onQuitar != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: mutedColor,
                  onPressed: onQuitar,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [tipoLineaProducto, tipoLineaBombeo, tipoLineaServicio].map((tipo) {
              final seleccionado = item.tipoLinea == tipo;
              return ChoiceChip(
                label: Text(tipoLineaLabel(tipo)),
                selected: seleccionado,
                onSelected: (_) {
                  item.tipoLinea = tipo;
                  if (tipo != tipoLineaProducto) item.productoId = null;
                  onChanged();
                },
                selectedColor: AppColors.accent,
                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: seleccionado ? Colors.black : textColor),
                backgroundColor: fillColor,
                side: BorderSide.none,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (item.tipoLinea == tipoLineaProducto) ...[
            if (productos.isNotEmpty)
              DropdownButtonFormField<int?>(
                initialValue: item.productoId,
                dropdownColor: AppColors.surfaceAlt(context),
                style: TextStyle(color: textColor, fontSize: 14.5),
                decoration: cotizacionFieldDecoration('Seleccionar producto…', mutedColor, fillColor),
                items: productos
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.nombre, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: onProductoSeleccionado,
              )
            else
              TextField(
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: cotizacionFieldDecoration(
                  'Producto (ID) — no se pudo cargar el catálogo',
                  mutedColor,
                  fillColor,
                ),
                onChanged: (value) {
                  item.productoId = int.tryParse(value.trim());
                  onChanged();
                },
              ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: item.volumen,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: textColor),
                  onChanged: (_) => onChanged(),
                  decoration: cotizacionFieldDecoration(
                    item.tipoLinea == tipoLineaProducto ? 'Volumen (m³)' : 'Volumen (m³) — opcional',
                    mutedColor,
                    fillColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: item.precio,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: textColor),
                  onChanged: (_) => onChanged(),
                  decoration: cotizacionFieldDecoration('Precio unitario', mutedColor, fillColor),
                ),
              ),
            ],
          ),
          if (item.tipoLinea == tipoLineaBombeo) ...[
            const SizedBox(height: 4),
            Text(
              'Si no capturas el volumen, se autocompleta con la suma de las partidas de producto.',
              style: TextStyle(fontSize: 11.5, color: mutedColor),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: item.descripcion,
            style: TextStyle(color: textColor),
            decoration: cotizacionFieldDecoration(
              item.tipoLinea == tipoLineaProducto ? 'Descripción (opcional)' : 'Descripción (ej. Bombeo pluma propia)',
              mutedColor,
              fillColor,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Importe estimado: \$${importeEstimado(item).toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: mutedColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Client-side estimated totals for the whole cotización. The subtotals come
/// precomputed from the screen ([sumaPorTipo]/[fleteVacioEstimado]).
class ResumenCotizacionCard extends StatelessWidget {
  final double subtotalProductos;
  final double subtotalBombeo;
  final double subtotalServicios;
  final double fleteVacio;
  final double porcentajeDescuento;
  final Color textColor;
  final Color mutedColor;
  final Color cardColor;
  final Color borderColor;

  const ResumenCotizacionCard({
    super.key,
    required this.subtotalProductos,
    required this.subtotalBombeo,
    required this.subtotalServicios,
    required this.fleteVacio,
    required this.porcentajeDescuento,
    required this.textColor,
    required this.mutedColor,
    required this.cardColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = subtotalProductos + subtotalBombeo + subtotalServicios + fleteVacio;
    // Only líneas producto se descuentan — bombeo/servicio/flete_vacío no.
    final descuento = subtotalProductos * (porcentajeDescuento / 100);
    final total = subtotal - descuento;

    Widget renglon(String label, double valor, {bool negativo = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 13, color: mutedColor)),
            ),
            Text(
              '${negativo ? '-' : ''}\$${valor.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor),
            ),
          ],
        ),
      );
    }

    return FieldGroup(
      cardColor: cardColor,
      borderColor: borderColor,
      expand: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen de cotización',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(height: 12),
          renglon('Productos', subtotalProductos),
          renglon('Bombeo', subtotalBombeo),
          renglon('Servicios adicionales', subtotalServicios),
          renglon('Flete / Vacío estimado', fleteVacio),
          if (porcentajeDescuento > 0) renglon('Descuento ($porcentajeDescuento%)', descuento, negativo: true),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total estimado',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: textColor),
                ),
              ),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Estimado — el backend recalcula el total real (incluyendo flete/vacío) al guardar.',
            style: TextStyle(fontSize: 11, color: mutedColor),
          ),
        ],
      ),
    );
  }
}
