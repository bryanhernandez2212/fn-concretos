import 'asesor.dart';

/// Mirrors `CotizacionResponse` from `comercial-service`. Single-product
/// model — no line-item/`partidas` list in this backend's schema.
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
  final int? productoId;
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
    required this.productoId,
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
      productoId: parseAsesorIntOrNull(json['productoId']),
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
    );
  }
}
