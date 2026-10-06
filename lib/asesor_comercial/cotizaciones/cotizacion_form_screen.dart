import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../auth/auth_service.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    show LatLng;
import '../../catalogo/catalogo_service.dart';
import '../../catalogo/elemento_constructivo.dart';
import '../../catalogo/planta.dart';
import '../../catalogo/producto.dart';
import '../../comercial/comercial_service.dart';
import '../../direccion/live_tracking/directions_service.dart';
import '../../comercial/pedido.dart';
import '../../operaciones/operaciones_service.dart';
import '../../operaciones/produccion.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_feedback.dart';
import '../asesor_comercial_service.dart';
import '../clientes_obras/cliente_picker_screen.dart';
import 'cotizacion.dart';
import 'cotizacion_form_widgets.dart';
import '../clientes_obras/obra_picker_screen.dart';

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
  int _currentStep = 0;
  String? _tipoServicio;
  final _descuentoController = TextEditingController();
  String? _formaPago;
  final _plantaIdManualController = TextEditingController();
  final List<PartidaControllers> _items = [];
  DateTime? _fechaSuministro;
  bool _requiereFactura = false;
  bool _enviando = false;
  bool _cargandoCatalogo = true;
  List<Planta> _plantas = [];
  List<Producto> _productos = [];
  List<ElementoConstructivo> _elementos = [];
  int? _plantaId;
  int? _asesorId;
  String? _asesorNombre;
  late final Future<void> _asesorFuture;
  int? _clienteId;
  String? _clienteNombre;
  int? _obraId;
  String? _obraNombre;
  int? _contactoId;
  String? _horarioEntrega;
  int? _elementoConstructivoId;
  String? _distanciaKm;
  final _distanciaController = TextEditingController();
  final _observacionesController = TextEditingController();
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
      _horarioEntrega = c.horarioEntrega;
      _elementoConstructivoId = c.elementoConstructivoId;
      _distanciaKm = c.distanciaKm?.toString();
      if (c.distanciaKm != null) _distanciaController.text = _distanciaKm!;
      if (c.observaciones != null)
        _observacionesController.text = c.observaciones!;
      if (c.porcentajeDescuento > 0)
        _descuentoController.text = '${c.porcentajeDescuento}';
      if (c.fechaSuministroEstimada != null)
        _fechaSuministro = DateTime.tryParse(c.fechaSuministroEstimada!);
      _items.addAll(
        c.productos
            .where((p) => p.tipoLinea != tipoLineaFleteVacio)
            .map(PartidaControllers.from),
      );
      if (_items.isEmpty) _items.add(PartidaControllers());
    } else {
      _clienteId = widget.clienteId;
      _clienteNombre = widget.clienteNombre;
      _obraId = widget.obraId;
      _obraNombre = widget.obraNombre;
      _items.add(PartidaControllers());
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  child: Text(
                    'Este cliente no tiene contactos registrados',
                    style: TextStyle(color: mutedColor),
                  ),
                )
              else
                for (final contacto in _contactos)
                  ListTile(
                    title: Text(
                      contacto.nombre,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: contacto.cargo != null
                        ? Text(
                            contacto.cargo!,
                            style: TextStyle(color: mutedColor),
                          )
                        : null,
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
        builder: (context) => ObraPickerScreen(
          clienteId: clienteId,
          clienteNombre: _clienteNombre ?? '',
        ),
      ),
    );
    if (obra == null || !mounted) return;
    setState(() {
      _obraId = obra.id;
      _obraNombre = obra.nombre;
      if (_plantaId == null) {
        if (obra.plantaId != null) {
          _plantaId = obra.plantaId;
          _plantaIdManualController.text = '${obra.plantaId}';
        } else if (_plantas.isNotEmpty && obra.latitud != 0) {
          Planta? closest;
          double minD = double.infinity;
          final pRatio = 0.017453292519943295;
          for (final p in _plantas) {
            if (p.latitud != null && p.longitud != null) {
              final a = 0.5 - math.cos((obra.latitud - p.latitud!) * pRatio)/2 + 
                        math.cos(p.latitud! * pRatio) * math.cos(obra.latitud * pRatio) * 
                        (1 - math.cos((obra.longitud - p.longitud!) * pRatio))/2;
              final d = 12742 * math.asin(math.sqrt(a));
              if (d < minD) {
                minD = d;
                closest = p;
              }
            }
          }
          if (closest != null) {
            _plantaId = closest.id;
            _plantaIdManualController.text = '${closest.id}';
          }
        }
      }
    });
    _recalcularDistancia();
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
    List<ElementoConstructivo> elementos = const [];
    try {
      final resultados = await Future.wait([
        CatalogoService.plantas(),
        CatalogoService.productos(),
        CatalogoService.elementosConstructivos(),
      ]);
      plantas = resultados[0] as List<Planta>;
      productos = resultados[1] as List<Producto>;
      elementos = resultados[2] as List<ElementoConstructivo>;
    } catch (_) {
      // Falls through with empty catalogs below.
    }
    if (!mounted) return;
    setState(() {
      _plantas = plantas;
      _productos = productos;
      _elementos = elementos;
      _cargandoCatalogo = false;
    });
    if (_plantaId != null &&
        _obraId != null &&
        (_distanciaKm == null || _distanciaKm!.isEmpty)) {
      _recalcularDistancia();
    }
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
      if (_plantaId != null &&
          _obraId != null &&
          (_distanciaKm == null || _distanciaKm!.isEmpty)) {
        _recalcularDistancia();
      }
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

  Future<void> _onProductoSeleccionado(
    PartidaControllers item,
    int? productoId,
  ) async {
    setState(() => item.productoId = productoId);
    final producto = _productoConId(productoId);
    if (producto != null && item.descripcion.text.trim().isEmpty) {
      setState(() => item.descripcion.text = producto.nombre);
    }
    if (productoId == null ||
        _plantaId == null ||
        item.precio.text.trim().isNotEmpty)
      return;
    try {
      final precios = await CatalogoService.preciosProducto(
        productoId,
        plantaId: _plantaId,
      );
      if (mounted && precios.isNotEmpty && item.precio.text.trim().isEmpty) {
        setState(() => item.precio.text = '${precios.first.precio}');
      }
    } catch (_) {
      // Best-effort autofill — the field stays editable either way.
    }
  }

  Future<void> _recalcularDistancia() async {
    if (_plantaId == null || _obraId == null) return;
    final planta = _plantaSeleccionada;
    if (planta == null || planta.latitud == null || planta.longitud == null)
      return;

    try {
      final obra = await ComercialService.obtenerObra(_obraId!);
      if (obra == null) return;

      final result = await DirectionsService.rutaHacia(
        origen: LatLng(latitude: planta.latitud!, longitude: planta.longitud!),
        destino: LatLng(latitude: obra.latitud, longitude: obra.longitud),
      );

      if (result != null && mounted) {
        final distKm = (result.distanciaMetros / 1000.0).toStringAsFixed(1);
        setState(() {
          _distanciaKm = distKm;
          _distanciaController.text = distKm;
        });
      }
    } catch (_) {
      // Ignorar errores, el campo se mantiene manual
    }
  }

  /// Checks the production schedule for the selected date and warns the user
  /// if the chosen delivery time falls within ±30 minutes of an existing
  /// scheduled production slot (`horaArranque`).
  Future<void> _verificarConflictoHorario(String horaElegida) async {
    if (_fechaSuministro == null) return;
    final fecha = DateFormat('yyyy-MM-dd').format(_fechaSuministro!);

    // Parse the chosen time into total minutes for easy comparison.
    final partsElegida = horaElegida.split(':');
    if (partsElegida.length < 2) return;
    final minutosElegidos =
        (int.tryParse(partsElegida[0]) ?? 0) * 60 +
        (int.tryParse(partsElegida[1]) ?? 0);

    try {
      final programacion =
          await OperacionesService.programacionDelDia(fecha);

      final conflictos = <ProgramacionProduccion>[];
      for (final prog in programacion) {
        final horaArr = prog.horaArranque;
        if (horaArr.isEmpty) continue;
        // horaArranque can be "HH:mm" or "HH:mm:ss"
        final partsArr = horaArr.split(':');
        if (partsArr.length < 2) continue;
        final minutosArr =
            (int.tryParse(partsArr[0]) ?? 0) * 60 +
            (int.tryParse(partsArr[1]) ?? 0);

        final diff = (minutosElegidos - minutosArr).abs();
        if (diff <= 30) {
          conflictos.add(prog);
        }
      }

      if (conflictos.isNotEmpty && mounted) {
        final horasOcupadas = conflictos
            .map((c) => c.horaArranque.length > 5
                ? c.horaArranque.substring(0, 5)
                : c.horaArranque)
            .toSet()
            .join(', ');
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Horario Ocupado',
                      style: TextStyle(fontSize: 17)),
                ),
              ],
            ),
            content: Text(
              'Ya existe producción programada cerca de este horario '
              '($horasOcupadas). El rango de ±30 minutos está comprometido.\n\n'
              '¿Deseas mantener este horario de todas formas?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() => _horarioEntrega = null);
                },
                child: const Text('Cambiar horario'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Mantener'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      // Best-effort: si no se puede consultar la programación, el asesor
      // puede continuar sin la validación.
    }
  }

  @override
  void dispose() {
    _descuentoController.dispose();
    _plantaIdManualController.dispose();
    _distanciaController.dispose();
    _observacionesController.dispose();
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
          data: base.copyWith(
            colorScheme: base.colorScheme.copyWith(
              primary: AppColors.accent,
              onPrimary: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _fechaSuministro = picked);
  }

  void _agregarPartida(String tipoLinea) =>
      setState(() => _items.add(PartidaControllers(tipoLinea: tipoLinea)));

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
      AppSnack.error(
        context,
        'No se pudo confirmar tu perfil de asesor. Revisa tu conexión e inténtalo de nuevo.',
      );
      return;
    }
    if (_clienteId == null) {
      AppSnack.error(context, 'Selecciona el cliente para esta cotización');
      return;
    }
    if (_plantaId == null) {
      AppSnack.error(
        context,
        'Selecciona la planta que atenderá esta cotización',
      );
      return;
    }

    final productos = <CotizacionItem>[];
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final precio = double.tryParse(item.precio.text.trim());
      if (precio == null) {
        AppSnack.error(
          context,
          'La partida ${i + 1} necesita un precio unitario válido',
        );
        return;
      }
      final volumen = double.tryParse(item.volumen.text.trim());
      // Only 'producto' líneas need productoId+volumenM3 — 'bombeo' has
      // neither (the backend autofills volumenM3 for bombeo when omitted).
      if (item.tipoLinea == tipoLineaProducto) {
        if (item.productoId == null) {
          AppSnack.error(
            context,
            'Selecciona un producto para la partida ${i + 1}',
          );
          return;
        }
        if (volumen == null) {
          AppSnack.error(context, 'La partida ${i + 1} necesita un volumen');
          return;
        }
      }
      productos.add(
        CotizacionItem(
          tipoLinea: item.tipoLinea,
          productoId: item.tipoLinea == tipoLineaProducto
              ? item.productoId
              : null,
          volumenM3: volumen,
          precioUnitario: precio,
          descripcion: item.descripcion.text.trim().isEmpty
              ? null
              : item.descripcion.text.trim(),
          porcentajeDescuentoLinea: item.descuentoLinea.text.trim().isEmpty
              ? null
              : double.tryParse(item.descuentoLinea.text.trim()),
        ),
      );
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
      final porcentajeDescuento = _descuentoController.text.trim().isEmpty
          ? null
          : double.tryParse(_descuentoController.text.trim());

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
          horarioEntrega: _horarioEntrega,
          elementoConstructivoId: _elementoConstructivoId,
          porcentajeDescuento: porcentajeDescuento,
          observaciones: _observacionesController.text.trim().isEmpty
              ? null
              : _observacionesController.text.trim(),
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
          horarioEntrega: _horarioEntrega,
          elementoConstructivoId: _elementoConstructivoId,
          porcentajeDescuento: porcentajeDescuento,
          observaciones: _observacionesController.text.trim().isEmpty
              ? null
              : _observacionesController.text.trim(),
        );
      }
      if (!mounted) return;
      AppSnack.success(
        context,
        widget.esEdicion ? 'Cotización actualizada' : 'Cotización creada',
      );
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted)
        AppSnack.error(
          context,
          widget.esEdicion
              ? 'No se pudo actualizar la cotización'
              : 'No se pudo crear la cotización',
        );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
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
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: mutedColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
          ),
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
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: mutedColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                texto ?? placeholder,
                style: TextStyle(
                  color: texto == null ? mutedColor : textColor,
                  fontWeight: FontWeight.w600,
                ),
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
    final plantaIdValida =
        _plantaId != null && _plantas.any((p) => p.id == _plantaId)
        ? _plantaId
        : null;
    if (_plantas.isEmpty) {
      return TextField(
        enabled: !_cargandoCatalogo,
        keyboardType: TextInputType.number,
        style: TextStyle(color: textColor),
        controller: _plantaIdManualController,
        onChanged: (value) => _plantaId = int.tryParse(value.trim()),
        decoration: cotizacionFieldDecoration(
          _cargandoCatalogo
              ? 'Cargando plantas…'
              : 'Planta (ID) — no se pudo cargar el catálogo',
          mutedColor,
          fillColor,
        ),
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: plantaIdValida,
      dropdownColor: AppColors.surfaceAlt(context),
      style: TextStyle(color: textColor, fontSize: 14.5),
      decoration: cotizacionFieldDecoration(
        'Seleccionar planta…',
        mutedColor,
        fillColor,
      ),
      items: _plantas
          .map(
            (p) => DropdownMenuItem(
              value: p.id,
              child: Text(p.nombre, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() => _plantaId = value);
        _recalcularDistancia();
      },
    );
  }

  Planta? get _plantaSeleccionada {
    for (final p in _plantas) {
      if (p.id == _plantaId) return p;
    }
    return null;
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
        title: Text(
          widget.esEdicion ? 'Editar cotización' : 'Nueva cotización',
        ),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.accent,
            onPrimary: Colors.black,
          ),
        ),
        child: Stepper(
          type: StepperType.horizontal,
          elevation: 0,
          currentStep: _currentStep,
          onStepTapped: (step) => setState(() => _currentStep = step),
          onStepContinue: () {
            if (_currentStep < 3) {
              setState(() => _currentStep += 1);
            } else {
              if (!_enviando) _submit();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
            } else {
              Navigator.of(context).pop();
            }
          },
          controlsBuilder: (context, details) {
            final isLastStep = _currentStep == 3;
            return Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _enviando && isLastStep
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              isLastStep
                                  ? (widget.esEdicion
                                        ? 'Guardar cambios'
                                        : 'Crear cotización')
                                  : 'Siguiente',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: details.onStepCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(_currentStep == 0 ? 'Cancelar' : 'Atrás'),
                    ),
                  ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Cliente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    const SizedBox(height: 16),
                    if (widget.origenFijo)
                      _filaInfo(
                        icon: Icons.location_on_outlined,
                        texto:
                            _obraNombre ??
                            (_obraId != null
                                ? 'Obra #$_obraId'
                                : 'Sin obra específica'),
                        textColor: _obraNombre == null && _obraId == null
                            ? mutedColor
                            : textColor,
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
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
                    _filaInfo(
                      icon: Icons.badge_outlined,
                      texto: _asesorNombre ?? 'Resolviendo…',
                      textColor: textColor,
                      mutedColor: mutedColor,
                      fillColor: fillColor,
                    ),
                    const SizedBox(height: 16),
                    _plantaField(textColor, mutedColor, fillColor),
                  ],
                ),
              ),
            ),
            Step(
              title: const Text('Comercial', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: _tipoServicio,
                    dropdownColor: AppColors.surfaceAlt(context),
                    style: TextStyle(color: textColor, fontSize: 14.5),
                    decoration: cotizacionFieldDecoration(
                      'Tipo de servicio',
                      mutedColor,
                      fillColor,
                    ),
                    items: tipoServicioOpciones.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _tipoServicio = value),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _pickFecha,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: mutedColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _fechaSuministro == null
                                ? 'Fecha de suministro estimada'
                                : DateFormat(
                                    'd/MM/y',
                                  ).format(_fechaSuministro!),
                            style: TextStyle(
                              color: _fechaSuministro == null
                                  ? mutedColor
                                  : textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final initialTime = _horarioEntrega != null
                          ? TimeOfDay(
                              hour:
                                  int.tryParse(
                                    _horarioEntrega!.split(':').first,
                                  ) ??
                                  8,
                              minute:
                                  int.tryParse(
                                    _horarioEntrega!.split(':').last,
                                  ) ??
                                  0,
                            )
                          : const TimeOfDay(hour: 8, minute: 0);
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: initialTime,
                      );
                      if (picked != null) {
                        final horaStr =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        setState(() => _horarioEntrega = horaStr);
                        await _verificarConflictoHorario(horaStr);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_outlined,
                            size: 18,
                            color: mutedColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _horarioEntrega ?? 'Horario de entrega',
                              style: TextStyle(
                                color: _horarioEntrega == null
                                    ? mutedColor
                                    : textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_horarioEntrega != null)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _horarioEntrega = null),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: mutedColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: _elementoConstructivoId,
                    onChanged: (value) =>
                        setState(() => _elementoConstructivoId = value),
                    style: TextStyle(color: textColor),
                    dropdownColor: AppColors.surfaceAlt(context),
                    decoration: cotizacionFieldDecoration(
                      'Elemento constructivo',
                      mutedColor,
                      fillColor,
                    ),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'Sin elemento específico',
                          style: TextStyle(color: mutedColor),
                        ),
                      ),
                      for (final e in _elementos)
                        DropdownMenuItem<int?>(
                          value: e.id,
                          child: Text(e.nombre),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _distanciaController,
                    onChanged: (value) => _distanciaKm = value,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(color: textColor),
                    decoration:
                        cotizacionFieldDecoration(
                          'Distancia',
                          mutedColor,
                          fillColor,
                        ).copyWith(
                          suffixText: 'km',
                          suffixStyle: TextStyle(color: mutedColor),
                        ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: _formaPago,
                    dropdownColor: AppColors.surfaceAlt(context),
                    style: TextStyle(color: textColor, fontSize: 14.5),
                    decoration: cotizacionFieldDecoration(
                      'Forma de pago',
                      mutedColor,
                      fillColor,
                    ),
                    items: formaPagoOpciones.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _formaPago = value),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Productos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Spacer(),
                      PopupMenuButton<String>(
                        onSelected: _agregarPartida,
                        color: AppColors.surfaceAlt(context),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: tipoLineaProducto,
                            child: Text(tipoLineaLabel(tipoLineaProducto)),
                          ),
                          PopupMenuItem(
                            value: tipoLineaBombeo,
                            child: Text(tipoLineaLabel(tipoLineaBombeo)),
                          ),
                          PopupMenuItem(
                            value: tipoLineaServicio,
                            child: Text(tipoLineaLabel(tipoLineaServicio)),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 18, color: textColor),
                              const SizedBox(width: 6),
                              Text(
                                'Agregar partida',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _items.length; i++) ...[
                    PartidaCard(
                      index: i,
                      item: _items[i],
                      productos: _productos,
                      onQuitar: _items.length > 1
                          ? () => _quitarPartida(i)
                          : null,
                      onProductoSeleccionado: (value) =>
                          _onProductoSeleccionado(_items[i], value),
                      onChanged: () => setState(() {}),
                      textColor: textColor,
                      mutedColor: mutedColor,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      fillColor: fillColor,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            Step(
              title: const Text('Resumen', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              isActive: _currentStep >= 3,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  TextField(
                    controller: _observacionesController,
                    maxLines: 3,
                    style: TextStyle(color: textColor),
                    decoration: cotizacionFieldDecoration(
                      'Observaciones',
                      mutedColor,
                      fillColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descuentoController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(color: textColor),
                    onChanged: (_) => setState(() {}),
                    decoration: cotizacionFieldDecoration(
                      '% Descuento global',
                      mutedColor,
                      fillColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Un descuento mayor al límite (${limiteDescuentoTexto(_requiereFactura)}) requiere autorización.',
                    style: TextStyle(fontSize: 11.5, color: mutedColor),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _requiereFactura,
                    onChanged: (value) =>
                        setState(() => _requiereFactura = value),
                    title: Text(
                      'Requiere factura fiscal',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    activeThumbColor: AppColors.accent,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  ResumenCotizacionCard(
                    subtotalProductos: sumaPorTipo(_items, tipoLineaProducto),
                    subtotalBombeo: sumaPorTipo(_items, tipoLineaBombeo),
                    subtotalServicios: sumaPorTipo(_items, tipoLineaServicio),
                    fleteVacio: fleteVacioEstimado(_items, _plantaSeleccionada),
                    porcentajeDescuento:
                        double.tryParse(_descuentoController.text.trim()) ?? 0,
                    requiereFactura: _requiereFactura,
                    porcentajeIva: _plantaSeleccionada?.porcentajeIva ?? 16,
                    textColor: textColor,
                    mutedColor: mutedColor,
                    cardColor: cardColor,
                    borderColor: borderColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
