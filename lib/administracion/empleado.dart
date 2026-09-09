class EmpleadoResponse {
  final int id;
  final int empresaId;
  final String nombreCompleto;
  final String? nss;
  final String? curp;
  final String? ineNumero;
  final String? claveElector;
  final String? direccion;
  final String? telefono;
  final String? cuentaBancaria;
  final double? sueldoBase;
  final String? fotoPerfilUrl;
  final String? fechaIngresoReal;
  final String? fechaAlta;
  final int idPuesto;
  final String? puestoNombre;
  final int idArea;
  final String? areaNombre;
  final int? plantaId;
  final String? estatus;

  const EmpleadoResponse({
    required this.id,
    required this.empresaId,
    required this.nombreCompleto,
    required this.nss,
    required this.curp,
    required this.ineNumero,
    required this.claveElector,
    required this.direccion,
    required this.telefono,
    required this.cuentaBancaria,
    required this.sueldoBase,
    required this.fotoPerfilUrl,
    required this.fechaIngresoReal,
    required this.fechaAlta,
    required this.idPuesto,
    required this.puestoNombre,
    required this.idArea,
    required this.areaNombre,
    required this.plantaId,
    required this.estatus,
  });

  factory EmpleadoResponse.fromJson(Map<String, dynamic> json) {
    return EmpleadoResponse(
      id: (json['id'] as num?)?.toInt() ?? 0,
      empresaId: (json['empresaId'] as num?)?.toInt() ?? 0,
      nombreCompleto: json['nombreCompleto'] as String? ?? '',
      nss: json['nss'] as String?,
      curp: json['curp'] as String?,
      ineNumero: json['ineNumero'] as String?,
      claveElector: json['claveElector'] as String?,
      direccion: json['direccion'] as String?,
      telefono: json['telefono'] as String?,
      cuentaBancaria: json['cuentaBancaria'] as String?,
      sueldoBase: (json['sueldoBase'] as num?)?.toDouble(),
      fotoPerfilUrl: json['fotoPerfilUrl'] as String?,
      fechaIngresoReal: json['fechaIngresoReal'] as String?,
      fechaAlta: json['fechaAlta'] as String?,
      idPuesto: (json['idPuesto'] as num?)?.toInt() ?? 0,
      puestoNombre: json['puestoNombre'] as String?,
      idArea: (json['idArea'] as num?)?.toInt() ?? 0,
      areaNombre: json['areaNombre'] as String?,
      plantaId: (json['plantaId'] as num?)?.toInt(),
      estatus: json['estatus'] as String?,
    );
  }

  /// Body for `PUT /empleados/{id}` — every field `EmpleadoRequest` accepts,
  /// carried over unchanged unless overridden here.
  Map<String, dynamic> toRequestJson({String? fotoPerfilUrl}) {
    return {
      'empresaId': empresaId,
      'nombreCompleto': nombreCompleto,
      if (nss != null) 'nss': nss,
      if (curp != null) 'curp': curp,
      if (ineNumero != null) 'ineNumero': ineNumero,
      if (claveElector != null) 'claveElector': claveElector,
      if (direccion != null) 'direccion': direccion,
      if (telefono != null) 'telefono': telefono,
      if (cuentaBancaria != null) 'cuentaBancaria': cuentaBancaria,
      if (sueldoBase != null) 'sueldoBase': sueldoBase,
      'fotoPerfilUrl': fotoPerfilUrl ?? this.fotoPerfilUrl,
      if (fechaIngresoReal != null) 'fechaIngresoReal': fechaIngresoReal,
      if (fechaAlta != null) 'fechaAlta': fechaAlta,
      'idPuesto': idPuesto,
      'idArea': idArea,
      if (plantaId != null) 'plantaId': plantaId,
    };
  }
}
