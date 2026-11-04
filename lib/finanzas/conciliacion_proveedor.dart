library;

/// DTOs for the `conciliacion-proveedor-controller`, `vale-entrada-material-controller`
/// and `entrada-mercancia-controller` in `finanzas-service`.
class ConciliacionProveedor {
  final int id;
  final int proveedorId;
  final String proveedorNombre;
  final String periodoInicio;
  final String periodoFin;
  final int? totalViajes;
  final double? totalArena;
  final double? totalGrava;
  final double? totalAgua;
  final double? totalAPagar;
  final String? diferenciasDetectadas;
  final int? comprobanteId;
  final String estatus;
  final DateTime? createdAt;

  const ConciliacionProveedor({
    required this.id,
    required this.proveedorId,
    required this.proveedorNombre,
    required this.periodoInicio,
    required this.periodoFin,
    this.totalViajes,
    this.totalArena,
    this.totalGrava,
    this.totalAgua,
    this.totalAPagar,
    this.diferenciasDetectadas,
    this.comprobanteId,
    required this.estatus,
    this.createdAt,
  });

  factory ConciliacionProveedor.fromJson(Map<String, dynamic> json) {
    return ConciliacionProveedor(
      id: (json['id'] as num).toInt(),
      proveedorId: (json['proveedorId'] as num).toInt(),
      proveedorNombre: json['proveedorNombre'] as String? ?? 'Proveedor #${json['proveedorId']}',
      periodoInicio: json['periodoInicio'] as String? ?? '',
      periodoFin: json['periodoFin'] as String? ?? '',
      totalViajes: (json['totalViajes'] as num?)?.toInt(),
      totalArena: (json['totalArena'] as num?)?.toDouble(),
      totalGrava: (json['totalGrava'] as num?)?.toDouble(),
      totalAgua: (json['totalAgua'] as num?)?.toDouble(),
      totalAPagar: (json['totalAPagar'] as num?)?.toDouble(),
      diferenciasDetectadas: json['diferenciasDetectadas'] as String?,
      comprobanteId: (json['comprobanteId'] as num?)?.toInt(),
      estatus: json['estatus'] as String? ?? 'BORRADOR',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

/// DTO for a single line in a supplier reconciliation (`ConciliacionDetalleResponse`).
class ConciliacionDetalle {
  final int id;
  final int conciliacionId;
  final int? valeId;
  final int? entradaId;
  final String? estatus;
  final double? diferenciaMonto;
  final String? observaciones;

  const ConciliacionDetalle({
    required this.id,
    required this.conciliacionId,
    this.valeId,
    this.entradaId,
    this.estatus,
    this.diferenciaMonto,
    this.observaciones,
  });

  factory ConciliacionDetalle.fromJson(Map<String, dynamic> json) {
    return ConciliacionDetalle(
      id: (json['id'] as num).toInt(),
      conciliacionId: (json['conciliacionId'] as num).toInt(),
      valeId: (json['valeId'] as num?)?.toInt(),
      entradaId: (json['entradaId'] as num?)?.toInt(),
      estatus: json['estatus'] as String?,
      diferenciaMonto: (json['diferenciaMonto'] as num?)?.toDouble(),
      observaciones: json['observaciones'] as String?,
    );
  }
}

/// Model for `ValeEntradaMaterialResponse` (`vale-entrada-material-controller`).
class ValeEntradaMaterial {
  final int id;
  final int? proveedorId;
  final String? proveedorNombre;
  final int? ordenCompraId;
  final String? ordenCompraFolio;
  final String? material;
  final String? minaOrigen;
  final double? cantidad;
  final String? unidad;
  final String? numeroViaje;
  final String? folioVale;
  final String? fecha;
  final String? firmante;
  final String? transportista;
  final String? placas;
  final String? evidenciaFotoUrl;
  final int? plantaId;
  final String? estatus;
  final bool? tieneEntradaVinculada;
  final DateTime? createdAt;

  const ValeEntradaMaterial({
    required this.id,
    this.proveedorId,
    this.proveedorNombre,
    this.ordenCompraId,
    this.ordenCompraFolio,
    this.material,
    this.minaOrigen,
    this.cantidad,
    this.unidad,
    this.numeroViaje,
    this.folioVale,
    this.fecha,
    this.firmante,
    this.transportista,
    this.placas,
    this.evidenciaFotoUrl,
    this.plantaId,
    this.estatus,
    this.tieneEntradaVinculada,
    this.createdAt,
  });

  factory ValeEntradaMaterial.fromJson(Map<String, dynamic> json) {
    return ValeEntradaMaterial(
      id: (json['id'] as num).toInt(),
      proveedorId: (json['proveedorId'] as num?)?.toInt(),
      proveedorNombre: json['proveedorNombre'] as String?,
      ordenCompraId: (json['ordenCompraId'] as num?)?.toInt(),
      ordenCompraFolio: json['ordenCompraFolio'] as String?,
      material: json['material'] as String?,
      minaOrigen: json['minaOrigen'] as String?,
      cantidad: (json['cantidad'] as num?)?.toDouble(),
      unidad: json['unidad'] as String?,
      numeroViaje: json['numeroViaje'] as String?,
      folioVale: json['folioVale'] as String?,
      fecha: json['fecha'] as String?,
      firmante: json['firmante'] as String?,
      transportista: json['transportista'] as String?,
      placas: json['placas'] as String?,
      evidenciaFotoUrl: json['evidenciaFotoUrl'] as String?,
      plantaId: (json['plantaId'] as num?)?.toInt(),
      estatus: json['estatus'] as String?,
      tieneEntradaVinculada: json['tieneEntradaVinculada'] as bool?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

/// Backwards compatibility alias
typedef ValeEntradaMaterialResumen = ValeEntradaMaterial;

/// Lightweight model for `EntradaMercanciaResponse` used when picking entradas.
class EntradaMercanciaResumen {
  final int id;
  final int? valeId;
  final int? proveedorId;
  final String? proveedorNombre;
  final String? material;
  final double? cantidadRecibida;
  final String? unidad;
  final double? costoUnitario;
  final String? estatus;

  const EntradaMercanciaResumen({
    required this.id,
    this.valeId,
    this.proveedorId,
    this.proveedorNombre,
    this.material,
    this.cantidadRecibida,
    this.unidad,
    this.costoUnitario,
    this.estatus,
  });

  factory EntradaMercanciaResumen.fromJson(Map<String, dynamic> json) {
    return EntradaMercanciaResumen(
      id: (json['id'] as num).toInt(),
      valeId: (json['valeId'] as num?)?.toInt(),
      proveedorId: (json['proveedorId'] as num?)?.toInt(),
      proveedorNombre: json['proveedorNombre'] as String?,
      material: json['material'] as String?,
      cantidadRecibida: (json['cantidadRecibida'] as num?)?.toDouble(),
      unidad: json['unidad'] as String?,
      costoUnitario: (json['costoUnitario'] as num?)?.toDouble(),
      estatus: json['estatus'] as String?,
    );
  }
}
