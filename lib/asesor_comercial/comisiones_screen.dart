import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../finanzas/comision.dart';
import '../finanzas/finanzas_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/notification_bell_button.dart';
import 'asesor_comercial_service.dart';
import 'comision_periodo_detail_screen.dart';
import 'comisiones_widgets.dart';

const _accentYellow = AppColors.accent;

enum _Seccion { proyeccion, historial }

/// "Comisiones" tab, split in two sections:
/// - Proyección (default): `finanzas-service`'s `GET
///   /comisiones-periodo/proyeccion?asesorId=` — commissions calculated on
///   the fly for pedidos no real corte has processed yet. Deliberately
///   labeled as a projection everywhere, so it can't be mistaken for money
///   already authorized.
/// - Historial: `GET /comisiones-periodo?asesorId=` — cortes already
///   processed, newest first, tapping into their detalle.
/// Read-only: opening, generating, authorizing, adjusting or paying out a
/// period are administrative actions not exposed in this app.
class ComisionesScreen extends StatefulWidget {
  const ComisionesScreen({super.key});

  @override
  State<ComisionesScreen> createState() => _ComisionesScreenState();
}

class _ComisionesScreenState extends State<ComisionesScreen> {
  _Seccion _seccion = _Seccion.proyeccion;
  late Future<List<ComisionProyectada>> _proyeccionFuture;
  late Future<List<ComisionPeriodo>> _historialFuture;

  @override
  void initState() {
    super.initState();
    _proyeccionFuture = _cargarProyeccion();
    _historialFuture = _cargarHistorial();
  }

  Future<int> _asesorId() async {
    final asesor = await AsesorComercialService.miAsesor();
    if (asesor == null) {
      throw AuthException('No se encontró un asesor comercial vinculado a esta cuenta');
    }
    return asesor.id;
  }

  Future<List<ComisionProyectada>> _cargarProyeccion() async {
    final items = await FinanzasService.proyeccionComision(asesorId: await _asesorId());
    // Newest pedido first; undated ones last.
    items.sort((a, b) {
      final fa = a.fechaPedido, fb = b.fechaPedido;
      if (fa == null || fb == null) {
        return fa == null ? (fb == null ? 0 : 1) : -1;
      }
      return fb.compareTo(fa);
    });
    return items;
  }

  Future<List<ComisionPeriodo>> _cargarHistorial() async {
    final periodos = await FinanzasService.periodosComision(asesorId: await _asesorId());
    // Newest cut first; string compare is fine for ISO yyyy-MM-dd.
    periodos.sort((a, b) => (b.fechaInicio ?? '').compareTo(a.fechaInicio ?? ''));
    return periodos;
  }

  void _refresh() => setState(() {
    if (_seccion == _Seccion.proyeccion) {
      _proyeccionFuture = _cargarProyeccion();
    } else {
      _historialFuture = _cargarHistorial();
    }
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final fillColor = AppColors.border(context, alpha: 0.06);

    Widget seccionChip(_Seccion seccion, String label) {
      final selected = seccion == _seccion;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _seccion = seccion),
        selectedColor: _accentYellow,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, color: selected ? Colors.black : textColor),
        backgroundColor: fillColor,
        side: BorderSide.none,
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, BottomNavBar.clearance(context) + 16),
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _accentYellow.withValues(alpha: 0.18)),
                child: const Icon(Icons.account_balance_wallet_outlined, color: _accentYellow),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mis comisiones',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor),
                    ),
                    Text('Proyección y cortes procesados', style: TextStyle(fontSize: 13, color: mutedColor)),
                  ],
                ),
              ),
              const NotificationBellButton(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              seccionChip(_Seccion.proyeccion, 'Proyección'),
              const SizedBox(width: 8),
              seccionChip(_Seccion.historial, 'Historial'),
            ],
          ),
          const SizedBox(height: 16),
          if (_seccion == _Seccion.proyeccion)
            ProyeccionSection(future: _proyeccionFuture, onRetry: _refresh)
          else
            HistorialSection(
              future: _historialFuture,
              onRetry: _refresh,
              onPeriodoTap: (periodo) => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (context) => ComisionPeriodoDetailScreen(periodo: periodo))),
            ),
        ],
      ),
    );
  }
}
