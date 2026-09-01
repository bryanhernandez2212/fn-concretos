import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/notification_bell_button.dart';
import 'agenda_actividad.dart';
import 'asesor_comercial_service.dart';
import 'asesor_comercial_widgets.dart';

const _accentYellow = AppColors.accent;

class _AgendaData {
  final RutaDiaria ruta;
  final List<AgendaActividad> vencidas;

  const _AgendaData({required this.ruta, required this.vencidas});
}

/// "Agenda" tab — the advisor's own `ruta-diaria` for today, plus a banner
/// for any overdue activities (`GET /agenda/pendientes-vencidas`).
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  late Future<_AgendaData> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargar();
  }

  Future<_AgendaData> _cargar() async {
    final asesor = await AsesorComercialService.miAsesor();
    if (asesor == null) {
      throw AuthException('No se encontró un asesor comercial vinculado a esta cuenta');
    }
    final ruta = await AsesorComercialService.rutaDiaria(asesorId: asesor.id, fecha: DateTime.now());
    final vencidas = await AsesorComercialService.actividadesVencidas();
    return _AgendaData(ruta: ruta, vencidas: vencidas);
  }

  void _refresh() {
    setState(() => _future = _cargar());
  }

  Future<void> _marcarEstatus(AgendaActividad actividad, String estatus) async {
    if (!AuthService.permisos.contains(permisoAdministrarAgenda)) return;
    try {
      await AsesorComercialService.actualizarEstatusActividad(actividad.id, estatus: estatus);
      if (!mounted) return;
      AppSnack.success(context, estatus == 'completada' ? 'Actividad marcada como completada' : 'Actividad cancelada');
      _refresh();
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo actualizar la actividad');
    }
  }

  void _abrirAcciones(AgendaActividad actividad) {
    if (!AuthService.permisos.contains(permisoAdministrarAgenda)) return;
    final textColor = AppColors.text(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceAlt(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
              title: Text('Marcar como completada', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                _marcarEstatus(actividad, 'completada');
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: AppColors.error),
              title: Text('Cancelar actividad', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                _marcarEstatus(actividad, 'cancelada');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.08);

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<_AgendaData>(
        future: _future,
        builder: (context, snapshot) {
          final children = <Widget>[
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _accentYellow.withValues(alpha: 0.18)),
                  child: const Icon(Icons.calendar_month_outlined, color: _accentYellow),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Agenda', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
                      Text('Tus actividades de hoy', style: TextStyle(fontSize: 13, color: mutedColor)),
                    ],
                  ),
                ),
                const NotificationBellButton(),
              ],
            ),
            const SizedBox(height: 20),
          ];

          if (snapshot.connectionState != ConnectionState.done) {
            children.add(const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator())));
          } else if (snapshot.hasError) {
            children.add(
              ErrorState(
                message: snapshot.error is AuthException
                    ? (snapshot.error as AuthException).message
                    : 'No se pudo cargar la agenda',
                onRetry: _refresh,
                cardColor: cardColor,
                borderColor: borderColor,
                mutedColor: mutedColor,
              ),
            );
          } else {
            final data = snapshot.data!;
            if (data.vencidas.isNotEmpty) {
              children.add(
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${data.vencidas.length} actividad(es) vencida(s) sin completar',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (data.ruta.actividades.isEmpty) {
              children.add(
                EmptyState(
                  message: 'No tienes actividades programadas para hoy',
                  icon: Icons.event_available_outlined,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  mutedColor: mutedColor,
                ),
              );
            } else {
              for (final actividad in data.ruta.actividades) {
                children.add(
                  ActividadCard(
                    actividad: actividad,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                    onTap: () => _abrirAcciones(actividad),
                  ),
                );
                children.add(const SizedBox(height: 12));
              }
            }
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, BottomNavBar.clearance(context) + 16),
            children: children,
          );
        },
      ),
    );
  }
}
