import '../../auth/auth_service.dart';
import '../../operaciones/operaciones_service.dart';
import '../../operaciones/orden_trabajo_bombeo.dart';
import '../../operaciones/remision_tracking.dart';
import '../../vehicle/vehiculo_service.dart';

/// The open turno plus the remisiones linked to it.
class TurnoBombeoActual {
  final OrdenTrabajoBombeo? turno;
  final List<RemisionResumen> remisiones;

  const TurnoBombeoActual({required this.turno, required this.remisiones});
}

/// The bomba a turno gets opened on, with its unit number for display.
class BombaPropia {
  final int id;
  final String? numeroUnidad;

  const BombaPropia({required this.id, this.numeroUnidad});
}

/// Glue for the Operador de Bomba's "Turno de bombeo" tab on top of
/// `OperacionesService`'s `/ordenes-trabajo-bombeo` calls.
class TurnoBombeoService {
  /// There's no `/ordenes-trabajo-bombeo/{id}/remisiones` yet, so the
  /// linked remisiones are this operator's `remisiones?conductorBombaId=`
  /// filtered to the open turno's id on the client.
  static Future<TurnoBombeoActual> cargar() async {
    final idEmpleado = AuthService.idEmpleado;
    if (idEmpleado == null) {
      throw AuthException(
        'No se encontró tu número de empleado. Vuelve a iniciar sesión.',
      );
    }
    final turno = await OperacionesService.turnoBombeoAbierto(idEmpleado);
    if (turno == null) {
      return const TurnoBombeoActual(turno: null, remisiones: []);
    }

    final todas = await OperacionesService.remisionesPorConductorBomba(
      idEmpleado,
    );
    final ligadas = todas
        .where((r) => r.ordenTrabajoBombeoId == turno.id)
        .toList();
    return TurnoBombeoActual(turno: turno, remisiones: ligadas);
  }

  /// The operator's own bomba: the vehículo assigned to them in the fleet
  /// (`conductorAsignadoId`), falling back to the bomba on their most recent
  /// remisión. Null when neither exists.
  static Future<BombaPropia?> miBomba() async {
    final vehiculo = await VehiculoService.miVehiculo();
    if (vehiculo != null) {
      return BombaPropia(id: vehiculo.id, numeroUnidad: vehiculo.numeroUnidad);
    }

    final idEmpleado = AuthService.idEmpleado;
    if (idEmpleado == null) return null;
    final remisiones = await OperacionesService.remisionesPorConductorBomba(
      idEmpleado,
    );
    final conBomba = remisiones.where((r) => r.vehiculoBombaId != null).toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    if (conBomba.isEmpty) return null;
    final r = conBomba.first;
    return BombaPropia(
      id: r.vehiculoBombaId!,
      numeroUnidad: r.vehiculoBombaNumeroUnidad,
    );
  }
}
