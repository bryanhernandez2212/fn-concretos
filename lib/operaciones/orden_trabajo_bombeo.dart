/// Mirrors `OrdenTrabajoBombeoResponse` from the `operaciones` service — the
/// digital version of the paper "orden de trabajo de bombeo" an Operador de
/// Bomba fills in per turno. The backend generates `folio`
/// (`OTB-YYYYMMDD-####`) on open, and `volumenPorCobrar` on close (the sum
/// of `metrosBombeados` over the remisiones linked to it).
class OrdenTrabajoBombeo {
  final int id;
  final String folio;
  final int? vehiculoBombaId;
  final String? vehiculoBombaNumeroUnidad;
  final int? conductorBombaId;
  final String? auxiliarNombre;
  final String? clienteNombre;
  final String? direccionObra;
  final String? entreCalles;
  final String? telefono;
  final String? solicitadoPor;
  final String? fecha;
  final double? horometroInicio;
  final double? horometroFin;
  final double? precioPorM3;
  final double? volumenPorCobrar;
  final double? importeRecibo;
  final bool? tieneRecibo;
  final String? folioRecibo;
  final String? encargadoObraNombre;
  final String? observaciones;
  final String estatus;
  final DateTime? createdAt;
  final DateTime? cerradoEn;
  final int? totalRemisiones;

  const OrdenTrabajoBombeo({
    required this.id,
    required this.folio,
    this.vehiculoBombaId,
    this.vehiculoBombaNumeroUnidad,
    this.conductorBombaId,
    this.auxiliarNombre,
    this.clienteNombre,
    this.direccionObra,
    this.entreCalles,
    this.telefono,
    this.solicitadoPor,
    this.fecha,
    this.horometroInicio,
    this.horometroFin,
    this.precioPorM3,
    this.volumenPorCobrar,
    this.importeRecibo,
    this.tieneRecibo,
    this.folioRecibo,
    this.encargadoObraNombre,
    this.observaciones,
    required this.estatus,
    this.createdAt,
    this.cerradoEn,
    this.totalRemisiones,
  });

  bool get abierto => estatus == 'abierto';

  factory OrdenTrabajoBombeo.fromJson(Map<String, dynamic> json) {
    int? toInt(dynamic v) =>
        v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
    double? toDouble(dynamic v) =>
        v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

    return OrdenTrabajoBombeo(
      id: toInt(json['id']) ?? 0,
      folio: json['folio'] as String? ?? '',
      vehiculoBombaId: toInt(json['vehiculoBombaId']),
      vehiculoBombaNumeroUnidad: json['vehiculoBombaNumeroUnidad'] as String?,
      conductorBombaId: toInt(json['conductorBombaId']),
      auxiliarNombre: json['auxiliarNombre'] as String?,
      clienteNombre: json['clienteNombre'] as String?,
      direccionObra: json['direccionObra'] as String?,
      entreCalles: json['entreCalles'] as String?,
      telefono: json['telefono'] as String?,
      solicitadoPor: json['solicitadoPor'] as String?,
      fecha: json['fecha'] as String?,
      horometroInicio: toDouble(json['horometroInicio']),
      horometroFin: toDouble(json['horometroFin']),
      precioPorM3: toDouble(json['precioPorM3']),
      volumenPorCobrar: toDouble(json['volumenPorCobrar']),
      importeRecibo: toDouble(json['importeRecibo']),
      tieneRecibo: json['tieneRecibo'] as bool?,
      folioRecibo: json['folioRecibo'] as String?,
      encargadoObraNombre: json['encargadoObraNombre'] as String?,
      observaciones: json['observaciones'] as String?,
      estatus: json['estatus'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      cerradoEn: DateTime.tryParse(json['cerradoEn'] as String? ?? ''),
      totalRemisiones: toInt(json['totalRemisiones']),
    );
  }
}
