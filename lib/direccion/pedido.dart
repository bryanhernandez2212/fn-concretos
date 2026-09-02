/// Mirrors `PedidoResponse` from the `comercial` service
/// (`/sandbox/comercial/v3/api-docs`).
class Pedido {
  final int id;
  final String folio;
  final int clienteId;
  final int obraId;
  final String clienteNombre;
  final String obraNombre;
  final String tipoServicio;
  final double volumenSolicitadoM3;
  final double volumenEntregadoM3;
  final double volumenPendienteM3;
  final String condicionPago;
  final int? diasCredito;
  final String? fechaProgramada;
  final String estatusPagoAutorizacion;
  final String estatusLogisticaAutorizacion;
  final String estatusGeneral;
  final String? motivoRechazo;

  const Pedido({
    required this.id,
    required this.folio,
    required this.clienteId,
    required this.obraId,
    required this.clienteNombre,
    required this.obraNombre,
    required this.tipoServicio,
    required this.volumenSolicitadoM3,
    required this.volumenEntregadoM3,
    required this.volumenPendienteM3,
    required this.condicionPago,
    required this.diasCredito,
    required this.fechaProgramada,
    required this.estatusPagoAutorizacion,
    required this.estatusLogisticaAutorizacion,
    required this.estatusGeneral,
    required this.motivoRechazo,
  });

  factory Pedido.fromJson(Map<String, dynamic> json) {
    return Pedido(
      id: _parseInt(json['id']),
      folio: json['folio'] as String? ?? '',
      clienteId: _parseInt(json['clienteId']),
      obraId: _parseInt(json['obraId']),
      clienteNombre: json['clienteNombre'] as String? ?? 'Cliente sin nombre',
      obraNombre: json['obraNombre'] as String? ?? 'Obra sin nombre',
      tipoServicio: json['tipoServicio'] as String? ?? '',
      volumenSolicitadoM3: (json['volumenSolicitadoM3'] as num?)?.toDouble() ?? 0,
      volumenEntregadoM3: (json['volumenEntregadoM3'] as num?)?.toDouble() ?? 0,
      volumenPendienteM3: (json['volumenPendienteM3'] as num?)?.toDouble() ?? 0,
      condicionPago: json['condicionPago'] as String? ?? '',
      diasCredito: _parseIntOrNull(json['diasCredito']),
      fechaProgramada: json['fechaProgramada'] as String?,
      estatusPagoAutorizacion: json['estatusPagoAutorizacion'] as String? ?? '',
      estatusLogisticaAutorizacion: json['estatusLogisticaAutorizacion'] as String? ?? '',
      estatusGeneral: json['estatusGeneral'] as String? ?? '',
      motivoRechazo: json['motivoRechazo'] as String?,
    );
  }
}
/// The backend documents `id`/`clienteId`/`obraId` as `int64` but doesn't
/// mark them required, and some Spring/Jackson setups serialize `Long`
/// fields as JSON strings to dodge JS's 53-bit safe-integer limit — either
/// of which would throw a raw `TypeError` (not the `AuthException` that
/// screens special-case) if cast directly with `as int`.
int _parseInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _parseIntOrNull(dynamic value) => value == null ? null : _parseInt(value);

/// Mirrors `ClienteResponse` — only the credit-relevant fields Dirección
/// needs when judging a pedido. A cliente has no phone/contact info of its
/// own — that lives on its named contacts (see [ClienteContacto]), since a
/// cliente can have several (e.g. one per obra, or one per role like
/// "Compras" vs. "Residente de obra").
class Cliente {
  final int id;
  final String nombre;
  final double limiteCredito;
  final int diasCredito;
  final String estatus;

  const Cliente({
    required this.id,
    required this.nombre,
    required this.limiteCredito,
    required this.diasCredito,
    required this.estatus,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['id'] as int,
      nombre: json['nombre'] as String? ?? '',
      limiteCredito: (json['limiteCredito'] as num?)?.toDouble() ?? 0,
      diasCredito: json['diasCredito'] as int? ?? 0,
      estatus: json['estatus'] as String? ?? '',
    );
  }
}

/// Mirrors one row of `GET /obras/{obraId}/clientes` — a cliente↔obra
/// association. A single obra can have more than one cliente tied to it
/// (shared job sites), so this must be filtered by `clienteId` to find the
/// pairing relevant to a specific pedido. `contactoId` is which of that
/// cliente's [ClienteContacto]s is the one to reach for deliveries at this
/// specific obra — null means no contacto was assigned for this pairing.
class ObraCliente {
  final int clienteId;
  final int? contactoId;

  const ObraCliente({required this.clienteId, required this.contactoId});

  factory ObraCliente.fromJson(Map<String, dynamic> json) {
    return ObraCliente(
      clienteId: _parseInt(json['clienteId']),
      contactoId: _parseIntOrNull(json['contactoId']),
    );
  }
}

/// Mirrors one row of `GET /clientes/{clienteId}/contactos` — a named
/// person at the cliente (e.g. "Ing. Federico Solorzano, Residente de obra
/// (turno matutino)"). `telefono` is nullable — not every contacto has one
/// on file, in which case there's simply no WhatsApp button to show for
/// them.
class ClienteContacto {
  final int id;
  final String nombre;
  final String? telefono;
  final String? cargo;

  const ClienteContacto({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.cargo,
  });

  factory ClienteContacto.fromJson(Map<String, dynamic> json) {
    return ClienteContacto(
      id: _parseInt(json['id']),
      nombre: json['nombre'] as String? ?? '',
      telefono: json['telefono'] as String?,
      cargo: json['cargo'] as String?,
    );
  }
}

/// Mirrors `EstadoCuentaResponse`. `disponible=false` means the proxy to
/// finanzas-service isn't backed by anything real yet — the saldo/adeudo
/// fields are just zeros in that case, not a real "cliente al corriente".
class EstadoCuenta {
  final bool disponible;
  final double saldoActual;
  final double adeudoVencido;
  final double anticiposDisponibles;
  final bool moroso;
  final String? mensaje;

  const EstadoCuenta({
    required this.disponible,
    required this.saldoActual,
    required this.adeudoVencido,
    required this.anticiposDisponibles,
    required this.moroso,
    required this.mensaje,
  });

  factory EstadoCuenta.fromJson(Map<String, dynamic> json) {
    return EstadoCuenta(
      disponible: json['disponible'] as bool? ?? false,
      saldoActual: (json['saldoActual'] as num?)?.toDouble() ?? 0,
      adeudoVencido: (json['adeudoVencido'] as num?)?.toDouble() ?? 0,
      anticiposDisponibles: (json['anticiposDisponibles'] as num?)?.toDouble() ?? 0,
      moroso: json['moroso'] as bool? ?? false,
      mensaje: json['mensaje'] as String?,
    );
  }
}

/// Mirrors `ObraResponse` — just the fields
/// `deliveries/entregas_service.dart` needs to point the map/navigation at
/// the job site.
class Obra {
  final int id;
  final String nombre;
  final String direccion;
  final String clientePrincipalNombre;
  final double latitud;
  final double longitud;
  final String? ciudad;
  final String? colonia;

  const Obra({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.clientePrincipalNombre,
    required this.latitud,
    required this.longitud,
    this.ciudad,
    this.colonia,
  });

  factory Obra.fromJson(Map<String, dynamic> json) {
    return Obra(
      id: json['id'] as int,
      nombre: json['nombre'] as String? ?? 'Obra sin nombre',
      direccion: json['direccion'] as String? ?? '',
      clientePrincipalNombre: json['clientePrincipalNombre'] as String? ?? '',
      latitud: (json['latitud'] as num?)?.toDouble() ?? 0,
      longitud: (json['longitud'] as num?)?.toDouble() ?? 0,
      ciudad: json['ciudad'] as String?,
      colonia: json['colonia'] as String?,
    );
  }
}
