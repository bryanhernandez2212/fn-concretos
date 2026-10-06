import 'package:flutter/material.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/header_icon_button.dart';
import '../jefe_planta_mock.dart';
import '../jefe_planta_widgets.dart';
import 'solicitud_detail_screen.dart';
import 'solicitud_form_screen.dart';
import 'solicitudes_widgets.dart';

const _filtros = <String?>[
  null,
  estatusSolicitudPendiente,
  estatusSolicitudEnRevision,
  estatusSolicitudAutorizada,
  estatusSolicitudRechazada,
];

/// "Solicitudes" tab: the plant's solicitudes de compra (finanzas
/// `GET /solicitudes-compra?plantaId=`). Design-only — runs on
/// [JefePlantaMock].
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
    _future = JefePlantaMock.solicitudes(estatus: _filtro);
  }

  void _seleccionarFiltro(String? estatus) {
    setState(() {
      _filtro = estatus;
      _future = JefePlantaMock.solicitudes(estatus: estatus);
    });
  }

  Future<void> _refresh() async {
    _seleccionarFiltro(_filtro);
    await _future;
  }

  Future<void> _nueva() async {
    final creada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const SolicitudFormScreen()),
    );
    if (creada == true) _seleccionarFiltro(_filtro);
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
          const SizedBox(height: 12),
          const DatosEjemploBanner(),
          const SizedBox(height: 16),
          FiltroChips<String>(
            valores: _filtros,
            seleccionado: _filtro,
            etiqueta: (v) => v == null ? 'Todas' : etiquetaEstatusSolicitud(v),
            onSelected: _seleccionarFiltro,
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<SolicitudCompra>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const JefePlantaCargando();
              }
              if (snapshot.hasError) {
                return JefePlantaMensaje(
                  icon: Icons.error_outline,
                  mensaje: 'No se pudieron cargar las solicitudes',
                  onRetry: () => _seleccionarFiltro(_filtro),
                );
              }
              final solicitudes = snapshot.data!;
              if (solicitudes.isEmpty) {
                return const JefePlantaMensaje(
                  icon: Icons.request_quote_outlined,
                  mensaje: 'No hay solicitudes en este estatus',
                );
              }
              return Column(
                children: [
                  for (final s in solicitudes) ...[
                    SolicitudCard(
                      solicitud: s,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              SolicitudDetailScreen(solicitud: s),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
