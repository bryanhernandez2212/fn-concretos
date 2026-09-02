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

  /// `GET /clientes` — searches by `tipo`/`estatus` plus free-text `q`
  /// (matches against nombre/numeroCliente per cliente-controller's
  /// description). Dirección's own screens never search clientes — they
  /// only ever look one up by the id a Pedido already carries — so this
  /// exists for Asesor Comercial's obra-registration flow, which needs to
  /// pick an existing cliente instead of typing a raw id.
  static Future<List<Cliente>> buscarClientes({String? q, String? tipo, String? estatus}) async {
    final params = {
      if (q != null && q.isNotEmpty) 'q': q,
      if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
      if (estatus != null && estatus.isNotEmpty) 'estatus': estatus,
    };
    final query = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    final data = await _get('/clientes$query');
    return (data as List<dynamic>).map((e) => Cliente.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Registers a new cliente — same reasoning as [crearObra]: Asesor
  /// Comercial's field flow can hit a cliente that isn't in the system yet
  /// either, not just the obra.
  static Future<Cliente> crearCliente({
    required String nombre,
    String? numeroCliente,
    String? tipo,
    String? rfc,
    String? telefono,
    bool? whatsappDisponible,
    String? correo,
    bool? requiereFacturaDefault,
    int? asesorAsignadoId,
    double? limiteCredito,
    int? diasCredito,
  }) async {
    final data = await _post('/clientes', {
      'nombre': nombre,
      if (numeroCliente != null && numeroCliente.isNotEmpty) 'numeroCliente': numeroCliente,
      if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
      if (rfc != null && rfc.isNotEmpty) 'rfc': rfc,
      if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
      if (whatsappDisponible != null) 'whatsappDisponible': whatsappDisponible,
      if (correo != null && correo.isNotEmpty) 'correo': correo,
      if (requiereFacturaDefault != null) 'requiereFacturaDefault': requiereFacturaDefault,
      if (asesorAsignadoId != null) 'asesorAsignadoId': asesorAsignadoId,
      if (limiteCredito != null) 'limiteCredito': limiteCredito,
      if (diasCredito != null) 'diasCredito': diasCredito,
    });
    return Cliente.fromJson(data as Map<String, dynamic>);
  }

  static Future<Obra> obtenerObra(int id) async {
    final data = await _get('/obras/$id');
    return Obra.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /obras` — searches by `nombre`/`ciudad`/`estatus` (per
  /// obra-controller's own description, "Buscar obras por estatus, ciudad o
  /// nombre"). Used by Asesor Comercial's "registrar visita" flow to find
  /// an obra that's already in the system for a repeat visit, instead of
  /// only ever being able to register a brand-new one.
  static Future<List<Obra>> buscarObras({String? nombre, String? ciudad, String? estatus}) async {
    final params = {
      if (nombre != null && nombre.isNotEmpty) 'nombre': nombre,
      if (ciudad != null && ciudad.isNotEmpty) 'ciudad': ciudad,
      if (estatus != null && estatus.isNotEmpty) 'estatus': estatus,
    };
    final query = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    final data = await _get('/obras$query');
    return (data as List<dynamic>).map((e) => Obra.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Registers a new Obra (job site) — needed before a cotización can be
  /// created for a cliente whose site isn't in the system yet. Used by
  /// Asesor Comercial's obra-registration flow (`ObraFormScreen`); kept
  /// here rather than `asesor_comercial_service.dart` since it belongs to
  /// this file's `obtenerObra`/`clientesPorObra` domain.
  static Future<Obra> crearObra({
    required String nombre,
    required int clientePrincipalId,
    String? direccion,
    String? googleMapsLink,
    double? latitud,
    double? longitud,
    String? ciudad,
    String? colonia,
  }) async {
    final data = await _post('/obras', {
      'nombre': nombre,
      'clientePrincipalId': clientePrincipalId,
      if (direccion != null && direccion.isNotEmpty) 'direccion': direccion,
      if (googleMapsLink != null && googleMapsLink.isNotEmpty) 'googleMapsLink': googleMapsLink,
      if (latitud != null) 'latitud': latitud,
      if (longitud != null) 'longitud': longitud,
      if (ciudad != null && ciudad.isNotEmpty) 'ciudad': ciudad,
      if (colonia != null && colonia.isNotEmpty) 'colonia': colonia,
    });
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

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
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
