import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/auth_service.dart';
import '../catalogo/catalogo_service.dart';
import '../catalogo/planta.dart';
import '../catalogo/producto.dart';
import '../direccion/comercial_service.dart';
import '../direccion/pedido.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/field_group.dart';
import 'asesor_comercial_service.dart';
import 'cliente_picker_screen.dart';
import 'cotizacion.dart';
import 'obra_picker_screen.dart';

/// One editable línea/partida row. `tipoLinea` is [tipoLineaProducto],
/// [tipoLineaBombeo] or [tipoLineaServicio] only — never
/// [tipoLineaFleteVacio], which the backend generates itself and this app
/// must never resend (see `cotizacion.dart`). `productoId`/`tipoLinea`
/// aren't controllers (they're selections, not free text).
class _ItemControllers {
  final volumen = TextEditingController();
  final precio = TextEditingController();
  final descripcion = TextEditingController();
  String tipoLinea;
  int? productoId;

  _ItemControllers({this.tipoLinea = tipoLineaProducto});

  /// Existing `flete_vacio` líneas must be filtered out by the caller before
  /// reaching this factory — see [CotizacionFormScreen]'s edit-mode
  /// `initState`.
  factory _ItemControllers.from(CotizacionItem item) {
    final tipo = item.tipoLinea == tipoLineaBombeo || item.tipoLinea == tipoLineaServicio
        ? item.tipoLinea!
        : tipoLineaProducto;
    final c = _ItemControllers(tipoLinea: tipo);
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

/// Creates or edits a `Cotizacion`. When opened from a `VisitaDetailScreen`,
/// `clienteId`/`obraId` come prefilled and read-only. Opened standalone
/// (from `CotizacionesScreen`'s "+", with no cliente/obra given at all) —
/// the web app allows this too, a cotización doesn't have to originate from
/// a visita — cliente/obra become interactive pickers instead. A cotización
/// now holds one or more línea items (`productos`, at least one required by
/// the backend) rather than a single product/volumen/precio, so this form
/// manages a dynamic list of them. Planta and producto are picked from the
/// real `catalogo-service` catalog (same one the web app's "Nueva
/// cotización" screen uses) rather than typed as raw ids.
class CotizacionFormScreen extends StatefulWidget {
  final int? clienteId;
  final String? clienteNombre;
  final int? obraId;
  final String? obraNombre;
  final int? obraPlantaId;
  final Cotizacion? cotizacion;

  const CotizacionFormScreen({
    super.key,
    this.clienteId,
    this.clienteNombre,
    this.obraId,
    this.obraNombre,
    this.obraPlantaId,
    this.cotizacion,
  });

  bool get esEdicion => cotizacion != null;

  /// True when cliente/obra came prefilled from a Visita or from the
  /// cotización being edited — shown read-only rather than as pickers.
  bool get origenFijo => cotizacion != null || clienteId != null;

  @override
  State<CotizacionFormScreen> createState() => _CotizacionFormScreenState();
}

class _CotizacionFormScreenState extends State<CotizacionFormScreen> {
  String? _tipoServicio;
  final _descuentoController = TextEditingController();
  String? _formaPago;
  final _plantaIdManualController = TextEditingController();
  final List<_ItemControllers> _items = [];
  DateTime? _fechaSuministro;
  bool _requiereFactura = false;
  bool _enviando = false;
  bool _cargandoCatalogo = true;
  List<Planta> _plantas = [];
  List<Producto> _productos = [];
  int? _plantaId;
  int? _asesorId;
  String? _asesorNombre;
  late final Future<void> _asesorFuture;
  int? _clienteId;
  String? _clienteNombre;
  int? _obraId;
  String? _obraNombre;
  int? _contactoId;
  List<ClienteContacto> _contactos = [];

  @override
  void initState() {
    super.initState();
    final c = widget.cotizacion;
    if (c != null) {
      _clienteId = c.clienteId;
      _clienteNombre = c.clienteNombre;
      _obraId = c.obraId;
      _obraNombre = c.obraNombre;
      _contactoId = c.contactoId;
      _plantaId = c.plantaId;
      // Preserved as-is: editing shouldn't silently reassign a cotización
      // to whoever happens to be editing it — only a brand-new one defaults
      // to the logged-in advisor (see the else branch/_resolverAsesor).
      _asesorId = c.asesorId;
      _asesorNombre = c.asesorNombre;
      _asesorFuture = Future.value();
      _tipoServicio = c.tipoServicio;
      _formaPago = c.formaPago;
      _requiereFactura = c.requiereFactura;
      if (c.porcentajeDescuento > 0) _descuentoController.text = '${c.porcentajeDescuento}';
      if (c.fechaSuministroEstimada != null) _fechaSuministro = DateTime.tryParse(c.fechaSuministroEstimada!);
      _items.addAll(
        c.productos.where((p) => p.tipoLinea != tipoLineaFleteVacio).map(_ItemControllers.from),
      );
      if (_items.isEmpty) _items.add(_ItemControllers());
    } else {
      _clienteId = widget.clienteId;
      _clienteNombre = widget.clienteNombre;
      _obraId = widget.obraId;
      _obraNombre = widget.obraNombre;
      _items.add(_ItemControllers());
      _plantaId = widget.obraPlantaId;
      _asesorFuture = _resolverAsesor();
    }
    _plantaIdManualController.text = _plantaId == null ? '' : '$_plantaId';
    if (_clienteId != null) _cargarContactos();
    _cargarCatalogo();
  }

  /// Standalone flow only (`!widget.origenFijo`) — resets the previously
  /// picked obra/contacto, since both belonged to whichever cliente was
  /// selected before.
  Future<void> _elegirCliente() async {
    final cliente = await Navigator.of(context).push<Cliente>(
      MaterialPageRoute(builder: (context) => const ClientePickerScreen()),
    );
    if (cliente == null || !mounted) return;
    setState(() {
      _clienteId = cliente.id;
      _clienteNombre = cliente.nombre;
      _obraId = null;
      _obraNombre = null;
      _contactoId = null;
      _contactos = [];
    });
    _cargarContactos();
  }

  Future<void> _cargarContactos() async {
    final clienteId = _clienteId;
    if (clienteId == null) return;
    try {
      final contactos = await ComercialService.contactosCliente(clienteId);
      if (mounted) setState(() => _contactos = contactos);
    } catch (_) {
      // Best-effort — the contacto row just shows no options to pick from.
    }
  }

  ClienteContacto? _contactoConId(int? id) {
    if (id == null) return null;
    for (final c in _contactos) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _elegirContacto() async {
    final elegido = await showModalBottomSheet<ClienteContacto>(
      context: context,
      backgroundColor: AppColors.surfaceAlt(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final textColor = AppColors.text(context);
        final mutedColor = AppColors.mutedText(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_contactos.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Este cliente no tiene contactos registrados', style: TextStyle(color: mutedColor)),
                )
              else
                for (final contacto in _contactos)
                  ListTile(
                    title: Text(contacto.nombre, style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
                    subtitle: contacto.cargo != null ? Text(contacto.cargo!, style: TextStyle(color: mutedColor)) : null,
                    onTap: () => Navigator.of(context).pop(contacto),
                  ),
            ],
          ),
        );
      },
    );
    if (elegido == null || !mounted) return;
    setState(() => _contactoId = elegido.id);
  }

  void _quitarContacto() => setState(() => _contactoId = null);

  Future<void> _elegirObra() async {
    final clienteId = _clienteId;
    if (clienteId == null) return;
    final obra = await Navigator.of(context).push<Obra>(
      MaterialPageRoute(
        builder: (context) => ObraPickerScreen(clienteId: clienteId, clienteNombre: _clienteNombre ?? ''),
      ),
    );
    if (obra == null || !mounted) return;
    setState(() {
      _obraId = obra.id;
      _obraNombre = obra.nombre;
      if (_plantaId == null && obra.plantaId != null) {
        _plantaId = obra.plantaId;
        _plantaIdManualController.text = '${obra.plantaId}';
      }
    });
  }

  void _quitarObra() => setState(() {
    _obraId = null;
    _obraNombre = null;
  });

  /// Best-effort — the planta/producto selects just show empty if
  /// `catalogo-service` doesn't respond, rather than blocking the form.
  Future<void> _cargarCatalogo() async {
    List<Planta> plantas = const [];
    List<Producto> productos = const [];
    try {
      final resultados = await Future.wait([CatalogoService.plantas(), CatalogoService.productos()]);
      plantas = resultados[0] as List<Planta>;
      productos = resultados[1] as List<Producto>;
    } catch (_) {
      // Falls through with empty catalogs below.
    }
    if (!mounted) return;
    setState(() {
      _plantas = plantas;
      _productos = productos;
      _cargandoCatalogo = false;
    });
  }

  /// Resolves the logged-in advisor's own id — `crearCotizacion`/
  /// `actualizarCotizacion` need it sent explicitly (not left for the
  /// backend to infer) since `misCotizaciones` filters client-side by
  /// `asesorId`: a cotización saved without it wouldn't show up in "mis
  /// cotizaciones" afterward. Also seeds [_plantaId] from the advisor's own
  /// planta when nothing else (obra, editing an existing cotización) already
  /// set one.
  Future<void> _resolverAsesor() async {
    try {
      final asesor = await AsesorComercialService.miAsesor();
      if (!mounted || asesor == null) return;
      setState(() {
        _asesorId = asesor.id;
        _asesorNombre = asesor.nombre;
        if (_plantaId == null && asesor.plantaId != null) {
          _plantaId = asesor.plantaId;
          _plantaIdManualController.text = '${asesor.plantaId}';
        }
      });
    } catch (_) {
      // Best-effort — plantaId/asesorId stay resolvable manually either way.
    }
  }

  Producto? _productoConId(int? id) {
    if (id == null) return null;
    for (final p in _productos) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> _onProductoSeleccionado(_ItemControllers item, int? productoId) async {
    setState(() => item.productoId = productoId);
    final producto = _productoConId(productoId);
    if (producto != null && item.descripcion.text.trim().isEmpty) {
      setState(() => item.descripcion.text = producto.nombre);
    }
    if (productoId == null || _plantaId == null || item.precio.text.trim().isNotEmpty) return;
    try {
      final precios = await CatalogoService.preciosProducto(productoId, plantaId: _plantaId);
      if (mounted && precios.isNotEmpty && item.precio.text.trim().isEmpty) {
        setState(() => item.precio.text = '${precios.first.precio}');
      }
    } catch (_) {
      // Best-effort autofill — the field stays editable either way.
    }
  }

  @override
  void dispose() {
    _descuentoController.dispose();
    _plantaIdManualController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final hoy = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSuministro ?? hoy,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 365)),
      locale: const Locale('es'),
      builder: (context, child) {
        final base = Theme.of(context);
        return Theme(
          data: base.copyWith(colorScheme: base.colorScheme.copyWith(primary: AppColors.accent, onPrimary: Colors.black)),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _fechaSuministro = picked);
  }

  void _agregarPartida(String tipoLinea) => setState(() => _items.add(_ItemControllers(tipoLinea: tipoLinea)));

  void _quitarPartida(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _submit() async {
    // Guarantees _asesorId is resolved before building the request, even if
    // the user submits before _resolverAsesor's network call finishes —
    // otherwise the cotización would save without it and never show up in
    // "mis cotizaciones" (filtered client-side by asesorId).
    await _asesorFuture;
    if (!mounted) return;
    if (_asesorId == null) {
      AppSnack.error(context, 'No se pudo confirmar tu perfil de asesor. Revisa tu conexión e inténtalo de nuevo.');
      return;
    }
    if (_clienteId == null) {
      AppSnack.error(context, 'Selecciona el cliente para esta cotización');
      return;
    }
    if (_plantaId == null) {
      AppSnack.error(context, 'Selecciona la planta que atenderá esta cotización');
      return;
    }

    final productos = <CotizacionItem>[];
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final precio = double.tryParse(item.precio.text.trim());
      if (precio == null) {
        AppSnack.error(context, 'La partida ${i + 1} necesita un precio unitario válido');
        return;
      }
      final volumen = double.tryParse(item.volumen.text.trim());
      // Only 'producto' líneas need productoId+volumenM3 — 'bombeo' has
      // neither (the backend autofills volumenM3 for bombeo when omitted).
      if (item.tipoLinea == tipoLineaProducto) {
        if (item.productoId == null) {
          AppSnack.error(context, 'Selecciona un producto para la partida ${i + 1}');
          return;
        }
        if (volumen == null) {
          AppSnack.error(context, 'La partida ${i + 1} necesita un volumen');
          return;
        }
      }
      productos.add(CotizacionItem(
        tipoLinea: item.tipoLinea,
        productoId: item.tipoLinea == tipoLineaProducto ? item.productoId : null,
        volumenM3: volumen,
        precioUnitario: precio,
        descripcion: item.descripcion.text.trim().isEmpty ? null : item.descripcion.text.trim(),
      ));
    }
    if (productos.isEmpty) {
      AppSnack.error(context, 'Agrega al menos una partida');
      return;
    }

    setState(() => _enviando = true);
    try {
      final tipoServicio = _tipoServicio;
      final formaPago = _formaPago;
      // Anyone can request a discount up to the backend's own limit per
      // forma de pago — only exceeding it needs permisoAplicarDescuentoEspecial,
      // enforced server-side, not by hiding this field client-side.
      final porcentajeDescuento =
          _descuentoController.text.trim().isEmpty ? null : double.tryParse(_descuentoController.text.trim());

      if (widget.esEdicion) {
        await AsesorComercialService.actualizarCotizacion(
          widget.cotizacion!.id,
          clienteId: _clienteId!,
          plantaId: _plantaId!,
          productos: productos,
          obraId: _obraId,
          contactoId: _contactoId,
          asesorId: _asesorId,
          tipoServicio: tipoServicio,
          formaPago: formaPago,
          requiereFactura: _requiereFactura,
          fechaSuministroEstimada: _fechaSuministro,
          porcentajeDescuento: porcentajeDescuento,
        );
      } else {
        await AsesorComercialService.crearCotizacion(
          clienteId: _clienteId!,
          plantaId: _plantaId!,
          productos: productos,
          obraId: _obraId,
          contactoId: _contactoId,
          asesorId: _asesorId,
          tipoServicio: tipoServicio,
          formaPago: formaPago,
          requiereFactura: _requiereFactura,
          fechaSuministroEstimada: _fechaSuministro,
          porcentajeDescuento: porcentajeDescuento,
        );
      }
      if (!mounted) return;
      AppSnack.success(context, widget.esEdicion ? 'Cotización actualizada' : 'Cotización creada');
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, widget.esEdicion ? 'No se pudo actualizar la cotización' : 'No se pudo crear la cotización');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  InputDecoration _decoration(String hint, Color mutedColor, Color fillColor) {
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

  /// Read-only info row (Asesor encargado, or Cliente/Obra when
  /// `widget.origenFijo` — those came prefilled from a Visita/the cotización
  /// being edited and aren't picked freehand here).
  Widget _filaInfo({
    required IconData icon,
    required String texto,
    required Color textColor,
    required Color mutedColor,
    required Color fillColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: mutedColor),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: TextStyle(color: textColor, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  /// Tappable row (Cliente/Obra when standalone, Contacto always) — opens a
  /// picker via [onTap]; [onClear] shows a small "x" instead of the chevron
  /// once something is picked, so it can be unset without reopening the
  /// picker (mirrors Obra's own already-existing pattern).
  Widget _filaSeleccionable({
    required IconData icon,
    required String? texto,
    required String placeholder,
    required VoidCallback? onTap,
    required Color textColor,
    required Color mutedColor,
    required Color fillColor,
    VoidCallback? onClear,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(icon, size: 18, color: mutedColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                texto ?? placeholder,
                style: TextStyle(color: texto == null ? mutedColor : textColor, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: mutedColor,
                onPressed: onClear,
                visualDensity: VisualDensity.compact,
              )
            else if (onTap != null)
              Icon(Icons.chevron_right, color: mutedColor),
          ],
        ),
      ),
    );
  }

  Widget _plantaField(Color textColor, Color mutedColor, Color fillColor) {
    final plantaIdValida = _plantaId != null && _plantas.any((p) => p.id == _plantaId) ? _plantaId : null;
    if (_plantas.isEmpty) {
      return TextField(
        enabled: !_cargandoCatalogo,
        keyboardType: TextInputType.number,
        style: TextStyle(color: textColor),
        controller: _plantaIdManualController,
        onChanged: (value) => _plantaId = int.tryParse(value.trim()),
        decoration: _decoration(
          _cargandoCatalogo ? 'Cargando plantas…' : 'Planta (ID) — no se pudo cargar el catálogo',
          mutedColor,
          fillColor,
        ),
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: plantaIdValida,
      dropdownColor: AppColors.surfaceAlt(context),
      style: TextStyle(color: textColor, fontSize: 14.5),
      decoration: _decoration('Seleccionar planta…', mutedColor, fillColor),
      items: _plantas
          .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nombre, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (value) => setState(() => _plantaId = value),
    );
  }

  Widget _partidaCard(int index, Color textColor, Color mutedColor, Color cardColor, Color borderColor, Color fillColor) {
    final item = _items[index];
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
              if (_items.length > 1)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: mutedColor,
                  onPressed: () => _quitarPartida(index),
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
                onSelected: (_) => setState(() {
                  item.tipoLinea = tipo;
                  if (tipo != tipoLineaProducto) item.productoId = null;
                }),
                selectedColor: AppColors.accent,
                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: seleccionado ? Colors.black : textColor),
                backgroundColor: fillColor,
                side: BorderSide.none,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (item.tipoLinea == tipoLineaProducto) ...[
            if (_productos.isNotEmpty)
              DropdownButtonFormField<int?>(
                initialValue: item.productoId,
                dropdownColor: AppColors.surfaceAlt(context),
                style: TextStyle(color: textColor, fontSize: 14.5),
                decoration: _decoration('Seleccionar producto…', mutedColor, fillColor),
                items: _productos
                    .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nombre, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (value) => _onProductoSeleccionado(item, value),
              )
            else
              TextField(
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: _decoration('Producto (ID) — no se pudo cargar el catálogo', mutedColor, fillColor),
                onChanged: (value) => setState(() => item.productoId = int.tryParse(value.trim())),
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
                  onChanged: (_) => setState(() {}),
                  decoration: _decoration(
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
                  onChanged: (_) => setState(() {}),
                  decoration: _decoration('Precio unitario', mutedColor, fillColor),
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
            decoration: _decoration(
              item.tipoLinea == tipoLineaProducto ? 'Descripción (opcional)' : 'Descripción (ej. Bombeo pluma propia)',
              mutedColor,
              fillColor,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Importe estimado: \$${_importeEstimado(item).toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: mutedColor),
            ),
          ),
        ],
      ),
    );
  }

  /// Client-side estimate only — the backend's own `precioTotal` per línea
  /// (shown in `CotizacionDetailScreen` after saving) is authoritative. A
  /// `producto` línea is precio × volumen; `bombeo`/`servicio` are typically
  /// a flat fee, so just precio.
  double _importeEstimado(_ItemControllers item) {
    final precio = double.tryParse(item.precio.text.trim()) ?? 0;
    if (item.tipoLinea != tipoLineaProducto) return precio;
    final volumen = double.tryParse(item.volumen.text.trim()) ?? 0;
    return precio * volumen;
  }

  double _sumaPorTipo(String tipoLinea) => _items
      .where((i) => i.tipoLinea == tipoLinea)
      .fold(0.0, (sum, i) => sum + _importeEstimado(i));

  Planta? get _plantaSeleccionada {
    for (final p in _plantas) {
      if (p.id == _plantaId) return p;
    }
    return null;
  }

  /// Mirrors the backend's own rule (see `cotizacion.dart`): one flete_vacio
  /// per `producto` línea whose volumen doesn't divide evenly into the
  /// planta's `capacidadReferenciaM3`, charged at `precioPorM3Vacio` for the
  /// leftover (vacío) capacity. Preview only — needs a planta with both
  /// fields set, otherwise there's nothing to estimate from.
  double _fleteVacioEstimado() {
    final planta = _plantaSeleccionada;
    final capacidad = planta?.capacidadReferenciaM3;
    final precioVacio = planta?.precioPorM3Vacio;
    if (capacidad == null || capacidad <= 0 || precioVacio == null) return 0;
    var total = 0.0;
    for (final item in _items) {
      if (item.tipoLinea != tipoLineaProducto) continue;
      final volumen = double.tryParse(item.volumen.text.trim()) ?? 0;
      if (volumen <= 0) continue;
      final residuo = volumen % capacidad;
      if (residuo == 0) continue;
      total += (capacidad - residuo) * precioVacio;
    }
    return total;
  }

  Widget _resumenCotizacion(Color textColor, Color mutedColor, Color cardColor, Color borderColor) {
    final subtotalProductos = _sumaPorTipo(tipoLineaProducto);
    final subtotalBombeo = _sumaPorTipo(tipoLineaBombeo);
    final subtotalServicios = _sumaPorTipo(tipoLineaServicio);
    final fleteVacio = _fleteVacioEstimado();
    final subtotal = subtotalProductos + subtotalBombeo + subtotalServicios + fleteVacio;
    final porcentajeDescuento = double.tryParse(_descuentoController.text.trim()) ?? 0;
    // Only líneas producto se descuentan — bombeo/servicio/flete_vacío no.
    final descuento = subtotalProductos * (porcentajeDescuento / 100);
    final total = subtotal - descuento;

    Widget renglon(String label, double valor, {bool negativo = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: mutedColor))),
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
          Text('Resumen de cotización', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
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
                child: Text('Total estimado', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: textColor)),
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

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.10);
    final fillColor = AppColors.border(context, alpha: 0.06);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.esEdicion ? 'Editar cotización' : 'Nueva cotización'),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text('Cliente y obra', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 8),
          if (widget.origenFijo)
            _filaInfo(
              icon: Icons.business_outlined,
              texto: _clienteNombre ?? '',
              textColor: textColor,
              mutedColor: mutedColor,
              fillColor: fillColor,
            )
          else
            _filaSeleccionable(
              icon: Icons.business_outlined,
              texto: _clienteNombre,
              placeholder: 'Seleccionar cliente…',
              onTap: _elegirCliente,
              textColor: textColor,
              mutedColor: mutedColor,
              fillColor: fillColor,
            ),
          const SizedBox(height: 12),
          if (widget.origenFijo)
            _filaInfo(
              icon: Icons.location_on_outlined,
              texto: _obraNombre ?? (_obraId != null ? 'Obra #$_obraId' : 'Sin obra específica'),
              textColor: _obraNombre == null && _obraId == null ? mutedColor : textColor,
              mutedColor: mutedColor,
              fillColor: fillColor,
            )
          else
            _filaSeleccionable(
              icon: Icons.location_on_outlined,
              texto: _obraNombre,
              placeholder: 'Sin obra específica',
              onTap: _clienteId == null ? null : _elegirObra,
              onClear: _obraNombre != null ? _quitarObra : null,
              textColor: textColor,
              mutedColor: mutedColor,
              fillColor: fillColor,
            ),
          const SizedBox(height: 12),
          _filaSeleccionable(
            icon: Icons.person_outline,
            texto: _contactoConId(_contactoId)?.nombre,
            placeholder: 'Sin contacto específico',
            onTap: _clienteId == null ? null : _elegirContacto,
            onClear: _contactoId != null ? _quitarContacto : null,
            textColor: textColor,
            mutedColor: mutedColor,
            fillColor: fillColor,
          ),
          const SizedBox(height: 12),
          _filaInfo(
            icon: Icons.badge_outlined,
            texto: _asesorNombre ?? 'Resolviendo…',
            textColor: textColor,
            mutedColor: mutedColor,
            fillColor: fillColor,
          ),
          const SizedBox(height: 12),
          _plantaField(textColor, mutedColor, fillColor),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickFecha,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 18, color: mutedColor),
                  const SizedBox(width: 12),
                  Text(
                    _fechaSuministro == null ? 'Fecha de suministro estimada' : DateFormat('d/MM/y').format(_fechaSuministro!),
                    style: TextStyle(color: _fechaSuministro == null ? mutedColor : textColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Condiciones comerciales', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _tipoServicio,
            dropdownColor: AppColors.surfaceAlt(context),
            style: TextStyle(color: textColor, fontSize: 14.5),
            decoration: _decoration('Tipo de servicio', mutedColor, fillColor),
            items: tipoServicioOpciones.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (value) => setState(() => _tipoServicio = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _formaPago,
            dropdownColor: AppColors.surfaceAlt(context),
            style: TextStyle(color: textColor, fontSize: 14.5),
            decoration: _decoration('Forma de pago', mutedColor, fillColor),
            items: formaPagoOpciones.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (value) => setState(() => _formaPago = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descuentoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: textColor),
            onChanged: (_) => setState(() {}),
            decoration: _decoration('% Descuento', mutedColor, fillColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Un descuento mayor al límite (${limiteDescuentoTexto(_requiereFactura)}) requiere autorización.',
            style: TextStyle(fontSize: 11.5, color: mutedColor),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _requiereFactura,
            onChanged: (value) => setState(() => _requiereFactura = value),
            title: Text('Requiere factura fiscal', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.accent,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Productos y servicios',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: _agregarPartida,
                color: AppColors.surfaceAlt(context),
                itemBuilder: (context) => [
                  PopupMenuItem(value: tipoLineaProducto, child: Text(tipoLineaLabel(tipoLineaProducto))),
                  PopupMenuItem(value: tipoLineaBombeo, child: Text(tipoLineaLabel(tipoLineaBombeo))),
                  PopupMenuItem(value: tipoLineaServicio, child: Text(tipoLineaLabel(tipoLineaServicio))),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 18, color: textColor),
                      const SizedBox(width: 6),
                      Text('Agregar producto o servicio', style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _items.length; i++) ...[
            _partidaCard(i, textColor, mutedColor, cardColor, borderColor, fillColor),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          _resumenCotizacion(textColor, mutedColor, cardColor, borderColor),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _enviando ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _enviando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                  : Text(widget.esEdicion ? 'Guardar cambios' : 'Crear cotización', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
