import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import 'pedido.dart';

/// Granular permission names (as returned in `/auth/me`'s `permisos`) that
/// gate the Dirección screens — checked instead of `AuthService.rol` so
/// access follows whatever the backend's role/permission catalog actually
/// grants, not a hardcoded role name (`roles-controller` lets permissions be
/// reassigned to different roles independently of this app).
const permisoAutorizarCredito = 'pedidos.autorizar_credito';
const permisoAutorizarLogistica = 'pedidos.autorizar_logistica';

/// Talks to the real fnconcretos `comercial` sandbox (see its
/// `/v3/api-docs`) — pedidos, autorizaciones, clientes. Reuses
/// [AuthService.authHeaders] for the bearer token; this app has no
/// state-management package, so results are returned directly rather than
/// cached anywhere.
class ComercialService {
  static const _baseUrl = 'https://fnconcretos.app/sandbox/comercial';

  static Future<List<Pedido>> pedidosPendientesDePago() async {
    final data = await _get('/pedidos?estatusGeneral=pendiente_autorizacion_pago');
    debugPrint('pedidosPendientesDePago raw: ${jsonEncode(data)}'); // TEMP debug
    return (data as List<dynamic>).map((e) => Pedido.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Pedido> obtenerPedido(int id) async {
    final data = await _get('/pedidos/$id');
    return Pedido.fromJson(data as Map<String, dynamic>);
  }

  static Future<Cliente> obtenerCliente(int id) async {
    final data = await _get('/clientes/$id');
    return Cliente.fromJson(data as Map<String, dynamic>);
  }

  static Future<Obra> obtenerObra(int id) async {
    final data = await _get('/obras/$id');
    return Obra.fromJson(data as Map<String, dynamic>);
  }

  static Future<EstadoCuenta> estadoCuenta(int clienteId) async {
    final data = await _get('/clientes/$clienteId/estado-cuenta');
    return EstadoCuenta.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<ObraCliente>> clientesPorObra(int obraId) async {
    final data = await _get('/obras/$obraId/clientes');
    return (data as List<dynamic>).map((e) => ObraCliente.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<ClienteContacto>> contactosCliente(int clienteId) async {
    final data = await _get('/clientes/$clienteId/contactos');
    return (data as List<dynamic>).map((e) => ClienteContacto.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Resolves the specific person to contact for delivering [clienteId]'s
  /// pedido at [obraId] — cross-references the obra↔cliente association
  /// (which one, if any, has a contacto assigned for this specific pairing,
  /// since an obra can have more than one cliente tied to it) with that
  /// cliente's contact directory (which has the actual `telefono`). Returns
  /// null if no contacto is assigned for this pairing, or the referenced
  /// contacto no longer exists in the directory.
  static Future<ClienteContacto?> contactoParaEntrega({
    required int obraId,
    required int clienteId,
  }) async {
    final asociaciones = await clientesPorObra(obraId);
    final propia = asociaciones.where((a) => a.clienteId == clienteId);
    final contactoId = propia.isEmpty ? null : propia.first.contactoId;
    if (contactoId == null) return null;

    final contactos = await contactosCliente(clienteId);
    final match = contactos.where((c) => c.id == contactoId);
    return match.isEmpty ? null : match.first;
  }

  /// `resultado` is `'aprobado'` or `'rechazado'`; `motivo` is required by
  /// the backend when rechazando.
  static Future<void> autorizarPago(int pedidoId, {required String resultado, String? motivo}) {
    return _post('/pedidos/$pedidoId/autorizaciones/pago', {
      'resultado': resultado,
      if (motivo != null) 'motivo': motivo,
    });
  }

  static Future<void> autorizarLogistica(int pedidoId, {required String resultado, String? motivo}) {
    return _post('/pedidos/$pedidoId/autorizaciones/logistica', {
      'resultado': resultado,
      if (motivo != null) 'motivo': motivo,
    });
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

  static Future<void> _post(String path, Map<String, dynamic> body) async {
    final headers = await AuthService.authHeaders();
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (_) {
      throw AuthException('No se pudo conectar con el servidor');
    }
    _handleResponse(response);
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
