/// DTOs for the `material-insumo-servicio-controller` — materiales (arena,
/// grava, agua), insumos (refacciones/consumibles de parque vehicular) and
/// servicios (mantenimiento, grúa, lavado) used by the conciliación de
/// agregados screen in Dirección.
library;

/// Mirrors `MaterialResponse` from `catalogo-service`.
class MaterialAgregado {
  final int id;
  final String nombre;
  final String unidad;
  final String? descripcion;
  final String estatus;

  const MaterialAgregado({
    required this.id,
    required this.nombre,
    required this.unidad,
    required this.descripcion,
    required this.estatus,
  });

  factory MaterialAgregado.fromJson(Map<String, dynamic> json) {
    return MaterialAgregado(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String? ?? '',
      unidad: json['unidad'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      estatus: json['estatus'] as String? ?? '',
    );
  }
}

/// Mirrors `InsumoResponse` from `catalogo-service`.
class InsumoAgregado {
  final int id;
  final String nombre;
  final String unidad;
  final String? categoria;
  final String? descripcion;
  final String estatus;

  const InsumoAgregado({
    required this.id,
    required this.nombre,
    required this.unidad,
    required this.categoria,
    required this.descripcion,
    required this.estatus,
  });

  factory InsumoAgregado.fromJson(Map<String, dynamic> json) {
    return InsumoAgregado(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String? ?? '',
      unidad: json['unidad'] as String? ?? '',
      categoria: json['categoria'] as String?,
      descripcion: json['descripcion'] as String?,
      estatus: json['estatus'] as String? ?? '',
    );
  }
}

/// Mirrors `ServicioResponse` from `catalogo-service`.
class ServicioAgregado {
  final int id;
  final String nombre;
  final String? descripcion;
  final String estatus;

  const ServicioAgregado({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.estatus,
  });

  factory ServicioAgregado.fromJson(Map<String, dynamic> json) {
    return ServicioAgregado(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      estatus: json['estatus'] as String? ?? '',
    );
  }
}
