import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Permission `finanzas-service` requires for `PATCH /ordenes-compra/{id}/
/// autorizar` and `/rechazar` — also what gates Dirección's "Compras" tab
/// (see `direccion/direccion_home_screen.dart`), checked by permission
/// rather than role name for the same reason as `pedidos.autorizar_credito`.
const permisoAutorizarOrdenesCompra = 'ordenes_compra.autorizar';

/// Mirrors `OrdenCompraDetalleResponse` — one line item of an orden de
/// compra (material, insumo or servicio).
class OrdenCompraItem {
  final int id;
  final String? tipoItem;
  final String descripcion;
  final String? unidad;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;
  final double iva;
  final double total;

  const OrdenCompraItem({
    required this.id,
    required this.tipoItem,
    required this.descripcion,
    required this.unidad,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    required this.iva,
    required this.total,
  });

  factory OrdenCompraItem.fromJson(Map<String, dynamic> json) {
    return OrdenCompraItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      tipoItem: json['tipoItem'] as String?,
      descripcion: json['descripcion'] as String? ?? '',
      unidad: json['unidad'] as String?,
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
      precioUnitario: (json['precioUnitario'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      iva: (json['iva'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Mirrors `OrdenCompraResponse` from `finanzas-service`'s
/// `orden-compra-controller`. Only read + autorizar/rechazar are used by
/// this app — creating, sending to authorization and the post-autorización
/// estatus flow (en_espera_entrega, recibida, pagada...) stay on desktop.
class OrdenCompra {
  final int id;
  final String folio;
  final int? proveedorId;
  final String proveedorNombre;
  final int? plantaId;
  final String? condicionPago;
  final bool facturacionConIva;
  final String? destinoTipo;
  final int? vehiculoDestinoId;
  final String? areaDestino;
  final double subtotal;
  final double iva;
  final double total;
  final String estatus;
  final String? motivoRechazo;
  final DateTime? fechaAutorizacion;
  final DateTime? createdAt;
  final String? creadoPorUsuario;
  final List<OrdenCompraItem> items;

  const OrdenCompra({
    required this.id,
    required this.folio,
    required this.proveedorId,
    required this.proveedorNombre,
    required this.plantaId,
    required this.condicionPago,
    required this.facturacionConIva,
    required this.destinoTipo,
    required this.vehiculoDestinoId,
    required this.areaDestino,
    required this.subtotal,
    required this.iva,
    required this.total,
    required this.estatus,
    required this.motivoRechazo,
    required this.fechaAutorizacion,
    required this.createdAt,
    required this.creadoPorUsuario,
    required this.items,
  });

  /// The OpenAPI schema doesn't enumerate `estatus`, so the "waiting on
  /// Dirección" state is matched loosely: any value mentioning
  /// autorización that isn't already a result (`autorizada`/`rechazada`).
  /// UNVERIFIED against live data — if the backend uses a different word
  /// (e.g. `enviada`), add it to [_estatusPorAutorizar].
  static const _estatusPorAutorizar = {
    'pendiente_autorizacion',
    'en_autorizacion',
    'por_autorizar',
    'enviada_autorizacion',
    'enviada_a_autorizacion',
  };

  bool get porAutorizar {
    final e = estatus.toLowerCase();
    if (_estatusPorAutorizar.contains(e)) return true;
    return e.contains('autoriz') &&
        !e.contains('autorizad') &&
        !e.contains('rechaz');
  }

  factory OrdenCompra.fromJson(Map<String, dynamic> json) {
    return OrdenCompra(
      id: (json['id'] as num).toInt(),
      folio: json['folio'] as String? ?? '',
      proveedorId: (json['proveedorId'] as num?)?.toInt(),
      proveedorNombre:
          json['proveedorNombre'] as String? ?? 'Proveedor sin nombre',
      plantaId: (json['plantaId'] as num?)?.toInt(),
      condicionPago: json['condicionPago'] as String?,
      facturacionConIva: json['facturacionConIva'] as bool? ?? false,
      destinoTipo: json['destinoTipo'] as String?,
      vehiculoDestinoId: (json['vehiculoDestinoId'] as num?)?.toInt(),
      areaDestino: json['areaDestino'] as String?,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      iva: (json['iva'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      estatus: json['estatus'] as String? ?? '',
      motivoRechazo: json['motivoRechazo'] as String?,
      fechaAutorizacion: DateTime.tryParse(
        json['fechaAutorizacion'] as String? ?? '',
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      creadoPorUsuario: json['creadoPorUsuario'] as String?,
      items: ((json['items'] as List<dynamic>?) ?? const [])
          .map((e) => OrdenCompraItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Mirrors `OrdenCompraBitacoraResponse` — one estatus change.
class OrdenCompraBitacora {
  final String? estatusAnterior;
  final String estatusNuevo;
  final String? comentario;
  final String? usuario;
  final DateTime? createdAt;

  const OrdenCompraBitacora({
    required this.estatusAnterior,
    required this.estatusNuevo,
    required this.comentario,
    required this.usuario,
    required this.createdAt,
  });

  factory OrdenCompraBitacora.fromJson(Map<String, dynamic> json) {
    return OrdenCompraBitacora(
      estatusAnterior: json['estatusAnterior'] as String?,
      estatusNuevo: json['estatusNuevo'] as String? ?? '',
      comentario: json['comentario'] as String?,
      usuario: json['usuario'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

/// Spanish label for a snake_case estatus — known ones mapped, anything
/// else de-underscored and capitalized (same fallback idiom as
/// `finanzas/comision.dart`).
String etiquetaEstatusOrdenCompra(String estatus) {
  const conocidos = {
    'borrador': 'Borrador',
    'pendiente_autorizacion': 'Por autorizar',
    'en_autorizacion': 'Por autorizar',
    'por_autorizar': 'Por autorizar',
    'autorizada': 'Autorizada',
    'rechazada': 'Rechazada',
    'en_espera_entrega': 'En espera de entrega',
    'recibida': 'Recibida',
    'pagada': 'Pagada',
    'cerrada': 'Cerrada',
    'con_diferencia': 'Con diferencia',
    'cancelada': 'Cancelada',
  };
  final conocido = conocidos[estatus];
  if (conocido != null) return conocido;
  if (estatus.isEmpty) return 'Sin estatus';
  final texto = estatus.replaceAll('_', ' ');
  return texto[0].toUpperCase() + texto.substring(1);
}

Color colorEstatusOrdenCompra(String estatus) {
  final e = estatus.toLowerCase();
  if (e.startsWith('rechaz') || e.startsWith('cancel')) return AppColors.error;
  if (e.startsWith('autorizad') ||
      e == 'pagada' ||
      e == 'cerrada' ||
      e == 'recibida') {
    return AppColors.success;
  }
  if (e.contains('autoriz') || e == 'con_diferencia') return AppColors.warning;
  return Colors.blueGrey;
}
