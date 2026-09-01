import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/field_group.dart';
import '../widgets/notification_bell_button.dart';
import 'asesor_comercial_service.dart';
import 'asesor_comercial_widgets.dart';
import 'visita.dart';
import 'visita_detail_screen.dart';

const _accentYellow = AppColors.accent;

class _VisitasData {
  final int asesorId;
  final List<Visita> visitas;
  final ResumenVisitas resumen;

  const _VisitasData({required this.asesorId, required this.visitas, required this.resumen});
}

/// "Visitas" tab — the advisor's visits for a picked date (defaults to
/// today), same date-pill + `FutureBuilder` pattern as
/// `deliveries/HistorialEntregasScreen`.
class VisitasScreen extends StatefulWidget {
  const VisitasScreen({super.key});

  @override
  State<VisitasScreen> createState() => _VisitasScreenState();
}

class _VisitasScreenState extends State<VisitasScreen> {
  late final DateTime _hoy;
  late final DateTime _primeraFecha;
  late DateTime _fecha;
  late Future<_VisitasData> _future;

  @override
  void initState() {
    super.initState();
    _hoy = DateTime.now();
    _primeraFecha = _hoy.subtract(const Duration(days: 90));
    _fecha = DateTime(_hoy.year, _hoy.month, _hoy.day);
    _future = _cargar(_fecha);
  }

  Future<_VisitasData> _cargar(DateTime fecha) async {
    final asesor = await AsesorComercialService.miAsesor();
    if (asesor == null) {
      throw AuthException('No se encontró un asesor comercial vinculado a esta cuenta');
    }
    final visitas = await AsesorComercialService.visitasDelDia(asesorId: asesor.id, fecha: fecha);
    final resumen = await AsesorComercialService.resumenVisitasDelDia(asesorId: asesor.id, fecha: fecha);
    return _VisitasData(asesorId: asesor.id, visitas: visitas, resumen: resumen);
  }

  void _seleccionar(DateTime fecha) {
    setState(() {
      _fecha = fecha;
      _future = _cargar(fecha);
    });
  }

  void _refresh() => _seleccionar(_fecha);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: _primeraFecha,
      lastDate: _hoy,
      locale: const Locale('es'),
      builder: (context, child) {
        final base = Theme.of(context);
        return Theme(
          data: base.copyWith(colorScheme: base.colorScheme.copyWith(primary: _accentYellow, onPrimary: Colors.black)),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    _seleccionar(picked);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.08);
    final fechaLabel = _capitalizada(DateFormat("EEEE d 'de' MMMM 'de' y", 'es').format(_fecha));

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
                child: const Icon(Icons.place_outlined, color: _accentYellow),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Visitas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
                    Text('Visitas a obra programadas', style: TextStyle(fontSize: 13, color: mutedColor)),
                  ],
                ),
              ),
              const NotificationBellButton(),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _accentYellow.withValues(alpha: 0.18)),
                    child: const Icon(Icons.calendar_month_outlined, size: 20, color: _accentYellow),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fechaLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                        const SizedBox(height: 2),
                        Text('Toca para elegir otra fecha', style: TextStyle(fontSize: 12.5, color: mutedColor)),
                      ],
                    ),
                  ),
                  Icon(Icons.expand_more, color: mutedColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<_VisitasData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return ErrorState(
                  message: snapshot.error is AuthException ? (snapshot.error as AuthException).message : 'No se pudo cargar las visitas',
                  onRetry: _refresh,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  mutedColor: mutedColor,
                );
              }

              final data = snapshot.data!;
              final children = <Widget>[
                FieldGroup(
                  cardColor: cardColor,
                  borderColor: borderColor,
                  expand: true,
                  child: Row(
                    children: [
                      Icon(
                        data.resumen.cumpleMinimo ? Icons.check_circle_outline : Icons.info_outline,
                        color: data.resumen.cumpleMinimo ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${data.resumen.visitasRealizadas} de ${data.resumen.visitasMinimoRequerido} visitas mínimas realizadas',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ];

              if (data.visitas.isEmpty) {
                children.add(
                  EmptyState(
                    message: 'No tienes visitas programadas ese día',
                    icon: Icons.event_busy_outlined,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    mutedColor: mutedColor,
                  ),
                );
              } else {
                for (final visita in data.visitas) {
                  children.add(
                    VisitaCard(
                      visita: visita,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      onTap: () async {
                        final refrescar = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (context) => VisitaDetailScreen(visita: visita)),
                        );
                        if (refrescar == true) _refresh();
                      },
                    ),
                  );
                  children.add(const SizedBox(height: 12));
                }
              }

              return Column(children: children);
            },
          ),
        ],
      ),
    );
  }
}

String _capitalizada(String texto) => texto.isEmpty ? texto : '${texto[0].toUpperCase()}${texto.substring(1)}';
