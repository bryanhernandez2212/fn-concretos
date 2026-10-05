import 'dart:convert';
import '../config/http_client.dart' as http;
import '../auth/auth_service.dart';
import '../config/api_config.dart';
import 'elemento_constructivo.dart';
import 'planta.dart';
import 'producto.dart';

/// Talks to the real fnconcretos `catalogo` sandbox — a fifth microservice
/// this app hadn't talked to before (`catalogo-service`, discovered via its
/// own `/v3/api-docs`). Only the read endpoints `CotizacionFormScreen` needs
/// are covered here — plantas, productos de concreto, and a producto's
/// precio vigente per planta — not the rest of `catalogo-service`
/// (materiales, insumos, empresas, zonas, seguros...), which backs
/// desktop-only catalog administration this app doesn't expose.
class CatalogoService {
  static const _baseUrl = ApiConfig.catalogo;

  static Future<List<Planta>> plantas() async {
    final data = await _get('/plantas');
    return (data as List<dynamic>)
        .map((e) => Planta.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /productos` — "Buscar por resistencia, categoria o nombre"; [q] is
  /// matched against nombre (same free-text idiom as
  /// `ComercialService.buscarClientes`'s `q`).
  static Future<List<Producto>> productos({String? q}) async {
    final query = q == null || q.isEmpty
        ? ''
        : '?q=${Uri.encodeQueryComponent(q)}';
    final data = await _get('/productos$query');
    return (data as List<dynamic>)
        .map((e) => Producto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// A producto's precio can vary per planta — [plantaId] narrows to the one
  /// the cotización is being built for.
  static Future<List<Precio>> preciosProducto(
    int productoId, {
    int? plantaId,
  }) async {
    final query = plantaId == null ? '' : '?plantaId=$plantaId';
    final data = await _get('/productos/$productoId/precios$query');
    return (data as List<dynamic>)
        .map((e) => Precio.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<ElementoConstructivo>> elementosConstructivos() async {
    final data = await _get('/elementos-constructivos');
    return (data as List<dynamic>)
        .map((e) => ElementoConstructivo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /tipos-vehiculo` (Mix/Olla, Pluma, Tracto...) as an id → nombre
  /// map, used to label `VehiculoResumen.tipoVehiculoId` on `VehicleScreen`.
  static Future<Map<int, String>> tiposVehiculo() async {
    final data = await _get('/tipos-vehiculo');
    return {
      for (final e in (data as List<dynamic>).cast<Map<String, dynamic>>())
        (e['id'] as num).toInt(): e['nombre'] as String? ?? '',
    };
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
      final message = data is Map<String, dynamic>
          ? data['message'] as String?
          : null;
      throw AuthException(message ?? 'Ocurrió un error inesperado');
    }
    return data;
  }
}
