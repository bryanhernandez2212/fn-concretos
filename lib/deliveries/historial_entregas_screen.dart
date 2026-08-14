import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import 'deliveries_screen.dart' show RemisionCard;
import 'entregas_service.dart';
import 'delivery_detail_screen.dart';
import 'remision.dart';

const _accentYellow = Color(0xFFFFCC00);

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
  late DateTime _fecha;
  late Future<List<Remision>> _future;

  @override
  void initState() {
    super.initState();
    _fecha = DateTime.now().subtract(const Duration(days: 1));
    _future = EntregasService.entregasDelDia(fecha: _fecha);
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: today.subtract(const Duration(days: 90)),
      lastDate: today,
    );
    if (picked == null) return;
    setState(() {
      _fecha = picked;
      _future = EntregasService.entregasDelDia(fecha: picked);
    });
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
    final fechaLabel =
        '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de entregas'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : _accentYellow,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 18, color: _accentYellow),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fechaLabel,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textColor),
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
                      child: Text(
                        snapshot.error is AuthException
                            ? (snapshot.error as AuthException).message
                            : 'No se pudo cargar el historial',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: mutedColor),
                      ),
                    ),
                  );
                }

                final entregas = snapshot.data!;
                if (entregas.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No tuviste entregas asignadas ese día',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: mutedColor),
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
