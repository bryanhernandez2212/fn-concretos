import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import '../../catalogo/planta.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/header_icon_button.dart';
import '../jefe_planta_service.dart';
import '../jefe_planta_widgets.dart';
import 'mapa_ollas_screen.dart';
import 'ollas_widgets.dart';

/// "Ollas" tab: the fleet assigned to the jefe's planta (operaciones
/// `GET /vehiculos?plantaId=`), with a toggle to see every planta, and the
/// "mover a otra planta" action (`PATCH /vehiculos/{id}/planta`, only with
/// `vehiculos.cambiar_planta`). Ollas out on a remisión can't be moved.
class OllasScreen extends StatefulWidget {
  const OllasScreen({super.key});

  @override
  State<OllasScreen> createState() => _OllasScreenState();
}

class _OllasScreenState extends State<OllasScreen> {
  bool _soloMiPlanta = true;
  late Future<List<OllaPlanta>> _future;
  ContextoPlanta? _contexto;
  Map<int, String> _operadores = const {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    final soloMiPlanta = _soloMiPlanta;
    setState(() {
      _future = JefePlantaService.contexto().then((c) async {
        if (mounted && _contexto == null) setState(() => _contexto = c);
        final ollas = await JefePlantaService.ollas(
          plantaId: soloMiPlanta ? c.miPlantaId : null,
        );
        _cargarOperadores(ollas);
        return ollas;
      });
    });
  }

  Future<void> _cargarOperadores(List<OllaPlanta> ollas) async {
    final nombres = await JefePlantaService.nombresOperadores(
      ollas.map((o) => o.conductorAsignadoId).whereType<int>(),
    );
    if (mounted) setState(() => _operadores = {..._operadores, ...nombres});
  }

  Future<void> _refresh() async {
    _cargar();
    await _future;
  }

  void _verMapa({OllaPlanta? olla}) {
    final contexto = _contexto;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapaOllasScreen(
          plantaId: _soloMiPlanta ? contexto?.miPlantaId : null,
          contexto: contexto,
          ollaId: olla?.id,
          ollaNombre: olla?.numeroUnidad,
        ),
      ),
    );
  }

  Future<void> _mover(OllaPlanta olla) async {
    final plantas = _contexto?.plantas ?? const <Planta>[];
    if (plantas.isEmpty) {
      AppSnack.error(context, 'No se pudo cargar el catálogo de plantas');
      return;
    }
    final destino = await showModalBottomSheet<Planta>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceAlt(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => MoverOllaSheet(olla: olla, plantas: plantas),
    );
    if (destino == null || !mounted) return;
    try {
      await JefePlantaService.moverOlla(olla.id, destino.id);
      if (!mounted) return;
      AppSnack.success(
        context,
        '${olla.numeroUnidad} ahora está en ${destino.nombre}',
      );
      _cargar();
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo mover la olla');
    }
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
            icon: Icons.local_shipping_outlined,
            title: 'Ollas',
            subtitle: _contexto == null
                ? 'Cargando planta…'
                : _contexto!.miPlanta?.nombre ?? 'Todas las plantas',
            action: HeaderIconButton(
              icon: Icons.map_outlined,
              tooltip: 'Ver ollas en el mapa',
              onPressed: _verMapa,
            ),
          ),
          const SizedBox(height: 16),
          if (_contexto?.miPlantaId != null) ...[
            FiltroChips<bool>(
              valores: const [true, false],
              seleccionado: _soloMiPlanta,
              etiqueta: (v) => v == true ? 'Mi planta' : 'Todas las plantas',
              onSelected: (v) {
                _soloMiPlanta = v ?? true;
                _cargar();
              },
            ),
            const SizedBox(height: 16),
          ],
          FutureBuilder<List<OllaPlanta>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const JefePlantaCargando();
              }
              if (snapshot.hasError) {
                return JefePlantaMensaje(
                  icon: Icons.error_outline,
                  mensaje: snapshot.error is AuthException
                      ? (snapshot.error as AuthException).message
                      : 'No se pudieron cargar las ollas',
                  onRetry: _cargar,
                );
              }
              final ollas = snapshot.data!;
              final puedeCambiarPlanta = AuthService.permisos.contains(
                permisoCambiarPlantaVehiculo,
              );
              if (ollas.isEmpty) {
                return const JefePlantaMensaje(
                  icon: Icons.local_shipping_outlined,
                  mensaje: 'No hay ollas asignadas',
                );
              }
              final enRuta = ollas.where((o) => o.enRuta).length;
              final operando = ollas
                  .where(
                    (o) =>
                        !o.enRuta &&
                        o.estatusOperativo == estatusOperativoOperando,
                  )
                  .length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ResumenFlotaTile(
                        label: 'En planta',
                        valor: operando,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      ResumenFlotaTile(
                        label: 'En ruta',
                        valor: enRuta,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 8),
                      ResumenFlotaTile(
                        label: 'Fuera de servicio',
                        valor: ollas.length - operando - enRuta,
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final o in ollas) ...[
                    OllaCard(
                      olla: o,
                      plantaNombre:
                          _contexto?.nombrePlanta(o.plantaAsignadaId) ??
                          (o.plantaAsignadaId == null
                              ? 'Sin planta'
                              : 'Planta #${o.plantaAsignadaId}'),
                      operadorNombre: _operadores[o.conductorAsignadoId],
                      onMover: puedeCambiarPlanta ? () => _mover(o) : null,
                      onUbicacion: () => _verMapa(olla: o),
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
