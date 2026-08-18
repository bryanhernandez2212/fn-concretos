import '../auth/auth_service.dart';
import '../direccion/comercial_service.dart';
import '../operaciones/operaciones_service.dart';
import 'remision.dart';

/// Builds "Mis entregas del día" for the logged-in conductor by chaining
/// three services, none of which know about each other:
///
/// 1. `operaciones`'s `programacion-produccion` — the whole plant's
///    production schedule for a date (not scoped to any one conductor).
/// 2. `operaciones`'s `asignaciones` — who's actually assigned to each of
///    those pedidos, used to keep only this conductor's own deliveries.
/// 3. `comercial`'s `pedidos`/`obras` — the pedido and job-site details
///    (including the obra's lat/lng for the map/navigation).
///
/// These programación records predate any Remisión, so the resulting
/// [Remision]s all have `hitoActual: null`.
class EntregasService {
  /// [fecha] defaults to today; pass a past date to build the same list for
  /// that day instead (see `HistorialEntregasScreen`).
  static Future<List<Remision>> entregasDelDia({DateTime? fecha}) async {
    final dia = fecha ?? DateTime.now();
    final fechaStr =
        '${dia.year.toString().padLeft(4, '0')}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';

    final programacion = await OperacionesService.programacionDelDia(fechaStr);
    final idEmpleado = AuthService.idEmpleado;

    final entregas = <Remision>[];
    for (final item in programacion) {
      final asignaciones = await OperacionesService.asignacionesPorPedido(item.pedidoId);
      final esMia = asignaciones.any((a) => a.conductorId == idEmpleado);
      if (!esMia) continue;

      final pedido = await ComercialService.obtenerPedido(item.pedidoId);
      final obra = await ComercialService.obtenerObra(pedido.obraId);

      // If planta/producción already generated a Remisión for this pedido,
      // grab its id so RouteNavigationScreen can post real GPS pings to it.
      // The app never creates one itself (see vistas.md) — no Remisión yet
      // just means no GPS posting yet.
      final remisiones = await OperacionesService.remisionesPorPedido(pedido.id);
      final propia = remisiones.where((r) => r.conductorId == idEmpleado);
      final remisionPropia = propia.isEmpty ? null : propia.first;

      entregas.add(Remision(
        folio: pedido.folio,
        cliente: pedido.clienteNombre,
        obra: obra.nombre,
        direccion: obra.direccion,
        horaProgramada: item.horaArranque,
        tipoConcreto: pedido.tipoServicio,
        // This remisión's own volume once one exists — not the pedido's
        // total, since a pedido can be split across several remisiones.
        volumenM3: remisionPropia?.metrosCargados ?? remisionPropia?.metrosSolicitados ?? pedido.volumenSolicitadoM3,
        volumenPedidoTotal: pedido.volumenSolicitadoM3,
        volumenAcumuladoPedido: remisionPropia?.metrosAcumuladosPedido,
        volumenPendientePedido: remisionPropia?.metrosPendientesPedido,
        hitoActual: null,
        remisionId: remisionPropia?.id,
        destinoLat: obra.latitud,
        destinoLng: obra.longitud,
        pedidoId: pedido.id,
        clienteId: pedido.clienteId,
        obraId: pedido.obraId,
      ));
    }
    return entregas;
  }
}
