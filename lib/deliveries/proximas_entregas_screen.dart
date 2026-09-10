import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/auth_service.dart';
import '../theme/app_colors.dart';
import 'deliveries_widgets.dart' show RemisionCard;
import 'entregas_service.dart';
import 'delivery_detail_screen.dart';
import 'remision.dart';

const _accentYellow = AppColors.accent;

/// "Próximas entregas" — the forward-looking counterpart to
/// `HistorialEntregasScreen`: same date-picker + `EntregasService.entregasDelDia`
/// pattern, just picking from tomorrow onward instead of before today. Reached
/// from `DeliveriesScreen`'s dashboard when there's nothing assigned today,
/// so the conductor can check what's coming instead of just seeing an empty
/// screen. Same caveat as the historial screen and "Mis entregas del día"
/// itself applies here too: a day only shows up once planta/producción has
/// created a Remisión for it — a pedido merely programmed for a future date
/// with no Remisión yet won't appear (see `entregas_service.dart`).
class ProximasEntregasScreen extends StatefulWidget {
  const ProximasEntregasScreen({super.key});

  @override
  State<ProximasEntregasScreen> createState() => _ProximasEntregasScreenState();
}

class _ProximasEntregasScreenState extends State<ProximasEntregasScreen> {
  late final DateTime _manana;
  late final DateTime _ultimaFecha;
  late DateTime _fecha;
  late Future<List<Remision>> _future;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _manana = _diaSiguiente(hoy);
    _ultimaFecha = _manana.add(const Duration(days: 90));
    _fecha = _manana;
    _future = EntregasService.entregasDelDia(fecha: _fecha);
  }

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _diaSiguiente(DateTime d) =>
      _soloFecha(d.add(const Duration(days: 1)));

  void _seleccionar(DateTime fecha) {
    setState(() {
      _fecha = fecha;
      _future = EntregasService.entregasDelDia(fecha: fecha);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: _manana,
      lastDate: _ultimaFecha,
      locale: const Locale('es'),
      builder: (context, child) {
        final base = Theme.of(context);
        return Theme(
          data: base.copyWith(
            colorScheme: base.colorScheme.copyWith(
              primary: _accentYellow,
              onPrimary: Colors.black,
            ),
          ),
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

    final fechaLabel = _capitalizada(
      DateFormat("EEEE d 'de' MMMM 'de' y", 'es').format(_fecha),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Próximas entregas'),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accentYellow.withValues(alpha: 0.18),
                      ),
                      child: const Icon(
                        Icons.calendar_month_outlined,
                        size: 20,
                        color: _accentYellow,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fechaLabel,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Toca para elegir otra fecha',
                            style: TextStyle(fontSize: 12.5, color: mutedColor),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.expand_more, color: mutedColor),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Remision>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 40,
                            color: mutedColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            snapshot.error is AuthException
                                ? (snapshot.error as AuthException).message
                                : 'No se pudieron cargar las próximas entregas',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: mutedColor),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final entregas = snapshot.data!;
                if (entregas.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_busy_outlined,
                            size: 40,
                            color: mutedColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Aún no tienes entregas programadas ese día',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: mutedColor),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    for (final remision in entregas) ...[
                      RemisionCard(
                        remision: remision,
                        cardColor: cardColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        mutedColor: mutedColor,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  DeliveryDetailScreen(remision: remision),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _capitalizada(String texto) =>
    texto.isEmpty ? texto : '${texto[0].toUpperCase()}${texto.substring(1)}';
