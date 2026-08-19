import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/auth_service.dart';
import '../theme/app_colors.dart';
import 'deliveries_widgets.dart' show RemisionCard;
import 'entregas_service.dart';
import 'delivery_detail_screen.dart';
import 'remision.dart';

const _accentYellow = AppColors.accent;

/// "Historial de entregas" — same list/card as `DeliveriesScreen`, but for a
/// past date the conductor picks instead of always today. Reuses
/// `EntregasService.entregasDelDia(fecha: ...)`, which already accepts an
/// arbitrary date — `programacion-produccion` is plant-wide per day, so this
/// is the same filter-by-`idEmpleado` logic, just pointed at another day.
class HistorialEntregasScreen extends StatefulWidget {
  const HistorialEntregasScreen({super.key});

  @override
  State<HistorialEntregasScreen> createState() => _HistorialEntregasScreenState();
}

class _HistorialEntregasScreenState extends State<HistorialEntregasScreen> {
  late final DateTime _hoy;
  late final DateTime _primeraFecha;
  late DateTime _fecha;
  late Future<List<Remision>> _future;

  @override
  void initState() {
    super.initState();
    _hoy = DateTime.now();
    _primeraFecha = _hoy.subtract(const Duration(days: 90));
    _fecha = _diaAnterior(_hoy);
    _future = EntregasService.entregasDelDia(fecha: _fecha);
  }

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _diaAnterior(DateTime d) => _soloFecha(d.subtract(const Duration(days: 1)));

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
      firstDate: _primeraFecha,
      lastDate: _hoy,
      locale: const Locale('es'),
      builder: (context, child) {
        final base = Theme.of(context);
        return Theme(
          data: base.copyWith(
            colorScheme: base.colorScheme.copyWith(primary: _accentYellow, onPrimary: Colors.black),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    final fechaLabel = _capitalizada(DateFormat("EEEE d 'de' MMMM 'de' y", 'es').format(_fecha));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de entregas'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                          child: const Icon(Icons.calendar_month_outlined, size: 20, color: _accentYellow),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fechaLabel,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
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
              ],
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
                          Icon(Icons.error_outline, size: 40, color: mutedColor),
                          const SizedBox(height: 12),
                          Text(
                            snapshot.error is AuthException
                                ? (snapshot.error as AuthException).message
                                : 'No se pudo cargar el historial',
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
                          Icon(Icons.event_busy_outlined, size: 40, color: mutedColor),
                          const SizedBox(height: 12),
                          Text(
                            'No tuviste entregas asignadas ese día',
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
                            MaterialPageRoute(builder: (context) => DeliveryDetailScreen(remision: remision)),
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

String _capitalizada(String texto) => texto.isEmpty ? texto : '${texto[0].toUpperCase()}${texto.substring(1)}';
