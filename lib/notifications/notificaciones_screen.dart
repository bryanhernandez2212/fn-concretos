import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import 'notificacion.dart';
import 'notificaciones_service.dart';

/// Backed by auth-service's real `notificacion-controller`. Infinite scroll:
/// loads [_pageSize] at a time, fetching the next page once the user
/// scrolls near the bottom (see [_onScroll]) — see
/// `NotificacionesService.listar`.
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  final List<Notificacion> _items = [];
  bool _cargandoInicial = true;
  bool _cargandoMas = false;
  bool _hasMore = true;
  int _pagina = 0;
  AuthException? _errorInicial;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _cargarInicial();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _cargandoMas || _cargandoInicial) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _cargarMas();
    }
  }

  Future<void> _cargarInicial() async {
    setState(() {
      _cargandoInicial = true;
      _errorInicial = null;
    });
    try {
      final resultado = await NotificacionesService.listar(page: 0, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(resultado.items);
        _pagina = 0;
        _hasMore = resultado.hasMore;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorInicial = e is AuthException ? e : AuthException('No se pudieron cargar las notificaciones'));
      }
    } finally {
      if (mounted) setState(() => _cargandoInicial = false);
    }
  }

  Future<void> _cargarMas() async {
    setState(() => _cargandoMas = true);
    try {
      final siguiente = _pagina + 1;
      final resultado = await NotificacionesService.listar(page: siguiente, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(resultado.items);
        _pagina = siguiente;
        _hasMore = resultado.hasMore;
      });
    } catch (_) {
      // Best-effort — a failed "load more" just leaves _hasMore as-is, so
      // the next scroll near the bottom retries rather than surfacing an
      // error over what's already loaded fine.
    } finally {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  Future<void> _marcarLeida(Notificacion n) async {
    if (n.leida) return;
    setState(() {
      final idx = _items.indexWhere((e) => e.id == n.id);
      if (idx != -1) _items[idx] = n.copyWith(leida: true, leidaEn: DateTime.now());
    });
    try {
      await NotificacionesService.marcarLeida(n.id);
    } catch (_) {
      // Best-effort — the badge count elsewhere may lag by one until the
      // next refresh, not worth surfacing an error for a read-receipt.
    }
  }

  Future<void> _marcarTodasLeidas() async {
    if (_items.isEmpty || _items.every((n) => n.leida)) return;
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(leida: true, leidaEn: DateTime.now());
      }
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

    Widget body;
    if (_cargandoInicial && _items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items.isEmpty && _errorInicial != null) {
      body = ListView(
        controller: _scrollController,
        children: [_mensaje(icono: Icons.error_outline, texto: _errorInicial!.message, mutedColor: mutedColor)],
      );
    } else if (_items.isEmpty) {
      body = ListView(
        controller: _scrollController,
        children: [_mensaje(icono: Icons.notifications_none, texto: 'No tienes notificaciones', mutedColor: mutedColor)],
      );
    } else {
      body = ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final n = _items[index];
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
    }

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
      body: RefreshIndicator(onRefresh: _cargarInicial, child: body),
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
