import 'package:flutter/material.dart';
import '../../catalogo/planta.dart';
import '../../catalogo/producto.dart';
import '../../theme/app_colors.dart';
import '../../widgets/field_group.dart';
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
  final descuentoLinea = TextEditingController();
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
    c.descuentoLinea.text = item.porcentajeDescuentoLinea == null || item.porcentajeDescuentoLinea == 0 ? '' : '${item.porcentajeDescuentoLinea}';
    c.productoId = item.productoId;
    return c;
  }

  void dispose() {
    volumen.dispose();
    precio.dispose();
    descripcion.dispose();
    descuentoLinea.dispose();
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
  final desc = double.tryParse(item.descuentoLinea.text.trim()) ?? 0;
  final precioConDesc = precio * (1 - (desc / 100));
  
  if (item.tipoLinea != tipoLineaProducto) return precioConDesc;
  final volumen = double.tryParse(item.volumen.text.trim()) ?? 0;
  return precioConDesc * volumen;
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
class PartidaCard extends StatefulWidget {
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
  State<PartidaCard> createState() => _PartidaCardState();
}

class _PartidaCardState extends State<PartidaCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final productos = widget.productos;
    final index = widget.index;
    final textColor = widget.textColor;
    final mutedColor = widget.mutedColor;
    final cardColor = widget.cardColor;
    final borderColor = widget.borderColor;
    final fillColor = widget.fillColor;
    
    // Resumen para el header cuando está colapsado
    String tituloResumen = 'Detalles de la partida';
    if (!_expanded) {
      if (item.tipoLinea == tipoLineaProducto) {
        if (item.productoId != null) {
          final p = productos.where((prod) => prod.id == item.productoId).firstOrNull;
          tituloResumen = p?.nombre ?? 'Producto';
        } else {
          tituloResumen = 'Producto (sin seleccionar)';
        }
      } else {
        tituloResumen = tipoLineaLabel(item.tipoLinea);
      }
      final vol = item.volumen.text.trim();
      if (vol.isNotEmpty) tituloResumen += ' - $vol m³';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (Tocable para colapsar/expandir)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(14),
              bottom: _expanded ? Radius.zero : const Radius.circular(14),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: fillColor.withOpacity(0.5),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(14),
                  bottom: _expanded ? Radius.zero : const Radius.circular(14),
                ),
                border: _expanded ? Border(bottom: BorderSide(color: borderColor)) : null,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tituloResumen,
                      style: TextStyle(fontWeight: FontWeight.w700, color: textColor, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!_expanded) ...[
                    const SizedBox(width: 8),
                    Text(
                      '\$${importeEstimado(item).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.accent),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: mutedColor,
                  ),
                  if (widget.onQuitar != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: Colors.redAccent,
                      onPressed: widget.onQuitar,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Body & Footer se ocultan si está colapsado
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selector de Tipo
                  DropdownButtonFormField<String>(
                    value: item.tipoLinea,
                    dropdownColor: AppColors.surfaceAlt(context),
                    style: TextStyle(color: textColor, fontSize: 14.5, fontWeight: FontWeight.w600),
                    icon: Icon(Icons.keyboard_arrow_down, color: mutedColor),
                    decoration: cotizacionFieldDecoration('Tipo de Partida', mutedColor, fillColor).copyWith(
                      labelText: 'Tipo de Partida',
                      labelStyle: TextStyle(color: mutedColor, fontSize: 13),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      prefixIcon: Icon(Icons.category_outlined, color: mutedColor, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    items: [tipoLineaProducto, tipoLineaBombeo, tipoLineaServicio]
                        .map((tipo) => DropdownMenuItem(
                              value: tipo,
                              child: Text(tipoLineaLabel(tipo)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        item.tipoLinea = value;
                        if (value != tipoLineaProducto) item.productoId = null;
                        widget.onChanged();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  if (item.tipoLinea == tipoLineaProducto) ...[
                    if (productos.isNotEmpty)
                      DropdownButtonFormField<int?>(
                        initialValue: item.productoId,
                        dropdownColor: AppColors.surfaceAlt(context),
                        style: TextStyle(color: textColor, fontSize: 14.5, fontWeight: FontWeight.w600),
                        icon: Icon(Icons.keyboard_arrow_down, color: mutedColor),
                        decoration: cotizacionFieldDecoration('Seleccionar producto…', mutedColor, fillColor).copyWith(
                          labelText: 'Producto',
                          labelStyle: TextStyle(color: mutedColor, fontSize: 13),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          prefixIcon: Icon(Icons.inventory_2_outlined, color: mutedColor, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: productos
                            .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nombre, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: widget.onProductoSeleccionado,
                      )
                    else
                      TextField(
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor),
                        decoration: cotizacionFieldDecoration('Producto (ID) — no se pudo cargar el catálogo', mutedColor, fillColor),
                        onChanged: (value) {
                          item.productoId = int.tryParse(value.trim());
                          widget.onChanged();
                        },
                      ),
                    const SizedBox(height: 16),
                  ],
                  
                  TextField(
                    controller: item.volumen,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                    onChanged: (_) => widget.onChanged(),
                    decoration: cotizacionFieldDecoration(
                      item.tipoLinea == tipoLineaProducto ? 'Volumen (m³)' : 'Volumen (opc)',
                      mutedColor,
                      fillColor,
                    ).copyWith(
                      labelText: 'Volumen',
                      labelStyle: TextStyle(color: mutedColor, fontSize: 13),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      prefixIcon: Icon(Icons.water_drop_outlined, color: mutedColor, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  
                  if (item.tipoLinea == tipoLineaBombeo) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Sin volumen, se usa la suma de los productos.',
                      style: TextStyle(fontSize: 11.5, color: mutedColor, fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: item.precio,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                    onChanged: (_) => widget.onChanged(),
                    decoration: cotizacionFieldDecoration('Precio unitario', mutedColor, fillColor).copyWith(
                      labelText: 'Precio Unitario',
                      labelStyle: TextStyle(color: mutedColor, fontSize: 13),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      prefixIcon: Icon(Icons.attach_money_outlined, color: mutedColor, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: item.descripcion,
                    style: TextStyle(color: textColor),
                    decoration: cotizacionFieldDecoration(
                      item.tipoLinea == tipoLineaProducto ? 'Descripción (opcional)' : 'Descripción (ej. Bombeo)',
                      mutedColor,
                      fillColor,
                    ).copyWith(
                      labelText: 'Descripción',
                      labelStyle: TextStyle(color: mutedColor, fontSize: 13),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      prefixIcon: Icon(Icons.description_outlined, color: mutedColor, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: item.descuentoLinea,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                    onChanged: (_) => widget.onChanged(),
                    decoration: cotizacionFieldDecoration('% Desc.', mutedColor, fillColor).copyWith(
                      labelText: 'Descuento',
                      labelStyle: TextStyle(color: mutedColor, fontSize: 13),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      prefixIcon: Icon(Icons.percent_outlined, color: mutedColor, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtotal Partida',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
                  ),
                  Text(
                    '\$${importeEstimado(item).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ],
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
  final bool requiereFactura;

  /// A percentage (`16` = 16 %), as `Planta.porcentajeIva` comes from the
  /// backend and as the web uses it.
  final double porcentajeIva;
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
    required this.requiereFactura,
    this.porcentajeIva = 16,
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
    final subtotalConDescuento = subtotal - descuento;
    
    final iva = requiereFactura ? subtotalConDescuento * (porcentajeIva / 100) : 0.0;
    final total = subtotalConDescuento + iva;

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
          if (requiereFactura) renglon('IVA (${porcentajeIva.toStringAsFixed(porcentajeIva == porcentajeIva.roundToDouble() ? 0 : 2)}%)', iva),
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
