import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/header_icon_button.dart';
import '../jefe_planta_service.dart';
import '../jefe_planta_widgets.dart';
import 'solicitud_detail_screen.dart';
import 'solicitud_form_screen.dart';
import 'solicitudes_widgets.dart';

/// The web's groups, in its order.
const _filtros = <String?>[
  null,
  estatusSolicitudPendiente,
  estatusSolicitudAutorizada,
  estatusSolicitudOcGenerada,
  estatusSolicitudRechazada,
];

/// "Solicitudes" tab: the planta's solicitudes de compra (finanzas
/// `GET /solicitudes-compra?plantaId=`). The estatus filter runs on the
/// client, since "OC generada" is derived from the órdenes de compra.
class SolicitudesScreen extends StatefulWidget {
  const SolicitudesScreen({super.key});

  @override
  State<SolicitudesScreen> createState() => _SolicitudesScreenState();
}

class _SolicitudesScreenState extends State<SolicitudesScreen> {
  String? _filtro;
  late Future<List<SolicitudCompra>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargar();
  }

  Future<List<SolicitudCompra>> _cargar() async {
    final contexto = await JefePlantaService.contexto();
    return JefePlantaService.solicitudes(plantaId: contexto.miPlantaId);
  }

  void _recargar() => setState(() => _future = _cargar());

  Future<void> _refresh() async {
    _recargar();
    await _future;
  }

  Future<void> _nueva() async {
    final creada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const SolicitudFormScreen()),
    );
    if (creada == true) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          BottomNavBar.clearance(context) + 16,
        ),
        children: [
          JefePlantaTabHeader(
            icon: Icons.request_quote_outlined,
            title: 'Solicitudes',
            subtitle: 'Compras de tu planta',
            action: HeaderIconButton(
              icon: Icons.add_circle_outline,
              tooltip: 'Nueva solicitud',
              onPressed: _nueva,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<SolicitudCompra>>(
            future: _future,
            builder: (context, snapshot) {
              final todas = snapshot.data ?? const <SolicitudCompra>[];
              final cargando = snapshot.connectionState != ConnectionState.done;
              final filtros = FiltroChips<String>(
                valores: _filtros,
                seleccionado: _filtro,
                etiqueta: (v) {
                  final label = v == null
                      ? 'Todas'
                      : etiquetaEstatusSolicitud(v);
                  if (cargando || snapshot.hasError) return label;
                  final n = v == null
                      ? todas.length
                      : todas.where((s) => s.estatus == v).length;
                  return '$label  $n';
                },
                onSelected: (v) => setState(() => _filtro = v),
              );
              Widget conFiltros(Widget child) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [filtros, const SizedBox(height: 16), child],
              );
              if (cargando) return conFiltros(const JefePlantaCargando());
              if (snapshot.hasError) {
                return conFiltros(
                  JefePlantaMensaje(
                    icon: Icons.error_outline,
                    mensaje: snapshot.error is AuthException
                        ? (snapshot.error as AuthException).message
                        : 'No se pudieron cargar las solicitudes',
                    onRetry: _recargar,
                  ),
                );
              }
              final solicitudes = todas
                  .where((s) => _filtro == null || s.estatus == _filtro)
                  .toList();
              if (solicitudes.isEmpty) {
                return conFiltros(
                  JefePlantaMensaje(
                    icon: Icons.request_quote_outlined,
                    mensaje: todas.isEmpty
                        ? 'Aún no hay solicitudes de compra de tu planta'
                        : 'No hay solicitudes en este estatus',
                  ),
                );
              }
              return conFiltros(
                Column(
                  children: [
                    for (final s in solicitudes) ...[
                      SolicitudCard(
                        solicitud: s,
                        onTap: () async {
                          final cambio = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (context) =>
                                  SolicitudDetailScreen(solicitud: s),
                            ),
                          );
                          if (cambio == true && mounted) _recargar();
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
