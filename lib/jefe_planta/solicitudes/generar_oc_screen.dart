import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/field_group.dart';
import '../jefe_planta_service.dart';
import '../jefe_planta_widgets.dart';

const _tiposItem = {
  'material': 'Material',
  'insumo': 'Insumo',
  'servicio': 'Servicio',
};

/// The web's "Generar OC" for an autorizada solicitud: proveedor, condición
/// de pago, facturación con IVA and the artículos. Destino, planta and
/// solicitante are taken from the solicitud. On save the OC is created and
/// sent to autorización. Pops the [OrdenCompraGenerada].
class GenerarOcScreen extends StatefulWidget {
  final SolicitudCompra solicitud;

  const GenerarOcScreen({super.key, required this.solicitud});

  @override
  State<GenerarOcScreen> createState() => _GenerarOcScreenState();
}

class _GenerarOcScreenState extends State<GenerarOcScreen> {
  late Future<List<Proveedor>> _proveedores;
  Proveedor? _proveedor;
  List<ProveedorItem> _items = const [];
  bool _cargandoItems = false;
  String _condicionPago = 'contado';
  bool _conIva = true;
  final _lineas = <LineaOrdenCompra>[];
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _proveedores = JefePlantaService.proveedores();
  }

  Future<void> _elegirProveedor(Proveedor? p) async {
    if (p == null || p.id == _proveedor?.id) return;
    if (_lineas.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cambiar proveedor'),
          content: const Text(
            'Se quitarán los artículos que ya agregaste. ¿Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí, cambiar'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() {
      _proveedor = p;
      _lineas.clear();
      _items = const [];
      _cargandoItems = true;
      if (p.condicionPago == 'contado' || p.condicionPago == 'credito') {
        _condicionPago = p.condicionPago!;
      }
    });
    try {
      final items = await JefePlantaService.itemsProveedor(p.id);
      if (mounted && _proveedor?.id == p.id) setState(() => _items = items);
    } catch (_) {
      // Best-effort: without the catálogo the artículo is typed by hand.
    } finally {
      if (mounted && _proveedor?.id == p.id) {
        setState(() => _cargandoItems = false);
      }
    }
  }

  Future<void> _agregarLinea() async {
    final linea = await showModalBottomSheet<LineaOrdenCompra>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceAlt(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _LineaSheet(items: _items),
    );
    if (linea != null && mounted) setState(() => _lineas.add(linea));
  }

  double get _subtotal => _lineas.fold(0, (a, l) => a + l.importe);
  double get _iva => _conIva ? _subtotal * porcentajeIvaOrdenCompra / 100 : 0;

  Future<void> _generar() async {
    if (_proveedor == null) {
      AppSnack.error(context, 'Selecciona el proveedor');
      return;
    }
    if (_lineas.isEmpty) {
      AppSnack.error(context, 'Agrega al menos un artículo');
      return;
    }
    setState(() => _enviando = true);
    try {
      final oc = await JefePlantaService.generarOrdenCompra(
        solicitud: widget.solicitud,
        proveedorId: _proveedor!.id,
        condicionPago: _condicionPago,
        facturacionConIva: _conIva,
        lineas: List.of(_lineas),
      );
      if (mounted) Navigator.of(context).pop(oc);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) {
        AppSnack.error(context, 'No se pudo generar la orden de compra');
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final destino = s.vehiculoId != null
        ? 'Vehículo #${s.vehiculoId}'
        : s.area ?? 'General';

    Widget titulo(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        t,
        style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
      ),
    );

    Widget totalRow(String label, double v, {bool fuerte = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: fuerte ? textColor : mutedColor,
              fontWeight: fuerte ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            monedaJp.format(v),
            style: TextStyle(
              color: textColor,
              fontSize: fuerte ? 18 : 14,
              fontWeight: fuerte ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generar orden de compra'),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          FieldGroup(
            expand: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solicitud SC-${s.id}',
                  style: TextStyle(fontSize: 12, color: mutedColor),
                ),
                const SizedBox(height: 4),
                Text(
                  s.concepto,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                DatoRow(label: 'Destino', value: destino),
                if (s.montoEstimado != null)
                  DatoRow(
                    label: 'Monto estimado',
                    value: monedaJp.format(s.montoEstimado),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          titulo('Proveedor'),
          FutureBuilder<List<Proveedor>>(
            future: _proveedores,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const JefePlantaCargando();
              }
              if (snapshot.hasError) {
                return JefePlantaMensaje(
                  icon: Icons.error_outline,
                  mensaje: snapshot.error is AuthException
                      ? (snapshot.error as AuthException).message
                      : 'No se pudieron cargar los proveedores',
                  onRetry: () => setState(
                    () => _proveedores = JefePlantaService.proveedores(),
                  ),
                );
              }
              final proveedores = snapshot.data!;
              if (proveedores.isEmpty) {
                return const JefePlantaMensaje(
                  icon: Icons.storefront_outlined,
                  mensaje: 'No hay proveedores activos',
                );
              }
              return DropdownButtonFormField<Proveedor>(
                initialValue: _proveedor,
                isExpanded: true,
                decoration: campoJp(
                  context,
                  'Selecciona el proveedor',
                  prefixIcon: const Icon(Icons.storefront_outlined),
                ),
                dropdownColor: AppColors.surfaceAlt(context),
                items: [
                  for (final p in proveedores)
                    DropdownMenuItem(
                      value: p,
                      child: Text(p.nombre, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _enviando ? null : _elegirProveedor,
              );
            },
          ),
          const SizedBox(height: 20),
          titulo('Condición de pago'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'contado', label: Text('Contado')),
              ButtonSegment(value: 'credito', label: Text('Crédito')),
            ],
            selected: {_condicionPago},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.accent,
              selectedForegroundColor: AppColors.onAccent,
            ),
            onSelectionChanged: (v) => setState(() => _condicionPago = v.first),
          ),
          const SizedBox(height: 12),
          FieldGroup(
            expand: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                value: _conIva,
                onChanged: (v) => setState(() => _conIva = v),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.accent,
                title: Text(
                  'Facturación con IVA',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  'Suma ${porcentajeIvaOrdenCompra.toStringAsFixed(0)}% al total',
                  style: TextStyle(fontSize: 12, color: mutedColor),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: titulo('Artículos')),
              if (_cargandoItems)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          if (_lineas.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _proveedor == null
                    ? 'Selecciona un proveedor primero.'
                    : 'Agrega los artículos que incluye esta orden.',
                style: TextStyle(color: mutedColor),
              ),
            ),
          for (var i = 0; i < _lineas.length; i++) ...[
            _LineaCard(
              linea: _lineas[i],
              onQuitar: () => setState(() => _lineas.removeAt(i)),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _proveedor == null || _cargandoItems || _enviando
                  ? null
                  : _agregarLinea,
              icon: const Icon(Icons.add),
              label: const Text('Agregar artículo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                side: BorderSide(color: AppColors.border(context, alpha: 0.15)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (_lineas.isNotEmpty) ...[
            const SizedBox(height: 16),
            FieldGroup(
              expand: true,
              child: Column(
                children: [
                  totalRow('Subtotal', _subtotal),
                  if (_conIva)
                    totalRow(
                      'IVA ${porcentajeIvaOrdenCompra.toStringAsFixed(0)}%',
                      _iva,
                    ),
                  const Divider(height: 16),
                  totalRow('Total', _subtotal + _iva, fuerte: true),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _enviando ? null : _generar,
              style: botonPrimarioJp(),
              icon: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.receipt_long_outlined),
              label: const Text(
                'Generar OC y enviar a autorización',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineaCard extends StatelessWidget {
  final LineaOrdenCompra linea;
  final VoidCallback onQuitar;

  const _LineaCard({required this.linea, required this.onQuitar});

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cantidad = linea.cantidad % 1 == 0
        ? linea.cantidad.toStringAsFixed(0)
        : linea.cantidad.toString();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  linea.descripcion,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_tiposItem[linea.tipoItem] ?? linea.tipoItem} · '
                  '$cantidad${linea.unidad == null ? '' : ' ${linea.unidad}'} × '
                  '${monedaJp.format(linea.precioUnitario)}',
                  style: TextStyle(fontSize: 12.5, color: mutedColor),
                ),
              ],
            ),
          ),
          Text(
            monedaJp.format(linea.importe),
            style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
          ),
          IconButton(
            tooltip: 'Quitar',
            icon: Icon(Icons.close, color: mutedColor, size: 20),
            onPressed: onQuitar,
          ),
        ],
      ),
    );
  }
}

/// Adds one artículo: either from the proveedor's catálogo (prefills tipo,
/// nombre and precio de referencia) or typed by hand.
class _LineaSheet extends StatefulWidget {
  final List<ProveedorItem> items;

  const _LineaSheet({required this.items});

  @override
  State<_LineaSheet> createState() => _LineaSheetState();
}

class _LineaSheetState extends State<_LineaSheet> {
  final _formKey = GlobalKey<FormState>();
  ProveedorItem? _item;
  String _tipo = 'material';
  final _descripcion = TextEditingController();
  final _cantidad = TextEditingController(text: '1');
  final _unidad = TextEditingController();
  final _precio = TextEditingController();

  @override
  void dispose() {
    _descripcion.dispose();
    _cantidad.dispose();
    _unidad.dispose();
    _precio.dispose();
    super.dispose();
  }

  void _elegirItem(ProveedorItem? item) {
    setState(() {
      _item = item;
      if (item != null) {
        _tipo = _tiposItem.containsKey(item.tipoItem)
            ? item.tipoItem
            : 'material';
        _descripcion.text = item.nombre;
        if (item.precioReferencia != null) {
          _precio.text = item.precioReferencia!.toStringAsFixed(2);
        }
      }
    });
  }

  double? _numero(String t) => double.tryParse(t.replaceAll(',', '').trim());

  void _agregar() {
    if (!_formKey.currentState!.validate()) return;
    final unidad = _unidad.text.trim();
    Navigator.of(context).pop(
      LineaOrdenCompra(
        tipoItem: _tipo,
        materialId: _item?.materialId,
        insumoId: _item?.insumoId,
        servicioId: _item?.servicioId,
        descripcion: _descripcion.text.trim(),
        unidad: unidad.isEmpty ? null : unidad,
        cantidad: _numero(_cantidad.text)!,
        precioUnitario: _numero(_precio.text)!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHeader(title: 'Agregar artículo'),
                const SizedBox(height: 16),
                if (widget.items.isNotEmpty) ...[
                  DropdownButtonFormField<ProveedorItem?>(
                    initialValue: _item,
                    isExpanded: true,
                    decoration: campoJp(
                      context,
                      'Catálogo del proveedor',
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                    ),
                    dropdownColor: AppColors.surfaceAlt(context),
                    items: [
                      const DropdownMenuItem<ProveedorItem?>(
                        value: null,
                        child: Text('Otro (escribirlo)'),
                      ),
                      for (final i in widget.items)
                        DropdownMenuItem<ProveedorItem?>(
                          value: i,
                          child: Text(
                            i.precioReferencia == null
                                ? i.nombre
                                : '${i.nombre} · ${monedaJp.format(i.precioReferencia)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _elegirItem,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_item == null) ...[
                  Text(
                    'Tipo',
                    style: TextStyle(fontSize: 12.5, color: mutedColor),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final e in _tiposItem.entries)
                        ChoiceChip(
                          label: Text(e.value),
                          selected: _tipo == e.key,
                          showCheckmark: false,
                          selectedColor: AppColors.accent,
                          backgroundColor: AppColors.border(
                            context,
                            alpha: 0.06,
                          ),
                          side: BorderSide.none,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _tipo == e.key
                                ? AppColors.onAccent
                                : textColor,
                          ),
                          onSelected: (_) => setState(() => _tipo = e.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _descripcion,
                  style: TextStyle(color: textColor),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: campoJp(context, 'Descripción'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe la descripción'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cantidad,
                        style: TextStyle(color: textColor),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: campoJp(context, 'Cantidad'),
                        validator: (v) {
                          final n = _numero(v ?? '');
                          return n == null || n <= 0 ? 'Inválida' : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _unidad,
                        style: TextStyle(color: textColor),
                        decoration: campoJp(
                          context,
                          'Unidad',
                          hint: 'pza, kg…',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _precio,
                  style: TextStyle(color: textColor),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: campoJp(
                    context,
                    'Precio unitario',
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                  validator: (v) {
                    final n = _numero(v ?? '');
                    return n == null || n < 0 ? 'Precio inválido' : null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _agregar,
                    style: botonPrimarioJp(),
                    child: const Text(
                      'Agregar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
