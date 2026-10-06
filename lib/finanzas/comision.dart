import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Mirrors `ComisionPeriodoResponse` from `finanzas-service` — one
/// commission cut (fechaInicio–fechaFin) for one asesor, with the pedidos
/// counted toward it in [detalle].
class ComisionPeriodo {
  final int id;
  final int asesorId;
  final String? fechaInicio;
  final String? fechaFin;
  final String estatus;
  final String? fechaAutorizacion;
  final double totalComisiones;
  final List<ComisionDetalle> detalle;

  const ComisionPeriodo({
    required this.id,
    required this.asesorId,
    required this.fechaInicio,
    required this.fechaFin,
    required this.estatus,
    required this.fechaAutorizacion,
    required this.totalComisiones,
    required this.detalle,
  });

  factory ComisionPeriodo.fromJson(Map<String, dynamic> json) {
    return ComisionPeriodo(
      id: _parseInt(json['id']),
      asesorId: _parseInt(json['asesorId']),
      fechaInicio: json['fechaInicio'] as String?,
      fechaFin: json['fechaFin'] as String?,
      estatus: json['estatus'] as String? ?? '',
      fechaAutorizacion: json['fechaAutorizacion'] as String?,
      totalComisiones: (json['totalComisiones'] as num?)?.toDouble() ?? 0,
      detalle: (json['detalle'] as List<dynamic>? ?? const [])
          .map((e) => ComisionDetalle.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Mirrors `ComisionDetalleResponse` — one pedido's contribution to a
/// [ComisionPeriodo]. [motivoAjuste] is set when someone with
/// `comisiones.ajustar` overrode [comisionCalculada] by hand.
class ComisionDetalle {
  final int id;
  final int? pedidoId;
  final int? clienteId;
  final bool esCorporativo;
  final double? metrosSuministrados;
  final double? importeTotal;
  final String? tipoSuministro;
  final double? porcentajeAplicado;
  final double comisionCalculada;
  final String? motivoAjuste;

  const ComisionDetalle({
    required this.id,
    required this.pedidoId,
    required this.clienteId,
    required this.esCorporativo,
    required this.metrosSuministrados,
    required this.importeTotal,
    required this.tipoSuministro,
    required this.porcentajeAplicado,
    required this.comisionCalculada,
    required this.motivoAjuste,
  });

  factory ComisionDetalle.fromJson(Map<String, dynamic> json) {
    return ComisionDetalle(
      id: _parseInt(json['id']),
      pedidoId: _parseIntOrNull(json['pedidoId']),
      clienteId: _parseIntOrNull(json['clienteId']),
      esCorporativo: json['esCorporativo'] as bool? ?? false,
      metrosSuministrados: (json['metrosSuministrados'] as num?)?.toDouble(),
      importeTotal: (json['importeTotal'] as num?)?.toDouble(),
      tipoSuministro: json['tipoSuministro'] as String?,
      porcentajeAplicado: (json['porcentajeAplicado'] as num?)?.toDouble(),
      comisionCalculada: (json['comisionCalculada'] as num?)?.toDouble() ?? 0,
      motivoAjuste: json['motivoAjuste'] as String?,
    );
  }
}

/// Mirrors `ComisionProyectadaResponse` (`GET
/// /comisiones-periodo/proyeccion`) — a commission calculated on the fly
/// for one of the asesor's pedidos that no real cut has processed yet.
/// Never persisted server-side: the amount can still change until the
/// pedido is liquidated and Finanzas runs the corte, so it must never be
/// presented as money already authorized.
class ComisionProyectada {
  final int pedidoId;
  final String folio;
  final int? clienteId;
  final String clienteNombre;
  final double? importeTotal;
  final double? porcentajeAplicado;
  final double comisionProyectada;
  final String estatus;
  final String? estatusGeneralPedido;
  final DateTime? fechaPedido;

  const ComisionProyectada({
    required this.pedidoId,
    required this.folio,
    required this.clienteId,
    required this.clienteNombre,
    required this.importeTotal,
    required this.porcentajeAplicado,
    required this.comisionProyectada,
    required this.estatus,
    required this.estatusGeneralPedido,
    required this.fechaPedido,
  });

  factory ComisionProyectada.fromJson(Map<String, dynamic> json) {
    final fecha = json['fechaPedido'] as String?;
    return ComisionProyectada(
      pedidoId: _parseInt(json['pedidoId']),
      folio: json['folio'] as String? ?? 'Pedido #${json['pedidoId']}',
      clienteId: _parseIntOrNull(json['clienteId']),
      clienteNombre: json['clienteNombre'] as String? ?? 'Cliente sin nombre',
      importeTotal: (json['importeTotal'] as num?)?.toDouble(),
      porcentajeAplicado: (json['porcentajeAplicado'] as num?)?.toDouble(),
      comisionProyectada: (json['comisionProyectada'] as num?)?.toDouble() ?? 0,
      estatus: json['estatus'] as String? ?? '',
      estatusGeneralPedido: json['estatusGeneralPedido'] as String?,
      fechaPedido: fecha == null ? null : DateTime.tryParse(fecha),
    );
  }
}

/// The backend documents exactly two proyección estatus values; anything
/// else falls back to the raw string so a new value still renders.
String proyeccionEstatusLabel(String estatus) {
  switch (estatus) {
    case 'espera_pago_cliente':
      return 'Esperando pago del cliente';
    case 'liquidado_pendiente_corte':
      return 'Liquidado, falta el corte';
    default:
      return estatus.isEmpty ? 'Sin estatus' : estatus.replaceAll('_', ' ');
  }
}

Color proyeccionEstatusColor(String estatus) =>
    estatus == 'liquidado_pendiente_corte' ? AppColors.success : AppColors.warning;

/// The OpenAPI schema doesn't enumerate `estatus`, so this matches on
/// prefix (covering either gender, e.g. `pagado`/`pagada`) and falls back to
/// the raw string, title-cased, for anything unrecognized.
String comisionEstatusLabel(String estatus) {
  final e = estatus.toLowerCase();
  if (e.startsWith('pagad')) return 'Pagada';
  if (e.startsWith('autorizad')) return 'Autorizada';
  if (e.startsWith('calculad')) return 'Calculada';
  if (e.startsWith('pendiente')) return 'Pendiente';
  if (e.startsWith('abiert')) return 'Abierta';
  if (e.startsWith('cancelad')) return 'Cancelada';
  if (e.isEmpty) return 'Sin estatus';
  return e[0].toUpperCase() + e.substring(1).replaceAll('_', ' ');
}

Color comisionEstatusColor(String estatus) {
  final e = estatus.toLowerCase();
  if (e.startsWith('pagad')) return AppColors.success;
  if (e.startsWith('autorizad')) return AppColors.accent;
  if (e.startsWith('cancelad')) return AppColors.error;
  return AppColors.warning;
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _parseIntOrNull(dynamic value) => value == null ? null : _parseInt(value);
