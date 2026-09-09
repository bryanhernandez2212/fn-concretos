/// Mirrors `PlantaResponse` from `catalogo-service` — a planta principal or
/// de cobertura (e.g. "Cintalapa -> Tonala"). `capacidadReferenciaM3`/
/// `precioPorM3Vacio` back `CotizacionFormScreen`'s client-side estimate of
/// the flete_vacio the backend auto-generates on save (one per producto
/// línea whose volumen doesn't divide evenly into the planta's capacidad) —
/// the real amount always comes from the backend's own response afterward,
/// this is only a preview shown before saving.
class Planta {
  final int id;
  final String nombre;
  final String? tipoPlantaNombre;
  final String? estatus;
  final double? capacidadReferenciaM3;
  final double? precioPorM3Vacio;

  const Planta({
    required this.id,
    required this.nombre,
    this.tipoPlantaNombre,
    this.estatus,
    this.capacidadReferenciaM3,
    this.precioPorM3Vacio,
  });

  factory Planta.fromJson(Map<String, dynamic> json) {
    return Planta(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String? ?? 'Planta sin nombre',
      tipoPlantaNombre: json['tipoPlantaNombre'] as String?,
      estatus: json['estatus'] as String?,
      capacidadReferenciaM3: (json['capacidadReferenciaM3'] as num?)?.toDouble(),
      precioPorM3Vacio: (json['precioPorM3Vacio'] as num?)?.toDouble(),
    );
  }
}
