class ElementoConstructivo {
  final int id;
  final String nombre;
  final String? descripcion;

  const ElementoConstructivo({
    required this.id,
    required this.nombre,
    this.descripcion,
  });

  factory ElementoConstructivo.fromJson(Map<String, dynamic> json) {
    return ElementoConstructivo(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String? ?? 'Sin nombre',
      descripcion: json['descripcion'] as String?,
    );
  }
}
