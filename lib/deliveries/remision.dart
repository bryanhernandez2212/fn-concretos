/// The real `RemisionService.avanzarHito` state machine (`PATCH
/// /remisiones/{id}/hitos`'s `evento` values): 7 sequential steps plus
/// `conIncidencia`, an exception state outside the normal sequence. `estatus`
/// (from `GET /remisiones`) can also be overridden to `con_atraso` when
/// late — that's a computed status, not a hito, so it deliberately has no
/// member here; see [HitoEntrega.fromBackendValue].
enum HitoEntrega {
  cargandoPlanta('cargando_planta', 'Cargó en planta'),
  salioPlanta('salio_planta', 'Salió de planta'),
  enCamino('en_camino', 'En camino'),
  proximoLlegar('proximo_llegar', 'Próximo a llegar'),
  enObra('en_obra', 'En obra'),
  descargando('descargando', 'Descargando'),
  entregado('entregado', 'Entregado'),
  conIncidencia('con_incidencia', 'Con incidencia');

  /// The literal snake_case string the backend expects/returns.
  final String backendValue;
  final String label;

  const HitoEntrega(this.backendValue, this.label);

  /// Parses a raw `estatus` string from the backend. A blank value, or the
  /// literal `programado` (confirmed from the real sandbox — the backend's
  /// placeholder status before any hito PATCH), means the Remisión exists
  /// but no hito has ever been PATCHed yet — since a Remisión only gets
  /// created once the truck is being loaded, that's already [cargandoPlanta]
  /// in reality, not "nothing has happened", so it resolves to that rather
  /// than `null`. Returns `null` for anything else that isn't one of the 8
  /// known hito values — notably `con_atraso`, which is a computed status
  /// override, not a hito.
  static HitoEntrega? fromBackendValue(String value) {
    if (value.isEmpty || value == 'programado') return HitoEntrega.cargandoPlanta;
    for (final hito in HitoEntrega.values) {
      if (hito.backendValue == value) return hito;
    }
    return null;
  }
}

/// A delivery run assigned to the driver's vehicle/shift, built from
/// `EntregasService.entregasDelDia`.
class Remision {
  final String folio;
  final String cliente;
  final String obra;
  final String direccion;
  final String horaProgramada;
  final String tipoConcreto;

  /// This specific remisión's own volume (from `RemisionResumen.metrosCargados`
  /// / `metrosSolicitados`) once a Remisión exists — a pedido's total can be
  /// split across several remisiones (e.g. 40 m³ as 4 trucks of 10 m³ each),
  /// so this is NOT the same as [volumenPedidoTotal]. Falls back to the
  /// pedido's total before a Remisión exists, since there's nothing more
  /// specific to show yet.
  final double volumenM3;

  /// The pedido's own solicitado/entregado/pendiente totals — straight from
  /// `Pedido.volumenSolicitadoM3`/`volumenEntregadoM3`/`volumenPendienteM3`,
  /// always known regardless of whether a Remisión exists. Deliberately not
  /// sourced from `RemisionResumen.metrosAcumuladosPedido`/
  /// `metrosPendientesPedido` (a remisión-derived echo of the same pedido
  /// totals) — the pedido's own fields are simpler and always available.
  final double volumenPedidoTotal;
  final double volumenPedidoEntregado;
  final double volumenPedidoPendiente;

  /// Null until a real Remisión (with its own hito state machine) exists
  /// for this delivery — today's production programming alone doesn't have
  /// one yet (see `deliveries/entregas_service.dart`).
  final HitoEntrega? hitoActual;

  /// The real Remisión backing this delivery, if `EntregasService` found one
  /// already created for the pedido (by planta/producción). Null means no
  /// Remisión exists yet, so there's nothing to `POST /remisiones/{id}/gps`
  /// against — [RouteNavigationScreen] simply skips sending GPS in that case
  /// rather than fabricating one (see `vistas.md`; the app doesn't create
  /// Remisiones itself).
  final int? remisionId;

  /// Job-site coordinates the delivery-detail map centers on and routes to,
  /// from the pedido's `Obra` (real, via `ComercialService.obtenerObra`).
  final double destinoLat;
  final double destinoLng;

  /// Ids of the pedido/cliente/obra this delivery belongs to — carried along
  /// so a `POST /pruebas-concreto-fresco` (see `PruebaConcretoScreen`) can
  /// link back to them without an extra lookup.
  final int pedidoId;
  final int clienteId;
  final int obraId;

  /// From `ComercialService.contactoParaEntrega` — the specific person
  /// resolved from the obra↔cliente pairing (not a generic cliente-level
  /// phone; a cliente has none of its own) that `DeliveryDetailScreen`'s
  /// `ContactoCard` shows, same idea as `direccion/PedidoDetailScreen`'s.
  /// Null means no contacto is assigned for this obra+cliente pairing.
  final String? contactoNombre;
  final String? contactoCargo;
  final String? telefono;

  const Remision({
    required this.folio,
    required this.cliente,
    required this.obra,
    required this.direccion,
    required this.horaProgramada,
    required this.tipoConcreto,
    required this.volumenM3,
    required this.volumenPedidoTotal,
    required this.volumenPedidoEntregado,
    required this.volumenPedidoPendiente,
    required this.hitoActual,
    required this.remisionId,
    required this.destinoLat,
    required this.destinoLng,
    required this.pedidoId,
    required this.clienteId,
    required this.obraId,
    required this.contactoNombre,
    required this.contactoCargo,
    required this.telefono,
  });
}
