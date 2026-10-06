import 'dart:async';
import 'package:flutter/material.dart';
import '../notifications/notificaciones_screen.dart';
import '../notifications/notificaciones_service.dart';
import '../theme/app_colors.dart';

/// Bell + unread-count badge, shared across every tab screen in `HomeScreen`,
/// `DireccionHomeScreen`, and `AsesorComercialHomeScreen`. None of those
/// shells has a per-tab AppBar (each tab draws its own header inline), so
/// this is embedded as the trailing widget of each tab's own header row
/// (or an `AppBar` action, for `RutasActivasScreen`) rather than reserved
/// as a separate row above the tabs — keeps every tab's content starting
/// at the same height instead of leaving dead space just for the bell.
/// Polls the unread count every 15s, same cadence as this app's other
/// "someone else's device might have changed this" polling (live tracking,
/// pedido totals) — a new notification is exactly that kind of change.
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  int _noLeidas = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refrescarConteo();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refrescarConteo());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refrescarConteo() async {
    try {
      final conteo = await NotificacionesService.contarNoLeidas();
      if (mounted) setState(() => _noLeidas = conteo);
    } catch (_) {
      // Best-effort — a stale/missing badge isn't worth surfacing an error.
    }
  }

  Future<void> _abrir() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificacionesScreen()));
    _refrescarConteo();
  }

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.surfaceAlt(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _abrir,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tint.withValues(alpha: isDark ? 0.85 : 0.95),
            border: Border.all(color: AppColors.border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(Icons.notifications_outlined, color: AppColors.text(context), size: 22),
              ),
              if (_noLeidas > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tint, width: 1.5),
                    ),
                    child: Text(
                      _noLeidas > 99 ? '99+' : '$_noLeidas',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
