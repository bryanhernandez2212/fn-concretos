import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../vehicle/vehiculo_service.dart';
import 'operaciones_service.dart';
import 'vehiculo.dart';

/// Which medium feeds a unit's positions into `POST /remisiones/{id}/gps`,
/// chosen per vehículo from the web app (`VehiculoResumen.origenGps`).
///
/// - [appMovil]: this phone sends them while `RouteNavigationScreen` is
///   guiding (the only mode that existed before Samsara).
/// - [samsara]: the backend registers them itself from the unit's Samsara
///   device (`samsaraVehiculoId`) — the phone must NOT also send its own, or
///   the route would get two interleaved position streams. The Samsara API
///   token deliberately lives on the backend, never in this app.
///
/// Anything unrecognized (or no vehículo resolved at all) falls back to
/// [appMovil], so tracking keeps working exactly as before.
enum OrigenGps { appMovil, samsara }

extension OrigenGpsInfo on OrigenGps {
  static OrigenGps parse(String? valor) =>
      valor == 'samsara' ? OrigenGps.samsara : OrigenGps.appMovil;

  bool get telefonoEnviaPosicion => this == OrigenGps.appMovil;

  String get titulo => switch (this) {
    OrigenGps.appMovil => 'Rastreo por GPS del celular',
    OrigenGps.samsara => 'Rastreo por Samsara',
  };

  String get descripcion => switch (this) {
    OrigenGps.appMovil =>
      'Tu ubicación se envía desde este teléfono mientras la ruta está activa. Mantén la navegación abierta.',
    OrigenGps.samsara =>
      'La unidad se rastrea con su dispositivo Samsara. No es necesario mantener la app abierta para el rastreo.',
  };

  IconData get icon => switch (this) {
    OrigenGps.appMovil => Icons.smartphone,
    OrigenGps.samsara => Icons.satellite_alt_outlined,
  };
}

/// The unit a remisión's positions are tracked for, plus its [OrigenGps].
/// [vehiculoId] is what gets sent along with each `/gps` ping.
class RastreoRemision {
  final int? vehiculoId;
  final OrigenGps origen;

  const RastreoRemision({required this.vehiculoId, required this.origen});

  static const porDefecto = RastreoRemision(
    vehiculoId: null,
    origen: OrigenGps.appMovil,
  );
}

class RastreoGpsService {
  /// Resolves which of the remisión's units this driver is on — the olla
  /// for an Operador de Olla, the bomba for an Operador de Bomba, falling
  /// back to whichever one is set, then to the driver's own assigned unit
  /// (`VehiculoService.miVehiculo`) — and reads its `origenGps`.
  /// Best-effort: any failure returns [RastreoRemision.porDefecto] (phone
  /// GPS), so a lookup hiccup never silently stops tracking.
  static Future<RastreoRemision> paraRemision(int remisionId) async {
    try {
      final remision = await OperacionesService.remisionDetalle(remisionId);
      final esBomba = AuthService.rol == 'Operador de Bomba';
      final vehiculoId = esBomba
          ? (remision.vehiculoBombaId ?? remision.vehiculoOllaId)
          : (remision.vehiculoOllaId ?? remision.vehiculoBombaId);

      final VehiculoResumen? vehiculo = vehiculoId != null
          ? await OperacionesService.vehiculo(vehiculoId)
          : await VehiculoService.miVehiculo();
      if (vehiculo == null) return RastreoRemision.porDefecto;
      return RastreoRemision(
        vehiculoId: vehiculo.id,
        origen: OrigenGpsInfo.parse(vehiculo.origenGps),
      );
    } catch (_) {
      return RastreoRemision.porDefecto;
    }
  }
}
