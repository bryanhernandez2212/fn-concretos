import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../direccion/comercial_service.dart';
import '../operaciones/operaciones_service.dart';
import 'remision.dart';

String _fechaStr(DateTime dia) =>
    '${dia.year.toString().padLeft(4, '0')}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';

/// Fleet-wide asignadas/en ruta/entregadas/pendientes breakdown for one day
/// — same 4-way split `EntregasService.entregasDelDia` computes for one
/// conductor's own remisiones, but across every conductor, for Dirección's
/// "Rutas activas" summary card. `asignadas` is the day's total remisiones,
/// not its own bucket — `enRuta + entregadas + pendientes` always sums back
/// to it, same convention as `deliveries/deliveries_widgets.dart`'s
/// `RutasResumenCard`.
class ResumenEntregasDia {
  final int asignadas;
  final int enRuta;
  final int entregadas;
  final int pendientes;

  const ResumenEntregasDia({
    required this.asignadas,
    required this.enRuta,
    required this.entregadas,
    required this.pendientes,
  });
}

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
    final fechaStr = _fechaStr(dia);

    final programacion = await OperacionesService.programacionDelDia(fechaStr);
    final idEmpleado = AuthService.idEmpleado;

    final entregas = <Remision>[];
    for (final item in programacion) {
      final remisiones = await OperacionesService.remisionesPorPedido(item.pedidoId);
      final propias = remisiones.where((r) => r.conductorId == idEmpleado).toList();
      if (propias.isEmpty) {
        debugPrint(
          'EntregasService: pedido ${item.pedidoId} programado hoy pero sin remisión '
          'para conductorId=$idEmpleado (remisiones encontradas: '
          '${remisiones.map((r) => 'id=${r.id} conductorId=${r.conductorId}').toList()})',
        );
        continue;
      }

      final pedido = await ComercialService.obtenerPedido(item.pedidoId);
      final obra = await ComercialService.obtenerObra(pedido.obraId);
      final contacto = await ComercialService.contactoParaEntrega(
        obraId: pedido.obraId,
        clienteId: pedido.clienteId,
      );

      // The same conductor can have more than one remisión on the same
      // pedido — e.g. the olla can't carry the whole volume in one trip, so
      // they make several. Each is its own delivery run (own hito, own
      // horaCarga/horaEntrega), so each gets its own `Remision` entry rather
      // than collapsing to just one — otherwise an already-entregada trip
      // could shadow a still-active one for the same pedido (or vice versa)
      // depending on array order, hiding whichever didn't get picked.
      for (final remisionPropia in propias) {
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
    }
    return entregas;
  }

  /// Fleet-wide counterpart to [entregasDelDia] — every remisión scheduled
  /// for [fecha] (default today) across every conductor, not just the
  /// logged-in one. Skips the per-pedido cliente/obra/contacto lookups
  /// [entregasDelDia] needs to build its detail cards, since a summary
  /// count only needs each remisión's `estatus` — much cheaper to poll
  /// fleet-wide than the full per-driver list would be.
  static Future<ResumenEntregasDia> resumenFlotaDelDia({DateTime? fecha}) async {
    final dia = fecha ?? DateTime.now();
    final fechaStr = _fechaStr(dia);

    final programacion = await OperacionesService.programacionDelDia(fechaStr);

    var entregadas = 0;
    var enRuta = 0;
    var total = 0;
    for (final item in programacion) {
      final remisiones = await OperacionesService.remisionesPorPedido(item.pedidoId);
      for (final remision in remisiones) {
        total++;
        final hito = HitoEntrega.fromBackendValue(remision.estatus);
        if (hito == HitoEntrega.entregado) {
          entregadas++;
        } else if (HitoEntrega.enRutaHitos.contains(hito)) {
          enRuta++;
        }
      }
    }
    return ResumenEntregasDia(
      asignadas: total,
      enRuta: enRuta,
      entregadas: entregadas,
      pendientes: total - entregadas - enRuta,
    );
  }

  /// Rebuilds a single `Remision` from just its `remisionId` — used to open
  /// `DeliveryDetailScreen` when the driver taps the Android Live Update
  /// notification (`main.dart`'s `NavigationLiveUpdate.registerNotificationTapListener`),
  /// which only has a remisionId to work with (embedded in the notification's
  /// PendingIntent extras), not the day's full "Mis entregas del día" list
  /// this app would otherwise already have in memory. Unlike [entregasDelDia]
  /// there's no `ProgramacionProduccion` item for this one remisión, so
  /// `horaProgramada` is left blank rather than guessed. Returns null if the
  /// remisión (or its pedido/obra) can no longer be resolved — the caller
  /// just skips navigating rather than showing a broken detail screen.
  static Future<Remision?> remisionPorId(int remisionId) async {
    final remisionResumen = await OperacionesService.remisionDetalle(remisionId);
    final pedidoId = remisionResumen.pedidoId;
    if (pedidoId == null) return null;

    final pedido = await ComercialService.obtenerPedido(pedidoId);
    final obra = await ComercialService.obtenerObra(pedido.obraId);
    final contacto = await ComercialService.contactoParaEntrega(
      obraId: pedido.obraId,
      clienteId: pedido.clienteId,
    );

    return Remision(
      folio: pedido.folio,
      cliente: pedido.clienteNombre,
      obra: obra.nombre,
      direccion: obra.direccion,
      horaProgramada: '',
      tipoConcreto: pedido.tipoServicio,
      volumenM3: remisionResumen.metrosCargados ?? remisionResumen.metrosSolicitados ?? pedido.volumenSolicitadoM3,
      volumenPedidoTotal: pedido.volumenSolicitadoM3,
      volumenPedidoEntregado: pedido.volumenEntregadoM3,
      volumenPedidoPendiente: pedido.volumenPendienteM3,
      hitoActual: HitoEntrega.fromBackendValue(remisionResumen.estatus),
      remisionId: remisionResumen.id,
      destinoLat: obra.latitud,
      destinoLng: obra.longitud,
      pedidoId: pedido.id,
      clienteId: pedido.clienteId,
      obraId: pedido.obraId,
      contactoNombre: contacto?.nombre,
      contactoCargo: contacto?.cargo,
      telefono: contacto?.telefono,
    );
  }
}
