import '../auth/auth_service.dart';
import '../direccion/comercial_service.dart';
import '../operaciones/operaciones_service.dart';
import 'remision.dart';

/// Builds "Mis entregas del día" for the logged-in conductor by chaining
/// three services, none of which know about each other:
///
/// 1. `operaciones`'s `programacion-produccion` — the whole plant's
///    production schedule for a date (not scoped to any one conductor).
/// 2. `operaciones`'s `remisiones` — which conductor a pedido actually
///    belongs to lives on its Remisión's `conductorId`, used to keep only
///    this conductor's own deliveries. Deliberately *not* `/asignaciones`
///    (see `OperacionesService.asignacionesPorPedido`) — that endpoint
///    answers a different question and can come back empty for a pedido
///    that already has a remisión with a conductor on it, silently hiding
///    an otherwise-ready delivery.
/// 3. `comercial`'s `pedidos`/`obras`/`contactoParaEntrega` — the pedido and
///    job-site details (including the obra's lat/lng for the map/navigation,
///    and the specific contacto resolved for this obra+cliente pairing for
///    the detail screen's WhatsApp button).
///
/// A pedido programmed for today with no Remisión yet has no way to know
/// which conductor it belongs to, so it's skipped until planta/producción
/// creates one — this app never creates a Remisión itself (see vistas.md).
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
      final remisiones = await OperacionesService.remisionesPorPedido(item.pedidoId);
      final propia = remisiones.where((r) => r.conductorId == idEmpleado);
      if (propia.isEmpty) continue;
      final remisionPropia = propia.first;

      final pedido = await ComercialService.obtenerPedido(item.pedidoId);
      final obra = await ComercialService.obtenerObra(pedido.obraId);
      final contacto = await ComercialService.contactoParaEntrega(
        obraId: pedido.obraId,
        clienteId: pedido.clienteId,
      );

      entregas.add(Remision(
        folio: pedido.folio,
        cliente: pedido.clienteNombre,
        obra: obra.nombre,
        direccion: obra.direccion,
        horaProgramada: item.horaArranque,
        tipoConcreto: pedido.tipoServicio,
        // This remisión's own volume — not the pedido's total, since a
        // pedido can be split across several remisiones.
        volumenM3: remisionPropia.metrosCargados ?? remisionPropia.metrosSolicitados ?? pedido.volumenSolicitadoM3,
        volumenPedidoTotal: pedido.volumenSolicitadoM3,
        volumenPedidoEntregado: pedido.volumenEntregadoM3,
        volumenPedidoPendiente: pedido.volumenPendienteM3,
        hitoActual: HitoEntrega.fromBackendValue(remisionPropia.estatus),
        remisionId: remisionPropia.id,
        destinoLat: obra.latitud,
        destinoLng: obra.longitud,
        pedidoId: pedido.id,
        clienteId: pedido.clienteId,
        obraId: pedido.obraId,
        contactoNombre: contacto?.nombre,
        contactoCargo: contacto?.cargo,
        telefono: contacto?.telefono,
      ));
    }
    return entregas;
  }
}
