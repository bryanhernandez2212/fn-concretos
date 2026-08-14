import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../operaciones/vehiculo.dart';

/// Resolves the logged-in driver's own vehicle. There's no backend concept
/// of "mi vehículo" as a single call — `GET /vehiculos` is fleet-wide, so
/// this fetches everything and keeps the one whose `conductorAsignadoId`
/// matches `AuthService.idEmpleado`, the same cross-service id assumption
/// already used for `AsignacionResumen.conductorId` (see
/// `deliveries/entregas_service.dart`).
class VehiculoService {
  static Future<VehiculoResumen?> miVehiculo() async {
    final vehiculos = await OperacionesService.vehiculos();
    final idEmpleado = AuthService.idEmpleado;
    for (final vehiculo in vehiculos) {
      if (vehiculo.conductorAsignadoId == idEmpleado) return vehiculo;
    }
    return null;
  }
}
