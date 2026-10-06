import 'package:flutter/material.dart';
import '../../catalogo/planta.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../jefe_planta_mock.dart';
import '../jefe_planta_widgets.dart';
import 'ollas_widgets.dart';

/// "Ollas" tab: the fleet assigned to the jefe's planta (operaciones
/// `GET /vehiculos?plantaId=`), with a toggle to see every planta, and the
/// "mover a otra planta" action (`PUT /vehiculos/{id}` with a new
/// `plantaAsignadaId`). Design-only — runs on [JefePlantaMock].
class OllasScreen extends StatefulWidget {
  const OllasScreen({super.key});

  @override
  State<OllasScreen> createState() => _OllasScreenState();
}

class _OllasScreenState extends State<OllasScreen> {
  bool _soloMiPlanta = true;
  late Future<List<OllaPlanta>> _future;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    setState(() {
      _future = JefePlantaMock.ollas(
        plantaId: _soloMiPlanta ? JefePlantaMock.miPlantaId : null,
      );
    });
  }

  Future<void> _refresh() async {
    _cargar();
    await _future;
  }

  Future<void> _mover(OllaPlanta olla) async {
    final destino = await showModalBottomSheet<Planta>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceAlt(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) =>
          MoverOllaSheet(olla: olla, plantas: JefePlantaMock.plantas),
    );
    if (destino == null || !mounted) return;
    try {
      await JefePlantaMock.moverOlla(olla.id, destino.id);
      if (!mounted) return;
      AppSnack.success(
        context,
        '${olla.numeroUnidad} ahora está en ${destino.nombre}',
      );
      _cargar();
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo mover la olla');
    }
  }

  @override
  Widget build(BuildContext context) {
    final miPlanta = JefePlantaMock.planta(JefePlantaMock.miPlantaId);
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
            subtitle: miPlanta?.nombre ?? 'Tu planta',
          ),
          const SizedBox(height: 12),
          const DatosEjemploBanner(),
          const SizedBox(height: 16),
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
          FutureBuilder<List<OllaPlanta>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const JefePlantaCargando();
              }
              if (snapshot.hasError) {
                return JefePlantaMensaje(
                  icon: Icons.error_outline,
                  mensaje: 'No se pudieron cargar las ollas',
                  onRetry: _cargar,
                );
              }
              final ollas = snapshot.data!;
              if (ollas.isEmpty) {
                return const JefePlantaMensaje(
                  icon: Icons.local_shipping_outlined,
                  mensaje: 'No hay ollas asignadas',
                );
              }
              int cuenta(String e) =>
                  ollas.where((o) => o.estatusOperativo == e).length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ResumenFlotaTile(
                        label: 'Disponibles',
                        valor: cuenta(estatusOperativoDisponible),
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      ResumenFlotaTile(
                        label: 'En ruta',
                        valor: cuenta(estatusOperativoEnRuta),
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 8),
                      ResumenFlotaTile(
                        label: 'Mantenimiento',
                        valor: cuenta(estatusOperativoMantenimiento),
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final o in ollas) ...[
                    OllaCard(
                      olla: o,
                      plantaNombre:
                          JefePlantaMock.planta(o.plantaAsignadaId)?.nombre ??
                          '#${o.plantaAsignadaId}',
                      onMover: () => _mover(o),
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
