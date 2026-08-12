/// The 9-step delivery lifecycle a `Remisión` moves through, from assignment
/// at the plant to the client's signature. Mirrors the real state machine
/// (`RemisionService.avanzarHito`) so the mock data lines up once wired.
enum HitoEntrega {
  pedidoAsignado,
  cargaEnPlanta,
  salidaDePlanta,
  enRuta,
  llegadaAObra,
  posicionadoParaDescarga,
  descarga,
  entregaCompleta,
  remisionFirmada,
}

extension HitoEntregaLabel on HitoEntrega {
  String get label => switch (this) {
    HitoEntrega.pedidoAsignado => 'Pedido asignado',
    HitoEntrega.cargaEnPlanta => 'Carga en planta',
    HitoEntrega.salidaDePlanta => 'Salida de planta',
    HitoEntrega.enRuta => 'En ruta',
    HitoEntrega.llegadaAObra => 'Llegada a obra',
    HitoEntrega.posicionadoParaDescarga => 'Posicionado para descarga',
    HitoEntrega.descarga => 'Descarga',
    HitoEntrega.entregaCompleta => 'Entrega completa',
    HitoEntrega.remisionFirmada => 'Remisión firmada',
  };
}

/// A delivery run (mock data) assigned to the driver's vehicle/shift.
class Remision {
  final String folio;
  final String cliente;
  final String obra;
  final String direccion;
  final String horaProgramada;
  final String tipoConcreto;
  final double volumenM3;
  final HitoEntrega hitoActual;

  /// Job-site coordinates the delivery-detail map centers on and routes to
  /// (see `delivery_map_section.dart`). Mock lat/lng for now — the real
  /// pipeline is WhatsApp → Google Maps link → `obra-controller`, per
  /// vistas.md's note on how obras get their location.
  final double destinoLat;
  final double destinoLng;

  const Remision({
    required this.folio,
    required this.cliente,
    required this.obra,
    required this.direccion,
    required this.horaProgramada,
    required this.tipoConcreto,
    required this.volumenM3,
    required this.hitoActual,
    required this.destinoLat,
    required this.destinoLng,
  });
}

/// Static placeholder list standing in for "mis entregas del día" until the
/// backend is wired up.
const misEntregasDeHoy = [
  Remision(
    folio: 'REM-10432',
    cliente: 'Constructora Del Valle',
    obra: 'Residencial Las Lomas, Torre B',
    direccion: 'Av. Insurgentes Sur 1234, CDMX',
    horaProgramada: '08:30 AM',
    tipoConcreto: "f'c 250",
    volumenM3: 7.0,
    hitoActual: HitoEntrega.enRuta,
    destinoLat: 19.3654,
    destinoLng: -99.1706,
  ),
  Remision(
    folio: 'REM-10433',
    cliente: 'Grupo Edifica',
    obra: 'Plaza Comercial Norte, local 12',
    direccion: 'Calz. Vallejo 890, CDMX',
    horaProgramada: '10:15 AM',
    tipoConcreto: "f'c 200",
    volumenM3: 5.5,
    hitoActual: HitoEntrega.pedidoAsignado,
    destinoLat: 19.4726,
    destinoLng: -99.1495,
  ),
  Remision(
    folio: 'REM-10429',
    cliente: 'Inmobiliaria Sáenz',
    obra: 'Casa habitación, calle Roble 45',
    direccion: 'Col. Del Carmen, Coyoacán, CDMX',
    horaProgramada: '07:00 AM',
    tipoConcreto: "f'c 300",
    volumenM3: 9.0,
    hitoActual: HitoEntrega.entregaCompleta,
    destinoLat: 19.3467,
    destinoLng: -99.1618,
  ),
  // Destino real (no CDMX) para probar navegación con GPS/ruta reales en
  // Tuxtla Gutiérrez, Chiapas — ver lib/deliveries/route_navigation_screen.dart.
  Remision(
    folio: 'REM-10441',
    cliente: 'Grupo Comercial Chiapas',
    obra: 'Plaza Crystal Tuxtla Gutiérrez',
    direccion: 'Blvd. Belisario Domínguez Km. 1081, Tuxtla Gutiérrez, Chiapas',
    horaProgramada: '11:00 AM',
    tipoConcreto: "f'c 250",
    volumenM3: 6.0,
    hitoActual: HitoEntrega.enRuta,
    destinoLat: 16.7533,
    destinoLng: -93.14987,
  ),
];
