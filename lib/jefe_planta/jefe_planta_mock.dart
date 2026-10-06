import '../catalogo/planta.dart';

// MOCK LAYER — design-only data for the Jefe de Planta screens until the
// endpoints are handed over. Every DTO here mirrors the field names of the
// real backend schemas it will be replaced by, so swapping this file for a
// real service is a matter of adding `fromJson` + HTTP calls:
//   - SolicitudCompra      ← finanzas `SolicitudCompraResponse`
//                            (`GET/POST /solicitudes-compra`, `/{id}/bitacora`)
//   - OllaPlanta           ← operaciones `VehiculoResponse`
//                            (`GET /vehiculos?plantaId=`, `PUT /vehiculos/{id}`)
//   - ProgramacionPedido   ← operaciones `ProgramacionResponse`
//                            (`GET/POST /programacion-produccion`,
//                            `PATCH /programacion-produccion/{id}/estatus`)
// Estatus values below come from the OpenAPI summaries and are unverified
// against live data. Writes only mutate the in-memory lists.

/// Simulated network latency, so loading states are visible while designing.
Future<void> _latencia() => Future.delayed(const Duration(milliseconds: 450));

// ---------------------------------------------------------------------------
// Solicitudes de compra
// ---------------------------------------------------------------------------

const estatusSolicitudPendiente = 'pendiente';
const estatusSolicitudCotizacionRecibida = 'cotizacion_recibida';
const estatusSolicitudEnRevision = 'en_revision';
const estatusSolicitudAutorizada = 'autorizada';
const estatusSolicitudRechazada = 'rechazada';

const areasSolicitud = [
  'Producción',
  'Mantenimiento',
  'Flota',
  'Laboratorio',
  'Seguridad',
  'Administración',
];

class SolicitudCompra {
  final int id;
  final int solicitanteId;
  final int plantaId;
  final int? vehiculoId;
  final String area;
  final String concepto;
  final String motivo;
  final String? cotizacionAdjuntaUrl;
  final double? montoEstimado;
  final String estatus;
  final DateTime createdAt;
  final String? creadoPorUsuario;

  const SolicitudCompra({
    required this.id,
    required this.solicitanteId,
    required this.plantaId,
    this.vehiculoId,
    required this.area,
    required this.concepto,
    required this.motivo,
    this.cotizacionAdjuntaUrl,
    this.montoEstimado,
    required this.estatus,
    required this.createdAt,
    this.creadoPorUsuario,
  });
}

class BitacoraSolicitud {
  final String accion;
  final String usuario;
  final DateTime fecha;
  final String? comentario;

  const BitacoraSolicitud({
    required this.accion,
    required this.usuario,
    required this.fecha,
    this.comentario,
  });
}

// ---------------------------------------------------------------------------
// Ollas
// ---------------------------------------------------------------------------

const estatusOperativoDisponible = 'disponible';
const estatusOperativoEnRuta = 'en_ruta';
const estatusOperativoMantenimiento = 'en_mantenimiento';

class OllaPlanta {
  final int id;
  final String numeroUnidad;
  final String? placas;
  final double? capacidadM3;
  final int plantaAsignadaId;
  final String? conductorNombre;
  final String estatusOperativo;

  const OllaPlanta({
    required this.id,
    required this.numeroUnidad,
    this.placas,
    this.capacidadM3,
    required this.plantaAsignadaId,
    this.conductorNombre,
    required this.estatusOperativo,
  });

  OllaPlanta copyWith({int? plantaAsignadaId}) => OllaPlanta(
    id: id,
    numeroUnidad: numeroUnidad,
    placas: placas,
    capacidadM3: capacidadM3,
    plantaAsignadaId: plantaAsignadaId ?? this.plantaAsignadaId,
    conductorNombre: conductorNombre,
    estatusOperativo: estatusOperativo,
  );
}

// ---------------------------------------------------------------------------
// Programación de producción
// ---------------------------------------------------------------------------

const estatusProgramacionPrevia = 'previa';
const estatusProgramacionProgramado = 'programado';
const estatusProgramacionAprobado = 'aprobado';
const estatusProgramacionCancelada = 'cancelada';

/// A pedido as the jefe de planta sees it. The real screen will join
/// comercial's pedido (folio, cliente, obra, producto, m³) with operaciones'
/// programación row.
class PedidoPlanta {
  final int id;
  final String folio;
  final String clienteNombre;
  final String obraNombre;
  final String producto;
  final double volumenM3;
  final String? elemento;
  final DateTime fechaSolicitada;

  const PedidoPlanta({
    required this.id,
    required this.folio,
    required this.clienteNombre,
    required this.obraNombre,
    required this.producto,
    required this.volumenM3,
    this.elemento,
    required this.fechaSolicitada,
  });
}

class ProgramacionPedido {
  final int id;
  final PedidoPlanta pedido;
  final int plantaId;
  final DateTime fechaProgramada;
  final String horaArranque; // "HH:mm", as the backend sends it
  final int? dosificadorId;
  final int? personalRequerido;
  final String estatus;
  final bool logisticaAutorizada;

  const ProgramacionPedido({
    required this.id,
    required this.pedido,
    required this.plantaId,
    required this.fechaProgramada,
    required this.horaArranque,
    this.dosificadorId,
    this.personalRequerido,
    required this.estatus,
    this.logisticaAutorizada = false,
  });

  ProgramacionPedido copyWith({
    DateTime? fechaProgramada,
    String? horaArranque,
    int? dosificadorId,
    int? personalRequerido,
    String? estatus,
    bool? logisticaAutorizada,
  }) => ProgramacionPedido(
    id: id,
    pedido: pedido,
    plantaId: plantaId,
    fechaProgramada: fechaProgramada ?? this.fechaProgramada,
    horaArranque: horaArranque ?? this.horaArranque,
    dosificadorId: dosificadorId ?? this.dosificadorId,
    personalRequerido: personalRequerido ?? this.personalRequerido,
    estatus: estatus ?? this.estatus,
    logisticaAutorizada: logisticaAutorizada ?? this.logisticaAutorizada,
  );
}

class Dosificador {
  final int id;
  final String nombre;

  const Dosificador({required this.id, required this.nombre});
}

// ---------------------------------------------------------------------------
// Mock "service"
// ---------------------------------------------------------------------------

DateTime _hoy() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

bool mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class JefePlantaMock {
  JefePlantaMock._();

  /// The jefe's own planta. Real source: `plantaId` on
  /// `AdministracionService` `GET /empleados/{AuthService.idEmpleado}`.
  static const miPlantaId = 1;

  static const plantas = [
    Planta(id: 1, nombre: 'Planta Norte', tipoPlantaNombre: 'Principal'),
    Planta(id: 2, nombre: 'Planta Sur', tipoPlantaNombre: 'Principal'),
    Planta(id: 3, nombre: 'Planta Oriente', tipoPlantaNombre: 'Satélite'),
  ];

  static Planta? planta(int id) {
    for (final p in plantas) {
      if (p.id == id) return p;
    }
    return null;
  }

  static const dosificadores = [
    Dosificador(id: 11, nombre: 'Dosificador 1'),
    Dosificador(id: 12, nombre: 'Dosificador 2'),
  ];

  static Dosificador? dosificador(int? id) {
    for (final d in dosificadores) {
      if (d.id == id) return d;
    }
    return null;
  }

  // --- Solicitudes --------------------------------------------------------

  static final List<SolicitudCompra> _solicitudes = [
    SolicitudCompra(
      id: 104,
      solicitanteId: 1,
      plantaId: miPlantaId,
      vehiculoId: 3,
      area: 'Flota',
      concepto: 'Juego de llantas para olla',
      motivo: 'Desgaste irregular detectado en la revisión semanal.',
      montoEstimado: 38500,
      estatus: estatusSolicitudEnRevision,
      createdAt: _hoy().subtract(const Duration(days: 1)),
      creadoPorUsuario: 'jefe.planta',
    ),
    SolicitudCompra(
      id: 103,
      solicitanteId: 1,
      plantaId: miPlantaId,
      area: 'Producción',
      concepto: 'Aditivo retardante (4 tambos)',
      motivo: 'Inventario por debajo del mínimo de seguridad.',
      montoEstimado: 21200,
      estatus: estatusSolicitudPendiente,
      createdAt: _hoy().subtract(const Duration(days: 2)),
      creadoPorUsuario: 'jefe.planta',
    ),
    SolicitudCompra(
      id: 101,
      solicitanteId: 1,
      plantaId: miPlantaId,
      area: 'Mantenimiento',
      concepto: 'Banda transportadora de agregados',
      motivo: 'Reemplazo programado.',
      montoEstimado: 64000,
      estatus: estatusSolicitudAutorizada,
      createdAt: _hoy().subtract(const Duration(days: 9)),
      creadoPorUsuario: 'jefe.planta',
    ),
    SolicitudCompra(
      id: 99,
      solicitanteId: 1,
      plantaId: miPlantaId,
      area: 'Seguridad',
      concepto: 'Extintores PQS 9 kg',
      motivo: 'Vencimiento de recarga.',
      montoEstimado: 7800,
      estatus: estatusSolicitudRechazada,
      createdAt: _hoy().subtract(const Duration(days: 15)),
      creadoPorUsuario: 'jefe.planta',
    ),
  ];

  static Future<List<SolicitudCompra>> solicitudes({String? estatus}) async {
    await _latencia();
    return _solicitudes
        .where((s) => estatus == null || s.estatus == estatus)
        .toList();
  }

  static Future<SolicitudCompra> crearSolicitud({
    required String area,
    required String concepto,
    required String motivo,
    double? montoEstimado,
    int? vehiculoId,
    bool conCotizacion = false,
  }) async {
    await _latencia();
    final nueva = SolicitudCompra(
      id: (_solicitudes.map((s) => s.id).fold(0, (a, b) => a > b ? a : b)) + 1,
      solicitanteId: 1,
      plantaId: miPlantaId,
      vehiculoId: vehiculoId,
      area: area,
      concepto: concepto,
      motivo: motivo,
      montoEstimado: montoEstimado,
      cotizacionAdjuntaUrl: conCotizacion ? 'mock://cotizacion.pdf' : null,
      estatus: estatusSolicitudPendiente,
      createdAt: DateTime.now(),
      creadoPorUsuario: 'jefe.planta',
    );
    _solicitudes.insert(0, nueva);
    return nueva;
  }

  static Future<List<BitacoraSolicitud>> bitacora(SolicitudCompra s) async {
    await _latencia();
    final pasos = <BitacoraSolicitud>[
      BitacoraSolicitud(
        accion: 'Solicitud creada',
        usuario: s.creadoPorUsuario ?? '—',
        fecha: s.createdAt,
      ),
    ];
    final orden = [
      estatusSolicitudCotizacionRecibida,
      estatusSolicitudEnRevision,
    ];
    var t = s.createdAt;
    for (final e in orden) {
      if (s.estatus == estatusSolicitudPendiente) break;
      t = t.add(const Duration(hours: 5));
      pasos.add(
        BitacoraSolicitud(
          accion: etiquetaEstatusSolicitud(e),
          usuario: 'compras',
          fecha: t,
        ),
      );
      if (s.estatus == e) break;
    }
    if (s.estatus == estatusSolicitudAutorizada ||
        s.estatus == estatusSolicitudRechazada) {
      pasos.add(
        BitacoraSolicitud(
          accion: etiquetaEstatusSolicitud(s.estatus),
          usuario: 'direccion',
          fecha: t.add(const Duration(hours: 20)),
          comentario: s.estatus == estatusSolicitudRechazada
              ? 'Se cubre con stock de otra planta.'
              : null,
        ),
      );
    }
    return pasos.reversed.toList();
  }

  // --- Ollas --------------------------------------------------------------

  static final List<OllaPlanta> _ollas = [
    const OllaPlanta(
      id: 1,
      numeroUnidad: 'OL-101',
      placas: 'VKL-1201',
      capacidadM3: 8,
      plantaAsignadaId: 1,
      conductorNombre: 'Operador 1',
      estatusOperativo: estatusOperativoDisponible,
    ),
    const OllaPlanta(
      id: 2,
      numeroUnidad: 'OL-102',
      placas: 'VKL-1202',
      capacidadM3: 8,
      plantaAsignadaId: 1,
      conductorNombre: 'Operador 2',
      estatusOperativo: estatusOperativoEnRuta,
    ),
    const OllaPlanta(
      id: 3,
      numeroUnidad: 'OL-105',
      placas: 'VKL-1205',
      capacidadM3: 7,
      plantaAsignadaId: 1,
      estatusOperativo: estatusOperativoMantenimiento,
    ),
    const OllaPlanta(
      id: 4,
      numeroUnidad: 'OL-108',
      placas: 'VKL-1208',
      capacidadM3: 10,
      plantaAsignadaId: 1,
      conductorNombre: 'Operador 4',
      estatusOperativo: estatusOperativoDisponible,
    ),
    const OllaPlanta(
      id: 5,
      numeroUnidad: 'OL-201',
      placas: 'VKL-2201',
      capacidadM3: 8,
      plantaAsignadaId: 2,
      conductorNombre: 'Operador 5',
      estatusOperativo: estatusOperativoDisponible,
    ),
    const OllaPlanta(
      id: 6,
      numeroUnidad: 'OL-202',
      placas: 'VKL-2202',
      capacidadM3: 8,
      plantaAsignadaId: 2,
      estatusOperativo: estatusOperativoDisponible,
    ),
    const OllaPlanta(
      id: 7,
      numeroUnidad: 'OL-301',
      placas: 'VKL-3301',
      capacidadM3: 7,
      plantaAsignadaId: 3,
      conductorNombre: 'Operador 7',
      estatusOperativo: estatusOperativoEnRuta,
    ),
  ];

  static Future<List<OllaPlanta>> ollas({int? plantaId}) async {
    await _latencia();
    return _ollas
        .where((o) => plantaId == null || o.plantaAsignadaId == plantaId)
        .toList();
  }

  /// Mirrors `PUT /vehiculos/{id}` with a new `plantaAsignadaId`.
  static Future<OllaPlanta> moverOlla(int ollaId, int plantaDestinoId) async {
    await _latencia();
    final i = _ollas.indexWhere((o) => o.id == ollaId);
    final movida = _ollas[i].copyWith(plantaAsignadaId: plantaDestinoId);
    _ollas[i] = movida;
    return movida;
  }

  // --- Programación -------------------------------------------------------

  static final _pedidos = [
    PedidoPlanta(
      id: 501,
      folio: 'PED-0501',
      clienteNombre: 'Constructora Delta',
      obraNombre: 'Torre Residencial A',
      producto: "f'c 250 R28 TMA 3/4",
      volumenM3: 42,
      elemento: 'Losa',
      fechaSolicitada: _hoy(),
    ),
    PedidoPlanta(
      id: 502,
      folio: 'PED-0502',
      clienteNombre: 'Grupo Habitat',
      obraNombre: 'Fraccionamiento Las Palmas',
      producto: "f'c 200 R28 TMA 3/4",
      volumenM3: 18,
      elemento: 'Firme',
      fechaSolicitada: _hoy(),
    ),
    PedidoPlanta(
      id: 503,
      folio: 'PED-0503',
      clienteNombre: 'Ingeniería Civil MX',
      obraNombre: 'Puente vehicular km 12',
      producto: "f'c 300 R14 TMA 1",
      volumenM3: 64,
      elemento: 'Zapatas',
      fechaSolicitada: _hoy(),
    ),
    PedidoPlanta(
      id: 504,
      folio: 'PED-0504',
      clienteNombre: 'Particular',
      obraNombre: 'Casa habitación',
      producto: "f'c 150 R28 TMA 3/4",
      volumenM3: 6,
      elemento: 'Banqueta',
      fechaSolicitada: _hoy().add(const Duration(days: 1)),
    ),
    PedidoPlanta(
      id: 505,
      folio: 'PED-0505',
      clienteNombre: 'Constructora Delta',
      obraNombre: 'Torre Residencial B',
      producto: "f'c 250 R28 TMA 3/4",
      volumenM3: 36,
      elemento: 'Columnas',
      fechaSolicitada: _hoy().add(const Duration(days: 1)),
    ),
  ];

  static final List<ProgramacionPedido> _programacion = [
    ProgramacionPedido(
      id: 1,
      pedido: _pedidos[0],
      plantaId: miPlantaId,
      fechaProgramada: _hoy(),
      horaArranque: '07:00',
      dosificadorId: 11,
      personalRequerido: 3,
      estatus: estatusProgramacionAprobado,
      logisticaAutorizada: true,
    ),
    ProgramacionPedido(
      id: 2,
      pedido: _pedidos[1],
      plantaId: miPlantaId,
      fechaProgramada: _hoy(),
      horaArranque: '09:30',
      dosificadorId: 12,
      personalRequerido: 2,
      estatus: estatusProgramacionProgramado,
    ),
    ProgramacionPedido(
      id: 3,
      pedido: _pedidos[2],
      plantaId: miPlantaId,
      fechaProgramada: _hoy(),
      horaArranque: '12:00',
      dosificadorId: 11,
      personalRequerido: 4,
      estatus: estatusProgramacionPrevia,
    ),
  ];

  static Future<List<ProgramacionPedido>> programacion(DateTime fecha) async {
    await _latencia();
    final dia =
        _programacion.where((p) => mismoDia(p.fechaProgramada, fecha)).toList()
          ..sort((a, b) => a.horaArranque.compareTo(b.horaArranque));
    return dia;
  }

  /// Pedidos with no active programación row yet (what `GET
  /// /programacion-produccion?pedidoId=` answers per pedido).
  static Future<List<PedidoPlanta>> pedidosPorProgramar() async {
    await _latencia();
    final programados = _programacion
        .where((p) => p.estatus != estatusProgramacionCancelada)
        .map((p) => p.pedido.id)
        .toSet();
    return _pedidos.where((p) => !programados.contains(p.id)).toList();
  }

  /// Mirrors `POST /programacion-produccion` (new row) or `PUT /{id}`.
  static Future<ProgramacionPedido> guardarProgramacion({
    int? id,
    required PedidoPlanta pedido,
    required DateTime fecha,
    required String horaArranque,
    int? dosificadorId,
    int? personalRequerido,
  }) async {
    await _latencia();
    if (id != null) {
      final i = _programacion.indexWhere((p) => p.id == id);
      final editada = _programacion[i].copyWith(
        fechaProgramada: fecha,
        horaArranque: horaArranque,
        dosificadorId: dosificadorId,
        personalRequerido: personalRequerido,
      );
      _programacion[i] = editada;
      return editada;
    }
    final nueva = ProgramacionPedido(
      id: (_programacion.map((p) => p.id).fold(0, (a, b) => a > b ? a : b)) + 1,
      pedido: pedido,
      plantaId: miPlantaId,
      fechaProgramada: fecha,
      horaArranque: horaArranque,
      dosificadorId: dosificadorId,
      personalRequerido: personalRequerido,
      estatus: estatusProgramacionProgramado,
    );
    _programacion.add(nueva);
    return nueva;
  }

  /// Mirrors `PATCH /programacion-produccion/{id}/estatus`. Approving also
  /// approves the pedido's logística authorization on the backend.
  static Future<ProgramacionPedido> cambiarEstatus(
    int id,
    String estatus,
  ) async {
    await _latencia();
    final i = _programacion.indexWhere((p) => p.id == id);
    final actualizada = _programacion[i].copyWith(
      estatus: estatus,
      logisticaAutorizada: estatus == estatusProgramacionAprobado ? true : null,
    );
    _programacion[i] = actualizada;
    return actualizada;
  }
}

String etiquetaEstatusSolicitud(String estatus) => switch (estatus) {
  estatusSolicitudPendiente => 'Pendiente',
  estatusSolicitudCotizacionRecibida => 'Cotización recibida',
  estatusSolicitudEnRevision => 'En revisión',
  estatusSolicitudAutorizada => 'Autorizada',
  estatusSolicitudRechazada => 'Rechazada',
  _ => estatus,
};

String etiquetaEstatusOperativo(String estatus) => switch (estatus) {
  estatusOperativoDisponible => 'Disponible',
  estatusOperativoEnRuta => 'En ruta',
  estatusOperativoMantenimiento => 'En mantenimiento',
  _ => estatus,
};

String etiquetaEstatusProgramacion(String estatus) => switch (estatus) {
  estatusProgramacionPrevia => 'Previa',
  estatusProgramacionProgramado => 'Programado',
  estatusProgramacionAprobado => 'Aprobado',
  estatusProgramacionCancelada => 'Cancelada',
  _ => estatus,
};
