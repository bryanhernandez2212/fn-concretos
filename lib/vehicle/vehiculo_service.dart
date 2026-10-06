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

  /// Resolves the `.glb` URL to render for [vehiculo] — prefers
  /// `modelo3dUrl` already echoed onto the vehículo response, and only
  /// falls back to `GET /modelos-3d?tipoVehiculoId=` (picking the first
  /// `activo` catalog entry for that tipo) for a vehículo that hasn't had
  /// a modelo3d assigned directly yet.
  static Future<String?> modelo3dUrlPara(VehiculoResumen vehiculo) async {
    final urlPropio = vehiculo.modelo3dUrl;
    if (urlPropio != null && urlPropio.isNotEmpty) return urlPropio;

    final tipoVehiculoId = vehiculo.tipoVehiculoId;
    if (tipoVehiculoId == null) return null;
    final modelos = await OperacionesService.modelosPorTipoVehiculo(tipoVehiculoId);
    for (final modelo in modelos) {
      if (modelo.activo) return modelo.url;
    }
    return null;
  }
}
