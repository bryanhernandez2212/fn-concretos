import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import '../../operaciones/remision_tracking.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/field_group.dart';
import '../../widgets/notification_bell_button.dart';
import '../detalle/delivery_detail_screen.dart';
import '../entregas_service.dart';
import 'abrir_turno_screen.dart';
import 'cerrar_turno_screen.dart';
import 'turno_bombeo_service.dart';
import 'turno_bombeo_widgets.dart';

/// "Turno de bombeo" — Operador de Bomba-only tab, the digital version of
/// the paper orden de trabajo: open the day's turno (horómetro inicio), see
/// the remisiones dispatch linked to it, and close it (horómetro fin,
/// precio, recibo, encargado de obra).
class TurnoBombeoScreen extends StatefulWidget {
  const TurnoBombeoScreen({super.key});

  @override
  State<TurnoBombeoScreen> createState() => _TurnoBombeoScreenState();
}

class _TurnoBombeoScreenState extends State<TurnoBombeoScreen> {
  late Future<TurnoBombeoActual> _future;
  int? _abriendoRemisionId;

  @override
  void initState() {
    super.initState();
    _future = TurnoBombeoService.cargar();
  }

  Future<void> _refrescar() async {
    final future = TurnoBombeoService.cargar();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // The FutureBuilder shows the error state.
    }
  }

  Future<void> _abrirTurno() async {
    final abierto = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AbrirTurnoScreen()),
    );
    if (abierto == true) _refrescar();
  }

  Future<void> _cerrarTurno(TurnoBombeoActual actual) async {
    final cerrado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CerrarTurnoScreen(
          turno: actual.turno!,
          remisiones: actual.remisiones,
        ),
      ),
    );
    if (cerrado == true) _refrescar();
  }

  Future<void> _abrirRemision(RemisionResumen r) async {
    setState(() => _abriendoRemisionId = r.id);
    try {
      final remision = await EntregasService.remisionPorId(r.id);
      if (!mounted) return;
      if (remision == null) {
        AppSnack.error(context, 'No se pudo cargar la remisión');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DeliveryDetailScreen(remision: remision),
        ),
      );
      // The m³ bombeados may have been captured in the detail.
      if (mounted) _refrescar();
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo cargar la remisión');
    } finally {
      if (mounted) setState(() => _abriendoRemisionId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);

    return RefreshIndicator(
      onRefresh: _refrescar,
      color: AppColors.accent,
      child: FutureBuilder<TurnoBombeoActual>(
        future: _future,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState != ConnectionState.done;
          final actual = snapshot.data;
          final turno = actual?.turno;

          String subtitulo;
          if (loading) {
            subtitulo = 'Cargando...';
          } else if (snapshot.hasError) {
            subtitulo = 'No se pudo cargar tu turno';
          } else if (turno == null) {
            subtitulo = 'Sin turno abierto';
          } else {
            subtitulo = 'Turno abierto · ${turno.folio}';
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              BottomNavBar.clearance(context) + 16,
            ),
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withValues(alpha: 0.18),
                    ),
                    child: const Icon(
                      Icons.timer_outlined,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Turno de bombeo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        Text(
                          subtitulo,
                          style: TextStyle(fontSize: 13, color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                  const NotificationBellButton(),
                ],
              ),
              const SizedBox(height: 20),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    children: [
                      Text(
                        snapshot.error is AuthException
                            ? (snapshot.error as AuthException).message
                            : 'No se pudo cargar tu turno',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: mutedColor),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _refrescar,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              else if (turno == null)
                SinTurnoCard(onAbrir: _abrirTurno)
              else ...[
                TurnoActivoCard(
                  turno: turno,
                  remisionesLigadas: actual!.remisiones.length,
                ),
                const SizedBox(height: 24),
                Text(
                  'Remisiones del turno',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                if (actual.remisiones.isEmpty)
                  Text(
                    'Aún no hay remisiones ligadas a este turno. Planta las liga al crear la remisión.',
                    style: TextStyle(fontSize: 13.5, color: mutedColor),
                  )
                else
                  FieldGroup(
                    expand: true,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (index, r) in actual.remisiones.indexed) ...[
                          if (index > 0)
                            Divider(
                              height: 1,
                              color: AppColors.border(context),
                            ),
                          TurnoRemisionTile(
                            remision: r,
                            abriendo: _abriendoRemisionId == r.id,
                            onTap: () => _abrirRemision(r),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _cerrarTurno(actual),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text(
                      'Cerrar turno',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(
                        color: AppColors.border(context, alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
