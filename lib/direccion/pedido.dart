/// Mirrors `PedidoResponse` from the `comercial` service
/// (`/sandbox/comercial/v3/api-docs`).
class Pedido {
  final int id;
  final String folio;
  final int clienteId;
  final String clienteNombre;
  final String obraNombre;
  final String tipoServicio;
  final double volumenSolicitadoM3;
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
    required this.clienteNombre,
    required this.obraNombre,
    required this.tipoServicio,
    required this.volumenSolicitadoM3,
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
      id: json['id'] as int,
      folio: json['folio'] as String? ?? '',
      clienteId: json['clienteId'] as int,
      clienteNombre: json['clienteNombre'] as String? ?? 'Cliente sin nombre',
      obraNombre: json['obraNombre'] as String? ?? 'Obra sin nombre',
      tipoServicio: json['tipoServicio'] as String? ?? '',
      volumenSolicitadoM3: (json['volumenSolicitadoM3'] as num?)?.toDouble() ?? 0,
      condicionPago: json['condicionPago'] as String? ?? '',
      diasCredito: json['diasCredito'] as int?,
      fechaProgramada: json['fechaProgramada'] as String?,
      estatusPagoAutorizacion: json['estatusPagoAutorizacion'] as String? ?? '',
      estatusLogisticaAutorizacion: json['estatusLogisticaAutorizacion'] as String? ?? '',
      estatusGeneral: json['estatusGeneral'] as String? ?? '',
      motivoRechazo: json['motivoRechazo'] as String?,
    );
  }
}

/// Mirrors `ClienteResponse` — only the credit-relevant fields Dirección
/// needs when judging a pedido.
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
