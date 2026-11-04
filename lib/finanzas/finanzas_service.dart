import 'dart:convert';
import '../config/http_client.dart' as http;
import '../auth/auth_service.dart';
import '../config/api_config.dart';
import '../jefe_planta/jefe_planta_service.dart' show Proveedor;
import 'comision.dart';
import 'conciliacion_proveedor.dart';
import 'facturacion.dart';
import 'orden_compra.dart';

/// Talks to the real fnconcretos `finanzas` sandbox (`finanzas-service`,
/// its own `/v3/api-docs`), same `AuthService.authHeaders()` bearer pattern
/// as the other services. Only the read endpoints an Asesor Comercial
/// needs to see their own commissions — not `comision-periodo-controller`'s
/// write side (abrir periodo, agregar detalle, generar corte, autorizar,
/// ajustar, marcar pagada), which are administrative actions gated behind
/// `comisiones.autorizar`/`comisiones.ajustar` and belong to the desktop
/// system.
///
/// Also backs Dirección's "Compras" tab: `orden-compra-controller`'s reads
/// plus autorizar/rechazar only — creating an orden, sending it to
/// authorization and the post-autorización estatus flow stay on desktop.
class FinanzasService {
  static const _baseUrl = ApiConfig.finanzas;

  /// `GET /comisiones-periodo?asesorId=` — `asesorId` is required by the
  /// backend; it's the `Asesor.id` (see `AsesorComercialService.miAsesor`),
  /// not the auth account id.
  static Future<List<ComisionPeriodo>> periodosComision({required int asesorId}) async {
    final data = await _get('/comisiones-periodo?asesorId=$asesorId');
    return (data as List<dynamic>).map((e) => ComisionPeriodo.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `GET /comisiones-periodo/proyeccion?asesorId=` — projected (not yet
  /// cut) commissions for the asesor's pedidos. Calculated on the fly
  /// server-side, never persisted; a pedido drops off this list once a real
  /// corte processes it and it shows up under [periodosComision] instead.
  static Future<List<ComisionProyectada>> proyeccionComision({required int asesorId}) async {
    final data = await _get('/comisiones-periodo/proyeccion?asesorId=$asesorId');
    return (data as List<dynamic>).map((e) => ComisionProyectada.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<ComisionPeriodo> periodoComision(int id) async {
    final data = await _get('/comisiones-periodo/$id');
    return ComisionPeriodo.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /ordenes-compra` — no filter: the "por autorizar" estatus value
  /// isn't enumerated in the schema, so narrowing happens client-side via
  /// [OrdenCompra.porAutorizar] rather than guessing `?estatus=`.
  static Future<List<OrdenCompra>> ordenesCompra() async {
    final data = await _get('/ordenes-compra');
    return (data as List<dynamic>).map((e) => OrdenCompra.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `GET /ordenes-compra/{id}` — includes `items`.
  static Future<OrdenCompra> ordenCompra(int id) async {
    final data = await _get('/ordenes-compra/$id');
    return OrdenCompra.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<OrdenCompraBitacora>> bitacoraOrdenCompra(int id) async {
    final data = await _get('/ordenes-compra/$id/bitacora');
    return (data as List<dynamic>).map((e) => OrdenCompraBitacora.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Requires [permisoAutorizarOrdenesCompra].
  static Future<OrdenCompra> autorizarOrdenCompra(int id) async {
    final data = await _patch('/ordenes-compra/$id/autorizar');
    return OrdenCompra.fromJson(data as Map<String, dynamic>);
  }

  /// Requires [permisoAutorizarOrdenesCompra].
  static Future<OrdenCompra> rechazarOrdenCompra(int id, {required String motivo}) async {
    final data = await _patch('/ordenes-compra/$id/rechazar', {'motivoRechazo': motivo});
    return OrdenCompra.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /pagos/resumen-por-pedido` — amount paid per pedido. A pedido is
  /// "Pagado" once this covers its `montoTotal` (the web's rule, ±0.01).
  static Future<Map<int, double>> pagadoPorPedido(List<int> pedidoIds) async {
    if (pedidoIds.isEmpty) return {};
    final query = Uri(queryParameters: {'pedidoIds': pedidoIds.map((id) => '$id').toList()}).query;
    final data = await _get('/pagos/resumen-por-pedido?$query');
    return {
      for (final e in data as List<dynamic>)
        ((e as Map<String, dynamic>)['pedidoId'] as num).toInt(): (e['montoPagado'] as num?)?.toDouble() ?? 0,
    };
  }

  /// `GET /facturas/resumen-por-pedido` — backs the "Facturación" badge.
  static Future<Map<int, PedidoFacturacionResumen>> facturacionPorPedido(List<int> pedidoIds) async {
    if (pedidoIds.isEmpty) return {};
    final query = Uri(queryParameters: {'pedidoIds': pedidoIds.map((id) => '$id').toList()}).query;
    final data = await _get('/facturas/resumen-por-pedido?$query');
    final resumenes = (data as List<dynamic>).map((e) => PedidoFacturacionResumen.fromJson(e as Map<String, dynamic>));
    return {for (final r in resumenes) r.pedidoId: r};
  }

  static Future<List<Prefactura>> prefacturasDePedido(int pedidoId) async {
    final data = await _get('/prefacturas?pedidoId=$pedidoId');
    return (data as List<dynamic>).map((e) => Prefactura.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `POST /prefacturas/generar-por-pedido/{pedidoId}` — the whole pedido's
  /// real amount; links its delivered/signed remisiones automatically.
  static Future<Prefactura> generarPrefacturaPedido(int pedidoId) async {
    final data = await _post('/prefacturas/generar-por-pedido/$pedidoId');
    return Prefactura.fromJson(data as Map<String, dynamic>);
  }

  /// Public link of a prefactura, the printable page the web opens with
  /// "Ver prefactura" (`https://fnconcretos.app/prefactura/{token}`).
  static Future<Uri> ligaPublicaPrefactura(int prefacturaId) async {
    final data = await _post('/prefacturas/$prefacturaId/token-compartido');
    final token = (data as Map<String, dynamic>)['token'] as String;
    return Uri.parse('https://fnconcretos.app/prefactura/$token');
  }

  /// `POST /pagos` for an anticipo registered while converting a cotización,
  /// with the same body the web sends (`condicionPedido: 'anticipo'`).
  static Future<void> registrarAnticipo({
    required int clienteId,
    required int pedidoId,
    required int cotizacionId,
    required double monto,
    required String metodoPago,
    String? cuentaDestino,
    required bool requiereFactura,
    int? vendedorId,
  }) async {
    final ahora = DateTime.now();
    String dos(int n) => n.toString().padLeft(2, '0');
    final fechaPago =
        '${ahora.year}-${dos(ahora.month)}-${dos(ahora.day)}T${dos(ahora.hour)}:${dos(ahora.minute)}:${dos(ahora.second)}';
    await _post('/pagos', {
      'clienteId': clienteId,
      'fechaPago': fechaPago,
      'monto': monto,
      'metodoPago': metodoPago,
      if (cuentaDestino != null) 'cuentaDestino': cuentaDestino,
      'requiereFactura': requiereFactura,
      'condicionPedido': 'anticipo',
      'pedidoId': pedidoId,
      'cotizacionId': cotizacionId,
      if (vendedorId != null) 'vendedorId': vendedorId,
    });
  }

  // ---------------------------------------------------------------------
  // Conciliación de proveedores (`conciliacion-proveedor-controller`)
  // ---------------------------------------------------------------------

  /// Active proveedores list (`GET /proveedores?estatus=activo`).
  static Future<List<Proveedor>> proveedores() async {
    final data = await _get('/proveedores?estatus=activo');
    return (data as List<dynamic>)
        .map((e) => Proveedor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /conciliaciones-proveedor?proveedorId=`
  static Future<List<ConciliacionProveedor>> conciliacionesProveedor({
    required int proveedorId,
  }) async {
    final data = await _get('/conciliaciones-proveedor?proveedorId=$proveedorId');
    return (data as List<dynamic>)
        .map((e) => ConciliacionProveedor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /conciliaciones-proveedor` — abre una conciliación para un periodo.
  static Future<ConciliacionProveedor> abrirConciliacionProveedor({
    required int proveedorId,
    required String periodoInicio,
    required String periodoFin,
  }) async {
    final data = await _post('/conciliaciones-proveedor', {
      'proveedorId': proveedorId,
      'periodoInicio': periodoInicio,
      'periodoFin': periodoFin,
    });
    return ConciliacionProveedor.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /conciliaciones-proveedor/{id}/detalle`
  static Future<List<ConciliacionDetalle>> detalleConciliacionProveedor(int id) async {
    final data = await _get('/conciliaciones-proveedor/$id/detalle');
    return (data as List<dynamic>)
        .map((e) => ConciliacionDetalle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `PATCH /conciliaciones-proveedor/{id}/estatus`
  static Future<ConciliacionProveedor> cambiarEstatusConciliacionProveedor(
    int id, {
    required String estatus,
  }) async {
    final data = await _patch('/conciliaciones-proveedor/$id/estatus', {
      'estatus': estatus,
    });
    return ConciliacionProveedor.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /conciliaciones-proveedor/{id}/detalle`
  static Future<ConciliacionDetalle> agregarDetalleConciliacionProveedor(
    int id, {
    int? valeId,
    int? entradaId,
    String? estatus,
    double? diferenciaMonto,
    String? observaciones,
  }) async {
    final data = await _post('/conciliaciones-proveedor/$id/detalle', {
      if (valeId != null) 'valeId': valeId,
      if (entradaId != null) 'entradaId': entradaId,
      if (estatus != null) 'estatus': estatus,
      if (diferenciaMonto != null) 'diferenciaMonto': diferenciaMonto,
      if (observaciones != null) 'observaciones': observaciones,
    });
    return ConciliacionDetalle.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /vales-entrada-material`
  static Future<List<ValeEntradaMaterial>> valesEntradaMaterial({
    int? proveedorId,
    String? estatus,
    int? plantaId,
    int? ordenCompraId,
  }) async {
    final params = <String, String>{
      if (proveedorId != null) 'proveedorId': '$proveedorId',
      if (estatus != null && estatus.isNotEmpty) 'estatus': estatus,
      if (plantaId != null) 'plantaId': '$plantaId',
      if (ordenCompraId != null) 'ordenCompraId': '$ordenCompraId',
    };
    final query = params.isNotEmpty ? '?${Uri(queryParameters: params).query}' : '';
    final data = await _get('/vales-entrada-material$query');
    return (data as List<dynamic>)
        .map((e) => ValeEntradaMaterial.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /vales-entrada-material` — registra un vale de entrada de material.
  static Future<ValeEntradaMaterial> registrarValeEntradaMaterial(
    Map<String, dynamic> body,
  ) async {
    final data = await _post('/vales-entrada-material', body);
    return ValeEntradaMaterial.fromJson(data as Map<String, dynamic>);
  }

  /// `PATCH /vales-entrada-material/{id}/estatus`
  static Future<ValeEntradaMaterial> cambiarEstatusValeEntradaMaterial(
    int id, {
    required String estatus,
  }) async {
    final data = await _patch('/vales-entrada-material/$id/estatus', {
      'estatus': estatus,
    });
    return ValeEntradaMaterial.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /entradas-mercancia`
  static Future<List<EntradaMercanciaResumen>> entradasMercancia({
    int? proveedorId,
  }) async {
    final params = <String, String>{
      if (proveedorId != null) 'proveedorId': '$proveedorId',
    };
    final query = params.isNotEmpty ? '?${Uri(queryParameters: params).query}' : '';
    final data = await _get('/entradas-mercancia$query');
    return (data as List<dynamic>)
        .map((e) => EntradaMercanciaResumen.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<dynamic> _post(String path, [Map<String, dynamic>? body]) async {
    final headers = await AuthService.authHeaders();
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: body == null ? null : jsonEncode(body),
      );
    } catch (_) {
      throw AuthException('No se pudo conectar con el servidor');
    }
    return _handleResponse(response);
  }

  static Future<dynamic> _patch(String path, [Map<String, dynamic>? body]) async {
    final headers = await AuthService.authHeaders();
    final http.Response response;
    try {
      response = await http.patch(
        Uri.parse('$_baseUrl$path'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: body == null ? null : jsonEncode(body),
      );
    } catch (_) {
      throw AuthException('No se pudo conectar con el servidor');
    }
    return _handleResponse(response);
  }

  static Future<dynamic> _get(String path) async {
    final headers = await AuthService.authHeaders();
    final http.Response response;
    try {
      response = await http.get(Uri.parse('$_baseUrl$path'), headers: headers);
    } catch (_) {
      throw AuthException('No se pudo conectar con el servidor');
    }
    return _handleResponse(response);
  }

  static dynamic _handleResponse(http.Response response) {
    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        throw AuthException('Respuesta inesperada del servidor');
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map<String, dynamic> ? data['message'] as String? : null;
      throw AuthException(message ?? 'Ocurrió un error inesperado');
    }
    return data;
  }
}
