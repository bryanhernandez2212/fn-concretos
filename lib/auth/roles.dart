/// The complete role catalog (from `auth-service`'s `/roles`), kept here as
/// static reference data so screens can show a role's Spanish name and
/// description without an extra network round trip.
class Rol {
  final int id;
  final String nombre;
  final String descripcion;

  const Rol({required this.id, required this.nombre, required this.descripcion});
}

const catalogoRoles = [
  Rol(id: 1, nombre: 'Direccion', descripcion: 'Autoriza créditos, comisiones y excepciones'),
  Rol(id: 2, nombre: 'Ventas', descripcion: 'Cotizaciones, pedidos y seguimiento a clientes'),
  Rol(id: 3, nombre: 'Produccion', descripcion: 'Dosificación, programación y cargas'),
  Rol(id: 4, nombre: 'Laboratorio', descripcion: 'Control de calidad, diseños y ensayos'),
  Rol(id: 5, nombre: 'Recursos Humanos', descripcion: 'Expedientes, asistencias y nómina'),
  Rol(id: 6, nombre: 'Pagos', descripcion: 'Cobranza, facturación y conciliación'),
  Rol(
    id: 7,
    nombre: 'Operador de Olla',
    descripcion: 'App móvil de campo: hitos de entrega, firma, evidencia y GPS en ruta a obra',
  ),
  Rol(
    id: 8,
    nombre: 'Operador de Bomba',
    descripcion: 'App móvil de campo: hitos de entrega, firma y evidencia en ruta a obra',
  ),
];

/// Roles this build has real mobile screens for. Both field operators ride
/// the same Remisión through its hitos (see `AsignacionOllaBomba` in
/// vistas.md), so they share `HomeScreen` as-is — Operador de Bomba just
/// doesn't get the dosificación-report entry point yet (that needs backend
/// work first, per vistas.md).
const rolesConAppMovil = {'Operador de Olla', 'Operador de Bomba'};

Rol? rolPorNombre(String? nombre) {
  for (final rol in catalogoRoles) {
    if (rol.nombre == nombre) return rol;
  }
  return null;
}
