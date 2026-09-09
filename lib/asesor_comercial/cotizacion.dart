import 'asesor.dart';

/// `productos[].tipoLinea` values. `producto` (default, needs
/// `productoId`+`volumenM3`) and `bombeo` (no `productoId`, `volumenM3`
/// optional — the backend autofills it as the sum of the cotización's
/// `producto` lines when omitted) are confirmed with the backend team.
/// `servicio` (servicios adicionales, e.g. lavado/flete manual — no
/// `productoId`, flat `precioUnitario`, `volumenM3` optional) mirrors the
/// web app's "Servicios adicionales" bucket but isn't backend-confirmed —
/// `CotizacionItemRequest` only requires `precioUnitario` regardless of
/// `tipoLinea`, so an unrecognized value doesn't fail validation, but the
/// exact string may need correcting once confirmed. `flete_vacio` is
/// generated server-side (one per `producto` línea whose volumen doesn't
/// divide evenly into the planta's capacidad de referencia) and must never
/// be sent by this app — a PUT/POST resends the client's own lines and the
/// backend recalculates flete_vacio from scratch.
const tipoLineaProducto = 'producto';
const tipoLineaBombeo = 'bombeo';
const tipoLineaServicio = 'servicio';
const tipoLineaFleteVacio = 'flete_vacio';

/// Unrecognized values fall back to the raw string (title-cased) rather than
/// being mislabeled as "Producto" — future/renamed `tipoLinea` values should
/// still be legible instead of silently misclassified.
String tipoLineaLabel(String? tipoLinea) {
  switch (tipoLinea) {
    case null:
    case tipoLineaProducto:
      return 'Producto';
    case tipoLineaBombeo:
      return 'Bombeo';
    case tipoLineaServicio:
      return 'Servicio adicional';
    case tipoLineaFleteVacio:
      return 'Flete por vacío';
    default:
      return tipoLinea.isEmpty ? 'Producto' : tipoLinea[0].toUpperCase() + tipoLinea.substring(1);
  }
}

/// `formaPago` values confirmed with the team. Kept as a small `String:label`
/// map rather than an enum, same lightweight style as [tipoLineaLabel] —
/// `CotizacionRequest.formaPago` is still a plain unconstrained string on the
/// backend, this is just what `CotizacionFormScreen`'s dropdown offers.
const formaPagoOpciones = {'efectivo': 'Efectivo', 'factura': 'Factura'};

String formaPagoLabel(String? formaPago) => formaPagoOpciones[formaPago] ?? formaPago ?? '';

/// `tipoServicio` values confirmed with the team: "Directo" (entrega
/// directa) or "Bomba" (servicio con bombeo) — a cotización-level field,
/// distinct from a línea's own `tipoLinea` (which can independently include
/// a `bombeo` línea regardless of this).
const tipoServicioOpciones = {'directo': 'Directo', 'bomba': 'Bomba'};

String tipoServicioLabel(String? tipoServicio) => tipoServicioOpciones[tipoServicio] ?? tipoServicio ?? '';

/// The descuento limit that doesn't require `cotizaciones.aplicar_descuento_especial`
/// depends on whether the cotización requires factura, per the team: up to 5%
/// sin factura/efectivo, 11-12% con factura.
String limiteDescuentoTexto(bool requiereFactura) =>
    requiereFactura ? 'Con factura: 11-12%' : 'Sin factura/efectivo: hasta 5%';

/// Mirrors `CotizacionItemResponse` from `comercial-service` — one línea
/// (partida) of a Cotizacion. The backend requires at least one of these per
/// cotización (`CotizacionRequest.productos`, `minItems: 1`); a Cotizacion
/// used to be a single product/volumen/precio, but the real schema now
/// always carries a list, even when there's only one línea.
class CotizacionItem {
  final int? id;
  final String? tipoLinea;
  final int? productoId;
  final double? volumenM3;
  final double precioUnitario;
  final double? precioTotal;
  final String? descripcion;

  const CotizacionItem({
    this.id,
    this.tipoLinea,
    this.productoId,
    this.volumenM3,
    required this.precioUnitario,
    this.precioTotal,
    this.descripcion,
  });

  factory CotizacionItem.fromJson(Map<String, dynamic> json) {
    return CotizacionItem(
      id: parseAsesorIntOrNull(json['id']),
      tipoLinea: json['tipoLinea'] as String?,
      productoId: parseAsesorIntOrNull(json['productoId']),
      volumenM3: (json['volumenM3'] as num?)?.toDouble(),
      precioUnitario: (json['precioUnitario'] as num?)?.toDouble() ?? 0,
      precioTotal: (json['precioTotal'] as num?)?.toDouble(),
      descripcion: json['descripcion'] as String?,
    );
  }

  /// `tipoLinea` always goes explicit (defaulting to [tipoLineaProducto])
  /// rather than being omitted — the backend branches its own required-field
  /// validation on it. Never build one of these with [tipoLineaFleteVacio];
  /// that línea is server-generated only.
  Map<String, dynamic> toJson() {
    return {
      'tipoLinea': tipoLinea ?? tipoLineaProducto,
      if (productoId != null) 'productoId': productoId,
      if (volumenM3 != null) 'volumenM3': volumenM3,
      'precioUnitario': precioUnitario,
      if (descripcion != null && descripcion!.isNotEmpty) 'descripcion': descripcion,
    };
  }

  CotizacionItem copyWith({
    String? tipoLinea,
    double? volumenM3,
    double? precioUnitario,
    String? descripcion,
  }) {
    return CotizacionItem(
      id: id,
      tipoLinea: tipoLinea ?? this.tipoLinea,
      productoId: productoId,
      volumenM3: volumenM3 ?? this.volumenM3,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      precioTotal: precioTotal,
      descripcion: descripcion ?? this.descripcion,
    );
  }
}

/// Mirrors `CotizacionResponse` from `comercial-service`. A cotización can
/// now hold several [productos] (línea items) rather than a single
/// product/volumen/precio — `volumenM3`/`precioUnitario`/`montoTotal` here
/// stay as the backend's own aggregated totals across all of them.
class Cotizacion {
  final int id;
  final String folio;
  final int clienteId;
  final String clienteNombre;
  final int? obraId;
  final String? obraNombre;
  final int? contactoId;
  final int? plantaId;
  final int asesorId;
  final String asesorNombre;
  final List<CotizacionItem> productos;
  final double volumenM3;
  final String? tipoServicio;
  final String? fechaSuministroEstimada;
  final String? formaPago;
  final bool requiereFactura;
  final double porcentajeDescuento;
  final double precioUnitario;
  final double precioUnitarioConDescuento;
  final double montoTotal;
  final String estatus;
  final int? cotizacionOrigenId;
  final String? createdAt;

  const Cotizacion({
    required this.id,
    required this.folio,
    required this.clienteId,
    required this.clienteNombre,
    required this.obraId,
    required this.obraNombre,
    required this.contactoId,
    required this.plantaId,
    required this.asesorId,
    required this.asesorNombre,
    required this.productos,
    required this.volumenM3,
    required this.tipoServicio,
    required this.fechaSuministroEstimada,
    required this.formaPago,
    required this.requiereFactura,
    required this.porcentajeDescuento,
    required this.precioUnitario,
    required this.precioUnitarioConDescuento,
    required this.montoTotal,
    required this.estatus,
    required this.cotizacionOrigenId,
    required this.createdAt,
  });

  factory Cotizacion.fromJson(Map<String, dynamic> json) {
    return Cotizacion(
      id: parseAsesorInt(json['id']),
      folio: json['folio'] as String? ?? '',
      clienteId: parseAsesorInt(json['clienteId']),
      clienteNombre: json['clienteNombre'] as String? ?? 'Cliente sin nombre',
      obraId: parseAsesorIntOrNull(json['obraId']),
      obraNombre: json['obraNombre'] as String?,
      contactoId: parseAsesorIntOrNull(json['contactoId']),
      plantaId: parseAsesorIntOrNull(json['plantaId']),
      asesorId: parseAsesorInt(json['asesorId']),
      asesorNombre: json['asesorNombre'] as String? ?? '',
      productos: (json['productos'] as List<dynamic>? ?? const [])
          .map((e) => CotizacionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      volumenM3: (json['volumenM3'] as num?)?.toDouble() ?? 0,
      tipoServicio: json['tipoServicio'] as String?,
      fechaSuministroEstimada: json['fechaSuministroEstimada'] as String?,
      formaPago: json['formaPago'] as String?,
      requiereFactura: json['requiereFactura'] as bool? ?? false,
      porcentajeDescuento: (json['porcentajeDescuento'] as num?)?.toDouble() ?? 0,
      precioUnitario: (json['precioUnitario'] as num?)?.toDouble() ?? 0,
      precioUnitarioConDescuento: (json['precioUnitarioConDescuento'] as num?)?.toDouble() ?? 0,
      montoTotal: (json['montoTotal'] as num?)?.toDouble() ?? 0,
      estatus: json['estatus'] as String? ?? 'negociacion',
      cotizacionOrigenId: parseAsesorIntOrNull(json['cotizacionOrigenId']),
      createdAt: json['createdAt'] as String?,
    );
  }
}
