class Producto {
  final int id;
  final String nombre;
  final String? categoria;
  final String? resistencia;
  final String? revenimiento;
  final String? descripcion;
  final String? estatus;

  const Producto({
    required this.id,
    required this.nombre,
    this.categoria,
    this.resistencia,
    this.revenimiento,
    this.descripcion,
    this.estatus,
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String? ?? 'Producto sin nombre',
      categoria: json['categoria'] as String?,
      resistencia: json['resistencia'] as String?,
      revenimiento: json['revenimiento'] as String?,
      descripcion: json['descripcion'] as String?,
      estatus: json['estatus'] as String?,
    );
  }
}

/// Mirrors `PrecioResponse` — a producto's precio vigente at one planta.
class Precio {
  final int id;
  final int productoId;
  final int plantaId;
  final double precio;

  const Precio({
    required this.id,
    required this.productoId,
    required this.plantaId,
    required this.precio,
  });

  factory Precio.fromJson(Map<String, dynamic> json) {
    return Precio(
      id: (json['id'] as num).toInt(),
      productoId: (json['productoId'] as num).toInt(),
      plantaId: (json['plantaId'] as num).toInt(),
      precio: (json['precio'] as num?)?.toDouble() ?? 0,
    );
  }
}
