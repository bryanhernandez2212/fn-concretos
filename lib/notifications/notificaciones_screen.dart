import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import 'notificacion.dart';
import 'notificaciones_service.dart';

/// Backed by auth-service's real `notificacion-controller`. A single flat
/// page (no infinite scroll) — see `NotificacionesService.listar`.
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  late Future<List<Notificacion>> _future;
  List<Notificacion>? _ultimaData;

  @override
  void initState() {
    super.initState();
    _future = NotificacionesService.listar();
  }

  Future<void> _refrescar() async {
    final future = NotificacionesService.listar();
    setState(() => _future = future);
    try {
      await future;
    } catch (e) {
      if (mounted && _ultimaData != null) {
        AppSnack.error(context, e is AuthException ? e.message : 'No se pudo actualizar');
      }
    }
  }

  Future<void> _marcarLeida(Notificacion n) async {
    if (n.leida) return;
    setState(() {
      _ultimaData = _ultimaData
          ?.map((e) => e.id == n.id ? e.copyWith(leida: true, leidaEn: DateTime.now()) : e)
          .toList();
    });
    try {
      await NotificacionesService.marcarLeida(n.id);
    } catch (_) {
      // Best-effort — the badge count elsewhere may lag by one until the
      // next refresh, not worth surfacing an error for a read-receipt.
    }
  }

  Future<void> _marcarTodasLeidas() async {
    final data = _ultimaData;
    if (data == null || data.every((n) => n.leida)) return;
    setState(() {
      _ultimaData = data.map((e) => e.copyWith(leida: true, leidaEn: DateTime.now())).toList();
    });
    try {
      await NotificacionesService.marcarTodasLeidas();
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, e is AuthException ? e.message : 'No se pudo actualizar');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.08);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _marcarTodasLeidas,
            child: const Text('Marcar todas', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refrescar,
        // See DeliveriesScreen: RefreshIndicator needs a scrollable
        // descendant present in every state, so this always returns a
        // ListView regardless of loading/error/success.
        child: FutureBuilder<List<Notificacion>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
              _ultimaData = snapshot.data;
            }
            final data = _ultimaData;

            if (data == null) {
              if (snapshot.hasError) {
                return ListView(
                  children: [_mensaje(
                    icono: Icons.error_outline,
                    texto: snapshot.error is AuthException
                        ? (snapshot.error as AuthException).message
                        : 'No se pudieron cargar las notificaciones',
                    mutedColor: mutedColor,
                  )],
                );
              }
              return const Center(child: CircularProgressIndicator());
            }

            if (data.isEmpty) {
              return ListView(
                children: [_mensaje(
                  icono: Icons.notifications_none,
                  texto: 'No tienes notificaciones',
                  mutedColor: mutedColor,
                )],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: data.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final n = data[index];
                return _NotificacionCard(
                  notificacion: n,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  onTap: () => _marcarLeida(n),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _mensaje({required IconData icono, required String texto, required Color mutedColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 40, color: mutedColor),
          const SizedBox(height: 12),
          Text(texto, textAlign: TextAlign.center, style: TextStyle(color: mutedColor)),
        ],
      ),
    );
  }
}

class _NotificacionCard extends StatelessWidget {
  final Notificacion notificacion;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _NotificacionCard({
    required this.notificacion,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final n = notificacion;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.leida ? cardColor : AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: n.leida ? borderColor : AppColors.accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: n.leida ? Colors.transparent : AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.titulo,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: n.leida ? FontWeight.w600 : FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(n.mensaje, style: TextStyle(color: mutedColor, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat("d 'de' MMM, HH:mm", 'es').format(n.creadoEn),
                    style: TextStyle(color: mutedColor, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
