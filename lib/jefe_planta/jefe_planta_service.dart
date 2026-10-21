import 'dart:convert';
import '../administracion/administracion_service.dart';
import '../auth/auth_service.dart';
import '../catalogo/catalogo_service.dart';
import '../catalogo/planta.dart';
import '../comercial/pedido.dart';
import '../config/api_config.dart';
import '../config/http_client.dart' as http;

// Jefe de Planta data, from three backends. Catalogs, labels and status
// rules are copied from the web panel's bundle:
//   - Solicitudes de compra: finanzas `/solicitudes-compra`. `oc_generada`
//     isn't a backend estatus. The web derives it for an `autorizada`
//     solicitud that has an orden de compra (`ordenCompraId`).
//   - Ollas: operaciones `/vehiculos` (grupo `Mix/Ollas`). Moving is
//     `PATCH /vehiculos/{id}/planta`, which answers 409 for an olla en ruta.
//   - Programación: operaciones `/programacion-produccion`, joined with
//     comercial's pedido. "Por programar" is the web's rule: the planta's
//     pedidos whose `estatusGeneral` is `autorizado` or `parcial`.
//     Dosificadores come from administración `/dosificadores`.

// ---------------------------------------------------------------------------
// Solicitudes de compra
// ---------------------------------------------------------------------------

const estatusSolicitudPendiente = 'pendiente';
const estatusSolicitudAutorizada = 'autorizada';
const estatusSolicitudOcGenerada = 'oc_generada';
const estatusSolicitudRechazada = 'rechazada';

class SolicitudCompra {
  final int id;
  final int? solicitanteId;
  final int? plantaId;
  final int? vehiculoId;
  final String? area;
  final String concepto;
  final String? motivo;
  final String? cotizacionAdjuntaUrl;
  final double? montoEstimado;

  /// Already grouped like the web: [estatusSolicitudPendiente] (including
  /// the intermediate `cotizacion_recibida`/`en_revision`),
  /// [estatusSolicitudAutorizada], [estatusSolicitudOcGenerada] or
  /// [estatusSolicitudRechazada].
  final String estatus;
  final DateTime? createdAt;
  final String? creadoPorUsuario;
  final String? ordenCompraFolio;

  const SolicitudCompra({
    required this.id,
    this.solicitanteId,
    this.plantaId,
    this.vehiculoId,
    this.area,
    required this.concepto,
    this.motivo,
    this.cotizacionAdjuntaUrl,
    this.montoEstimado,
    required this.estatus,
    this.createdAt,
    this.creadoPorUsuario,
    this.ordenCompraFolio,
  });

  factory SolicitudCompra.fromJson(Map<String, dynamic> json) {
    final ordenCompraId = (json['ordenCompraId'] as num?)?.toInt();
    return SolicitudCompra(
      id: (json['id'] as num).toInt(),
      solicitanteId: (json['solicitanteId'] as num?)?.toInt(),
      plantaId: (json['plantaId'] as num?)?.toInt(),
      vehiculoId: (json['vehiculoId'] as num?)?.toInt(),
      area: _texto(json['area']),
      concepto: _texto(json['concepto']) ?? 'Sin concepto capturado',
      motivo: _texto(json['motivo']),
      cotizacionAdjuntaUrl: _texto(json['cotizacionAdjuntaUrl']),
      montoEstimado: (json['montoEstimado'] as num?)?.toDouble(),
      estatus: _agruparEstatusSolicitud(
        json['estatus'] as String?,
        conOrdenCompra: ordenCompraId != null,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      creadoPorUsuario: _texto(json['creadoPorUsuario']),
      ordenCompraFolio: ordenCompraId == null
          ? null
          : _texto(json['ordenCompraFolio']) ?? 'OC #$ordenCompraId',
    );
  }
}

String _agruparEstatusSolicitud(String? raw, {required bool conOrdenCompra}) {
  final e = (raw ?? '').trim().toLowerCase();
  if (e == 'autorizada' || e == 'autorizar') {
    return conOrdenCompra
        ? estatusSolicitudOcGenerada
        : estatusSolicitudAutorizada;
  }
  if (e == 'rechazada' || e == 'rechazar') return estatusSolicitudRechazada;
  return estatusSolicitudPendiente;
}

/// Mirrors finanzas `BitacoraEventoResponse`.
class BitacoraSolicitud {
  final String accion;
  final String usuario;
  final DateTime? fecha;
  final String? comentario;

  const BitacoraSolicitud({
    required this.accion,
    required this.usuario,
    this.fecha,
    this.comentario,
  });

  factory BitacoraSolicitud.fromJson(Map<String, dynamic> json) {
    final accion = _texto(json['accion']) ?? 'Movimiento';
    return BitacoraSolicitud(
      accion: accion.isEmpty
          ? accion
          : '${accion[0].toUpperCase()}${accion.substring(1).replaceAll('_', ' ')}',
      usuario: _texto(json['usuario']) ?? '—',
      fecha: DateTime.tryParse(json['creadoEn'] as String? ?? ''),
      comentario: _texto(json['descripcion']),
    );
  }
}

/// Permission `POST /ordenes-compra` requires; gates "Generar OC".
const permisoCrearOrdenCompra = 'ordenes_compra.crear';

/// IVA the web applies to an orden de compra's total (`Gu=16`).
const porcentajeIvaOrdenCompra = 16.0;

/// Mirrors finanzas `ProveedorResponse`, only what the OC form needs.
class Proveedor {
  final int id;
  final String nombre;
  final String? condicionPago;

  const Proveedor({required this.id, required this.nombre, this.condicionPago});

  factory Proveedor.fromJson(Map<String, dynamic> json) {
    return Proveedor(
      id: (json['id'] as num).toInt(),
      nombre:
          _texto(json['nombre']) ??
          _texto(json['razonSocial']) ??
          'Proveedor #${json['id']}',
      condicionPago: _texto(json['condicionPago'])?.toLowerCase(),
    );
  }
}

/// Mirrors finanzas `ProveedorItemResponse`: something this proveedor sells,
/// with its reference price.
class ProveedorItem {
  final String tipoItem;
  final int? materialId;
  final int? insumoId;
  final int? servicioId;
  final String nombre;
  final double? precioReferencia;

  const ProveedorItem({
    required this.tipoItem,
    this.materialId,
    this.insumoId,
    this.servicioId,
    required this.nombre,
    this.precioReferencia,
  });

  factory ProveedorItem.fromJson(Map<String, dynamic> json) {
    return ProveedorItem(
      tipoItem: (_texto(json['tipoItem']) ?? 'material').toLowerCase(),
      materialId: (json['materialId'] as num?)?.toInt(),
      insumoId: (json['insumoId'] as num?)?.toInt(),
      servicioId: (json['servicioId'] as num?)?.toInt(),
      nombre: _texto(json['nombreItem']) ?? 'Artículo #${json['id']}',
      precioReferencia: (json['precioReferencia'] as num?)?.toDouble(),
    );
  }
}

/// One line of the orden de compra being built (`OrdenCompraDetalleRequest`).
class LineaOrdenCompra {
  final String tipoItem;
  final int? materialId;
  final int? insumoId;
  final int? servicioId;
  final String descripcion;
  final String? unidad;
  final double cantidad;
  final double precioUnitario;

  const LineaOrdenCompra({
    required this.tipoItem,
    this.materialId,
    this.insumoId,
    this.servicioId,
    required this.descripcion,
    this.unidad,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get importe => cantidad * precioUnitario;

  Map<String, dynamic> toJson() => {
    'tipoItem': tipoItem,
    if (tipoItem == 'material') 'materialId': ?materialId,
    if (tipoItem == 'insumo') 'insumoId': ?insumoId,
    if (tipoItem == 'servicio') 'servicioId': ?servicioId,
    'descripcion': descripcion,
    'unidad': ?unidad,
    'cantidad': cantidad,
    'precioUnitario': precioUnitario,
  };
}

/// Result of [JefePlantaService.generarOrdenCompra]. Like the web, the OC
/// is created and then sent to autorización. If only the second step
/// fails, the OC still exists and [avisoEnvio] says so.
class OrdenCompraGenerada {
  final String folio;
  final String? avisoEnvio;

  const OrdenCompraGenerada({required this.folio, this.avisoEnvio});
}

// ---------------------------------------------------------------------------
// Ollas
// ---------------------------------------------------------------------------

/// `estatusOperativo` catalog from the web's vehicle form.
const estatusOperativoOperando = 'operando';
const estatusOperativoParada = 'parada';
const estatusOperativoEnReparacion = 'en_reparacion';
const estatusOperativoAccidentada = 'accidentada';

const grupoOllas = 'Mix/Ollas';

/// Mirrors operaciones `VehiculoResponse`, only the fields the Ollas tab
/// shows.
class OllaPlanta {
  final int id;
  final String numeroUnidad;
  final String? placas;
  final double? capacidadM3;
  final int? plantaAsignadaId;
  final int? conductorAsignadoId;
  final String estatusOperativo;

  /// True while a remisión has this unit out of the plant.
  final bool enRuta;

  const OllaPlanta({
    required this.id,
    required this.numeroUnidad,
    this.placas,
    this.capacidadM3,
    this.plantaAsignadaId,
    this.conductorAsignadoId,
    required this.estatusOperativo,
    this.enRuta = false,
  });

  factory OllaPlanta.fromJson(
    Map<String, dynamic> json, {
    bool enRuta = false,
  }) {
    return OllaPlanta(
      id: (json['id'] as num).toInt(),
      numeroUnidad: _texto(json['numeroUnidad']) ?? '#${json['id']}',
      placas: _texto(json['placas']),
      capacidadM3: (json['capacidadM3'] as num?)?.toDouble(),
      plantaAsignadaId: (json['plantaAsignadaId'] as num?)?.toInt(),
      conductorAsignadoId: (json['conductorAsignadoId'] as num?)?.toInt(),
      estatusOperativo:
          _texto(json['estatusOperativo'])?.toLowerCase() ??
          estatusOperativoOperando,
      enRuta: enRuta,
    );
  }
}

/// Mirrors operaciones `UbicacionVehiculoResponse`: a unit's last known
/// position, from Samsara or the operator's phone (per `origenGps`).
class UbicacionOlla {
  final int vehiculoId;
  final double latitud;
  final double longitud;
  final double? heading;

  /// km/h as the backend reports it.
  final double? velocidad;
  final String? ubicacionTexto;
  final DateTime? capturadaEn;
  final String? origenGps;

  const UbicacionOlla({
    required this.vehiculoId,
    required this.latitud,
    required this.longitud,
    this.heading,
    this.velocidad,
    this.ubicacionTexto,
    this.capturadaEn,
    this.origenGps,
  });

  /// Null when the backend has no usable fix (`disponible == false`, or
  /// no coordinates).
  static UbicacionOlla? fromJson(Map<String, dynamic> json) {
    final lat = (json['latitud'] as num?)?.toDouble();
    final lng = (json['longitud'] as num?)?.toDouble();
    if (json['disponible'] == false || lat == null || lng == null) return null;
    if (lat == 0 && lng == 0) return null;
    return UbicacionOlla(
      vehiculoId: (json['vehiculoId'] as num).toInt(),
      latitud: lat,
      longitud: lng,
      heading: (json['heading'] as num?)?.toDouble(),
      velocidad: (json['velocidad'] as num?)?.toDouble(),
      ubicacionTexto: _texto(json['ubicacionTexto']),
      capturadaEn: DateTime.tryParse(
        json['timestampCaptura'] as String? ?? '',
      )?.toLocal(),
      origenGps: _texto(json['origenGps'])?.toLowerCase(),
    );
  }

  /// Older than this, the map greys the olla out as "sin señal reciente".
  static const vigencia = Duration(minutes: 30);

  bool get reciente =>
      capturadaEn != null &&
      DateTime.now().difference(capturadaEn!) <= vigencia;
}

/// Permission `PATCH /vehiculos/{id}/planta` requires; gates "Mover a otra
/// planta".
const permisoCambiarPlantaVehiculo = 'vehiculos.cambiar_planta';

/// Remisión estatus that mean the unit is busy: the web fleet's "En ruta"
/// set (which includes `con_atraso`) plus `cargando_planta`, so an olla
/// being loaded can't be moved either.
const _estatusRemisionEnRuta = [
  'cargando_planta',
  'salio_planta',
  'en_camino',
  'proximo_llegar',
  'en_obra',
  'descargando',
  'con_atraso',
];

// ---------------------------------------------------------------------------
// Programación de producción
// ---------------------------------------------------------------------------

/// Mirrors administración `DosificadorResponse`.
class Dosificador {
  final int id;
  final String nombre;
  final int? plantaId;

  const Dosificador({required this.id, required this.nombre, this.plantaId});

  factory Dosificador.fromJson(Map<String, dynamic> json) {
    return Dosificador(
      id: (json['id'] as num).toInt(),
      nombre: _texto(json['nombre']) ?? 'Dosificador #${json['id']}',
      plantaId: (json['plantaId'] as num?)?.toInt(),
    );
  }
}

const estatusProgramacionPrevia = 'previa';
const estatusProgramacionProgramado = 'programado';
const estatusProgramacionAprobado = 'aprobado';
const estatusProgramacionCancelada = 'cancelada';

/// Rows that no longer block programming their pedido again. `concluido`
/// is assumed, not verified against the 409.
const _estatusProgramacionInactiva = {
  estatusProgramacionCancelada,
  'concluido',
};

/// A pedido as the jefe de planta sees it: comercial's pedido, flattened.
class PedidoPlanta {
  final int id;
  final String folio;
  final String clienteNombre;
  final String obraNombre;
  final String? producto;
  final double volumenM3;
  final DateTime? fechaSolicitada;

  const PedidoPlanta({
    required this.id,
    required this.folio,
    required this.clienteNombre,
    required this.obraNombre,
    this.producto,
    required this.volumenM3,
    this.fechaSolicitada,
  });

  factory PedidoPlanta.desdePedido(Pedido p) {
    final productos = p.productos
        .where((i) => (i.tipoLinea ?? 'producto') == 'producto')
        .map((i) => i.descripcion)
        .whereType<String>()
        .where((d) => d.trim().isNotEmpty)
        .toList();
    return PedidoPlanta(
      id: p.id,
      folio: p.folio,
      clienteNombre: p.clienteNombre,
      obraNombre: p.obraNombre,
      producto: productos.isEmpty ? null : productos.join(' · '),
      volumenM3: p.volumenSolicitadoM3,
      fechaSolicitada: DateTime.tryParse(p.fechaProgramada ?? ''),
    );
  }

  /// When the pedido lookup fails, show the raw id rather than made-up data.
  factory PedidoPlanta.soloId({int? pedidoId, int? cotizacionId}) {
    return PedidoPlanta(
      id: pedidoId ?? 0,
      folio: pedidoId != null
          ? 'Pedido #$pedidoId'
          : 'Cotización #$cotizacionId',
      clienteNombre: '—',
      obraNombre: '—',
      volumenM3: 0,
    );
  }
}

/// Mirrors operaciones `ProgramacionResponse`, joined with its pedido.
class ProgramacionPedido {
  final int id;
  final int? pedidoId;
  final int? cotizacionId;
  final PedidoPlanta pedido;
  final int? plantaId;
  final DateTime fechaProgramada;

  /// "HH:mm", or null when it wasn't captured (it's optional).
  final String? horaArranque;
  final int? dosificadorId;
  final int? personalRequerido;
  final String estatus;

  const ProgramacionPedido({
    required this.id,
    this.pedidoId,
    this.cotizacionId,
    required this.pedido,
    this.plantaId,
    required this.fechaProgramada,
    this.horaArranque,
    this.dosificadorId,
    this.personalRequerido,
    required this.estatus,
  });

  factory ProgramacionPedido.fromJson(
    Map<String, dynamic> json,
    PedidoPlanta pedido,
  ) {
    final hora = _texto(json['horaArranque']);
    return ProgramacionPedido(
      id: (json['id'] as num).toInt(),
      pedidoId: (json['pedidoId'] as num?)?.toInt(),
      cotizacionId: (json['cotizacionId'] as num?)?.toInt(),
      pedido: pedido,
      plantaId: (json['plantaId'] as num?)?.toInt(),
      fechaProgramada:
          DateTime.tryParse(json['fechaProgramada'] as String? ?? '') ??
          DateTime.now(),
      horaArranque: hora == null || hora.length < 5
          ? hora
          : hora.substring(0, 5),
      dosificadorId: (json['dosificadorId'] as num?)?.toInt(),
      personalRequerido: (json['personalRequerido'] as num?)?.toInt(),
      estatus: (_texto(json['estatus']) ?? '').toLowerCase(),
    );
  }
}

/// What `PATCH /programacion-produccion/{id}/estatus` reports back about
/// the pedido's logística authorization, which approving also triggers.
class CambioEstatusProgramacion {
  final bool logisticaAutorizada;
  final String? logisticaError;

  const CambioEstatusProgramacion({
    required this.logisticaAutorizada,
    this.logisticaError,
  });
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

bool mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _fechaIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String? _texto(dynamic v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

/// The jefe's planta and the planta catalog, loaded once per session.
class ContextoPlanta {
  /// `plantaId` on the jefe's empleado record. Null when the record has
  /// none, or couldn't be loaded; screens then show every planta.
  final int? miPlantaId;
  final List<Planta> plantas;

  const ContextoPlanta({required this.miPlantaId, required this.plantas});

  Planta? planta(int? id) {
    for (final p in plantas) {
      if (p.id == id) return p;
    }
    return null;
  }

  String nombrePlanta(int? id) =>
      id == null ? 'Sin planta' : planta(id)?.nombre ?? 'Planta #$id';

  Planta? get miPlanta => planta(miPlantaId);
}

class JefePlantaService {
  JefePlantaService._();

  static const _timeout = Duration(seconds: 20);

  static Future<ContextoPlanta>? _contexto;
  static int? _contextoDeEmpleado;

  /// Cached per logged-in empleado. Both lookups are best-effort, so this
  /// never throws.
  static Future<ContextoPlanta> contexto() {
    final empleado = AuthService.idEmpleado;
    if (_contexto == null || _contextoDeEmpleado != empleado) {
      _contextoDeEmpleado = empleado;
      _contexto = _cargarContexto(empleado);
    }
    return _contexto!;
  }

  static Future<ContextoPlanta> _cargarContexto(int? idEmpleado) async {
    final resultados = await Future.wait<Object?>([
      () async {
        if (idEmpleado == null) return null;
        try {
          return (await AdministracionService.obtenerEmpleado(
            idEmpleado,
          )).plantaId;
        } catch (_) {
          return null;
        }
      }(),
      () async {
        try {
          return await CatalogoService.plantas();
        } catch (_) {
          return const <Planta>[];
        }
      }(),
    ]);
    final plantas = resultados[1] as List<Planta>;
    // A failed catalog shouldn't stick for the whole session.
    if (plantas.isEmpty) _contexto = null;
    return ContextoPlanta(miPlantaId: resultados[0] as int?, plantas: plantas);
  }

  // --- Solicitudes --------------------------------------------------------

  /// The planta's solicitudes, newest first. Filtering by estatus happens
  /// on the client because [estatusSolicitudOcGenerada] is derived.
  static Future<List<SolicitudCompra>> solicitudes({int? plantaId}) async {
    final query = plantaId == null ? '' : '?plantaId=$plantaId';
    final data = await _get(ApiConfig.finanzas, '/solicitudes-compra$query');
    return (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(SolicitudCompra.fromJson)
        .toList()
      ..sort((a, b) => b.id.compareTo(a.id));
  }

  static Future<List<BitacoraSolicitud>> bitacora(int solicitudId) async {
    final data = await _get(
      ApiConfig.finanzas,
      '/solicitudes-compra/$solicitudId/bitacora',
    );
    return (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(BitacoraSolicitud.fromJson)
        .toList();
  }

  /// Administración's `GET /areas`, the catalog the web's form offers.
  /// Only active ones.
  static Future<List<String>> areas() async {
    final data = await _get(ApiConfig.administracion, '/areas');
    return (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .where(
          (a) =>
              (a['estatus'] as String? ?? 'activo').toLowerCase() == 'activo',
        )
        .map((a) => _texto(a['nombre']))
        .whereType<String>()
        .toList();
  }

  static Future<SolicitudCompra> crearSolicitud({
    required String concepto,
    String? area,
    String? motivo,
    double? montoEstimado,
    int? plantaId,
    int? vehiculoId,
    String? cotizacionAdjuntaUrl,
  }) async {
    final data =
        await _send('POST', ApiConfig.finanzas, '/solicitudes-compra', {
          'concepto': concepto,
          'area': ?area,
          'motivo': ?motivo,
          'montoEstimado': ?montoEstimado,
          'plantaId': ?plantaId,
          'vehiculoId': ?vehiculoId,
          'cotizacionAdjuntaUrl': ?cotizacionAdjuntaUrl,
        });
    return SolicitudCompra.fromJson(data as Map<String, dynamic>);
  }

  /// Active proveedores (`GET /proveedores?estatus=activo`), by name.
  static Future<List<Proveedor>> proveedores() async {
    final data = await _get(ApiConfig.finanzas, '/proveedores?estatus=activo');
    return (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(Proveedor.fromJson)
        .toList()
      ..sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );
  }

  static Future<List<ProveedorItem>> itemsProveedor(int proveedorId) async {
    final data = await _get(
      ApiConfig.finanzas,
      '/proveedores/$proveedorId/items',
    );
    return (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(ProveedorItem.fromJson)
        .toList();
  }

  /// The web's "Generar OC" for an autorizada [solicitud]: destino, planta
  /// and solicitante come from it (vehículo if it has one, else `general`
  /// with its área). Then `PATCH /ordenes-compra/{id}/enviar-autorizacion`.
  static Future<OrdenCompraGenerada> generarOrdenCompra({
    required SolicitudCompra solicitud,
    required int proveedorId,
    required String condicionPago,
    required bool facturacionConIva,
    required List<LineaOrdenCompra> lineas,
  }) async {
    final porVehiculo = solicitud.vehiculoId != null;
    final data =
        await _send('POST', ApiConfig.finanzas, '/ordenes-compra', {
              'proveedorId': proveedorId,
              'solicitudCompraId': solicitud.id,
              'plantaId': ?solicitud.plantaId,
              'solicitanteId': ?solicitud.solicitanteId,
              'condicionPago': condicionPago,
              'facturacionConIva': facturacionConIva,
              'destinoTipo': porVehiculo ? 'vehiculo' : 'general',
              if (porVehiculo) 'vehiculoDestinoId': solicitud.vehiculoId,
              if (!porVehiculo) 'areaDestino': ?solicitud.area,
              'items': [for (final l in lineas) l.toJson()],
            })
            as Map<String, dynamic>;
    final id = (data['id'] as num).toInt();
    final folio = _texto(data['folio']) ?? 'OC #$id';
    try {
      await _send(
        'PATCH',
        ApiConfig.finanzas,
        '/ordenes-compra/$id/enviar-autorizacion',
        const {},
      );
      return OrdenCompraGenerada(folio: folio);
    } on AuthException catch (e) {
      return OrdenCompraGenerada(
        folio: folio,
        avisoEnvio:
            'La $folio se guardó, pero no se pudo enviar a autorización: ${e.message}. Pide que la envíen desde la web.',
      );
    }
  }

  // --- Ollas --------------------------------------------------------------

  /// Ollas (`Mix/Ollas`) that aren't `baja`, optionally of one planta.
  /// [OllaPlanta.enRuta] comes from the remisiones on the road (best-effort).
  /// Those aren't filtered by planta: an olla of this planta can be out on
  /// another planta's remisión.
  static Future<List<OllaPlanta>> ollas({int? plantaId}) async {
    final params = {'grupo': grupoOllas, 'plantaId': ?plantaId?.toString()};
    final enRutaQuery = Uri(
      queryParameters: {'estatus': _estatusRemisionEnRuta},
    ).query;
    final results = await Future.wait<dynamic>([
      _get(
        ApiConfig.operaciones,
        '/vehiculos?${Uri(queryParameters: params).query}',
      ),
      _get(
        ApiConfig.operaciones,
        '/remisiones?$enRutaQuery',
      ).catchError((_) => null),
    ]);
    final enRuta = <int>{};
    if (results[1] is List) {
      for (final r in (results[1] as List).whereType<Map<String, dynamic>>()) {
        final estatus = (r['estatus'] as String? ?? '').toLowerCase();
        final olla = (r['vehiculoOllaId'] as num?)?.toInt();
        if (olla != null && _estatusRemisionEnRuta.contains(estatus)) {
          enRuta.add(olla);
        }
      }
    }
    final ollas =
        (results[0] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            // The server filters by grupo already; re-check in case it ignores it.
            .where((v) => v['grupo'] == grupoOllas)
            .where(
              (v) => (v['estatus'] as String? ?? '').toLowerCase() != 'baja',
            )
            .map(
              (v) => OllaPlanta.fromJson(
                v,
                enRuta: enRuta.contains((v['id'] as num).toInt()),
              ),
            )
            .toList()
          ..sort((a, b) => a.numeroUnidad.compareTo(b.numeroUnidad));
    return ollas;
  }

  /// Last known position per olla id (`GET /vehiculos/ubicaciones`).
  /// Unfiltered on purpose: with `plantaId` the backend leaves out some of
  /// that planta's ollas (seen 2026-10-12), so callers keep the ids they
  /// need. Ollas without a usable fix are absent from the map.
  static Future<Map<int, UbicacionOlla>> ubicacionesOllas() async {
    final data = await _get(ApiConfig.operaciones, '/vehiculos/ubicaciones');
    final ubicaciones = (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .where((v) => v['grupo'] == grupoOllas)
        .map(UbicacionOlla.fromJson)
        .whereType<UbicacionOlla>();
    return {for (final u in ubicaciones) u.vehiculoId: u};
  }

  /// Best-effort operator names (`GET /empleados/{id}`), keyed by id.
  static Future<Map<int, String>> nombresOperadores(Iterable<int> ids) async {
    final nombres = <int, String>{};
    await Future.wait(
      ids.toSet().map((id) async {
        final cache = _nombresEmpleado[id];
        if (cache != null) {
          nombres[id] = cache;
          return;
        }
        try {
          final e = await AdministracionService.obtenerEmpleado(id);
          final nombre = e.nombreCompleto.trim();
          if (nombre.isNotEmpty) nombres[id] = _nombresEmpleado[id] = nombre;
        } catch (_) {}
      }),
    );
    return nombres;
  }

  static final _nombresEmpleado = <int, String>{};

  /// `PATCH /vehiculos/{id}/planta`. The backend answers 409 when the olla
  /// is en ruta; its message is shown as is.
  static Future<OllaPlanta> moverOlla(int ollaId, int plantaDestinoId) async {
    final data = await _send(
      'PATCH',
      ApiConfig.operaciones,
      '/vehiculos/$ollaId/planta',
      {'plantaAsignadaId': plantaDestinoId},
    );
    return OllaPlanta.fromJson(data as Map<String, dynamic>);
  }

  // --- Programación -------------------------------------------------------

  /// One day's schedule for the planta, sorted by hora de arranque, with
  /// each row's pedido joined in (rows whose pedido can't be loaded show
  /// the raw id).
  static Future<List<ProgramacionPedido>> programacion(
    DateTime fecha, {
    int? plantaId,
  }) async {
    final params = {
      'fecha': _fechaIso(fecha),
      'plantaId': ?plantaId?.toString(),
    };
    final data = await _get(
      ApiConfig.operaciones,
      '/programacion-produccion?${Uri(queryParameters: params).query}',
    );
    final filas = (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
    final pedidos = await _pedidosPorId(
      filas.map((f) => (f['pedidoId'] as num?)?.toInt()).whereType<int>(),
    );
    final lista =
        filas.map((f) {
          final pedidoId = (f['pedidoId'] as num?)?.toInt();
          final pedido =
              pedidos[pedidoId] ??
              PedidoPlanta.soloId(
                pedidoId: pedidoId,
                cotizacionId: (f['cotizacionId'] as num?)?.toInt(),
              );
          return ProgramacionPedido.fromJson(f, pedido);
        }).toList()..sort(
          (a, b) => (a.horaArranque ?? '99').compareTo(b.horaArranque ?? '99'),
        );
    return lista;
  }

  static Future<Map<int?, PedidoPlanta>> _pedidosPorId(
    Iterable<int> ids,
  ) async {
    final mapa = <int?, PedidoPlanta>{};
    await Future.wait(
      ids.toSet().map((id) async {
        try {
          final data = await _get(ApiConfig.comercial, '/pedidos/$id');
          mapa[id] = PedidoPlanta.desdePedido(
            Pedido.fromJson(data as Map<String, dynamic>),
          );
        } catch (_) {}
      }),
    );
    return mapa;
  }

  /// Active dosificadores (administración `GET /dosificadores`), by name.
  static Future<List<Dosificador>> dosificadores({int? plantaId}) async {
    final query = plantaId == null ? '' : '?plantaId=$plantaId';
    final data = await _get(ApiConfig.administracion, '/dosificadores$query');
    return (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(Dosificador.fromJson)
        .toList()
      ..sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );
  }

  /// The web's rule for the "Programar" pedido picker: the planta's pedidos
  /// whose `estatusGeneral` is `autorizado` or `parcial`. Unlike the web, it
  /// also drops pedidos that already have an active programación, since
  /// `POST /programacion-produccion` answers 409 for them. That lookup is
  /// unfiltered (a pedido's row can sit under another planta) and
  /// best-effort.
  static Future<List<PedidoPlanta>> pedidosPorProgramar({int? plantaId}) async {
    final query = plantaId == null ? '' : '?plantaId=$plantaId';
    final results = await Future.wait<dynamic>([
      _get(ApiConfig.comercial, '/pedidos$query'),
      _get(
        ApiConfig.operaciones,
        '/programacion-produccion',
      ).catchError((_) => null),
    ]);
    final yaProgramados = <int>{};
    if (results[1] is List) {
      for (final f in (results[1] as List).whereType<Map<String, dynamic>>()) {
        final estatus = (_texto(f['estatus']) ?? '').toLowerCase();
        final pedidoId = (f['pedidoId'] as num?)?.toInt();
        if (pedidoId != null &&
            !_estatusProgramacionInactiva.contains(estatus)) {
          yaProgramados.add(pedidoId);
        }
      }
    }
    return (results[0] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(Pedido.fromJson)
        .where(
          (p) =>
              const {
                'autorizado',
                'parcial',
              }.contains(p.estatusGeneral.toLowerCase()) &&
              !yaProgramados.contains(p.id),
        )
        .map(PedidoPlanta.desdePedido)
        .toList()
      ..sort(
        (a, b) => (a.fechaSolicitada ?? DateTime(9999)).compareTo(
          b.fechaSolicitada ?? DateTime(9999),
        ),
      );
  }

  /// `POST /programacion-produccion` for a new row, `PUT /{id}` when
  /// [actual] is given (keeping its estatus).
  static Future<void> guardarProgramacion({
    ProgramacionPedido? actual,
    required int pedidoId,
    int? plantaId,
    required DateTime fecha,
    String? horaArranque,
    int? dosificadorId,
    int? personalRequerido,
  }) async {
    final body = {
      'pedidoId': pedidoId,
      'plantaId': ?(plantaId ?? actual?.plantaId),
      'fechaProgramada': _fechaIso(fecha),
      'horaArranque': ?horaArranque,
      'dosificadorId': ?dosificadorId,
      'personalRequerido': ?personalRequerido,
      if (actual != null) 'estatus': actual.estatus,
    };
    if (actual == null) {
      await _send(
        'POST',
        ApiConfig.operaciones,
        '/programacion-produccion',
        body,
      );
    } else {
      await _send(
        'PUT',
        ApiConfig.operaciones,
        '/programacion-produccion/${actual.id}',
        body,
      );
    }
  }

  /// `programado`/`aprobado`/`cancelada`. Approving a row tied to a pedido
  /// also approves that pedido's logística authorization in comercial.
  static Future<CambioEstatusProgramacion> cambiarEstatus(
    int id,
    String estatus,
  ) async {
    final data = await _send(
      'PATCH',
      ApiConfig.operaciones,
      '/programacion-produccion/$id/estatus',
      {'estatus': estatus},
    );
    final json = data is Map<String, dynamic>
        ? data
        : const <String, dynamic>{};
    return CambioEstatusProgramacion(
      logisticaAutorizada: json['logisticaAutorizada'] == true,
      logisticaError: _texto(json['logisticaError']),
    );
  }

  // --- HTTP ---------------------------------------------------------------

  static Future<dynamic> _get(String base, String path) async {
    final headers = await AuthService.authHeaders();
    final http.Response response;
    try {
      response = await http
          .get(Uri.parse('$base$path'), headers: headers)
          .timeout(_timeout);
    } catch (_) {
      throw AuthException('No se pudo conectar con el servidor');
    }
    return _handleResponse(response);
  }

  static Future<dynamic> _send(
    String method,
    String base,
    String path,
    Map<String, dynamic> body,
  ) async {
    final headers = {
      ...await AuthService.authHeaders(),
      'Content-Type': 'application/json',
    };
    final uri = Uri.parse('$base$path');
    final encoded = jsonEncode(body);
    final http.Response response;
    try {
      response = await switch (method) {
        'POST' => http.post(uri, headers: headers, body: encoded),
        'PUT' => http.put(uri, headers: headers, body: encoded),
        _ => http.patch(uri, headers: headers, body: encoded),
      }.timeout(_timeout);
    } catch (_) {
      throw AuthException('No se pudo conectar con el servidor');
    }
    return _handleResponse(response);
  }

  static dynamic _handleResponse(http.Response response) {
    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        throw AuthException('Respuesta inesperada del servidor');
      }
    }
    if (response.statusCode == 403) {
      throw AuthException('Tu usuario no tiene permiso para esta acción');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map<String, dynamic>
          ? data['message'] as String?
          : null;
      throw AuthException(message ?? 'Ocurrió un error inesperado');
    }
    return data;
  }
}

String etiquetaEstatusSolicitud(String estatus) => switch (estatus) {
  estatusSolicitudPendiente => 'Pendiente de autorizar',
  estatusSolicitudAutorizada => 'Autorizada',
  estatusSolicitudOcGenerada => 'OC generada',
  estatusSolicitudRechazada => 'Rechazada',
  _ => estatus,
};

String etiquetaEstatusOperativo(String estatus) => switch (estatus) {
  estatusOperativoOperando => 'En operación',
  estatusOperativoParada => 'Parada',
  estatusOperativoEnReparacion => 'En reparación',
  estatusOperativoAccidentada => 'Accidentada',
  _ =>
    estatus.isEmpty
        ? estatus
        : '${estatus[0].toUpperCase()}${estatus.substring(1).replaceAll('_', ' ')}',
};

String etiquetaEstatusProgramacion(String estatus) => switch (estatus) {
  estatusProgramacionPrevia => 'Previa',
  estatusProgramacionProgramado => 'Programado',
  estatusProgramacionAprobado => 'Aprobado',
  estatusProgramacionCancelada => 'Cancelada',
  // Seen in the sandbox; set by the backend, never by this app.
  'en_proceso' => 'En proceso',
  'concluido' => 'Concluido',
  _ => estatus,
};
