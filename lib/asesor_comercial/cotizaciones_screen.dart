import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/header_icon_button.dart';
import '../widgets/notification_bell_button.dart';
import 'asesor_comercial_service.dart';
import 'asesor_comercial_widgets.dart';
import 'cotizacion.dart';
import 'cotizacion_detail_screen.dart';
import 'cotizacion_form_screen.dart';

const _accentYellow = AppColors.accent;

const _filtros = <String?>[null, 'negociacion', 'listo', 'convertida', 'cancelada'];

String _filtroLabel(String? estatus) => estatus == null ? 'Todas' : estatusLabel(estatus);

/// "Cotizaciones" tab. Most cotizaciones originate from a Visita (see
/// `VisitaDetailScreen`), but the web app also allows creating one
/// standalone — the "+" here opens `CotizacionFormScreen` with no
/// cliente/obra prefilled, so it picks them itself.
class CotizacionesScreen extends StatefulWidget {
  const CotizacionesScreen({super.key});

  @override
  State<CotizacionesScreen> createState() => _CotizacionesScreenState();
}

class _CotizacionesScreenState extends State<CotizacionesScreen> {
  String? _filtro;
  late Future<List<Cotizacion>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargar(_filtro);
  }

  Future<List<Cotizacion>> _cargar(String? estatus) async {
    final asesor = await AsesorComercialService.miAsesor();
    if (asesor == null) {
      throw AuthException('No se encontró un asesor comercial vinculado a esta cuenta');
    }
    return AsesorComercialService.misCotizaciones(asesorId: asesor.id, estatus: estatus);
  }

  void _seleccionarFiltro(String? estatus) {
    setState(() {
      _filtro = estatus;
      _future = _cargar(estatus);
    });
  }

  void _refresh() => _seleccionarFiltro(_filtro);

  Future<void> _nuevaCotizacion() async {
    final creada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const CotizacionFormScreen()),
    );
    if (creada == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.08);
    final fillColor = AppColors.border(context, alpha: 0.06);

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
                child: const Icon(Icons.receipt_long_outlined, color: _accentYellow),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cotizaciones', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
                    Text('Tus cotizaciones activas', style: TextStyle(fontSize: 13, color: mutedColor)),
                  ],
                ),
              ),
              HeaderIconButton(
                icon: Icons.add_circle_outline,
                tooltip: 'Nueva cotización',
                onPressed: _nuevaCotizacion,
              ),
              const SizedBox(width: 8),
              const NotificationBellButton(),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filtros.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final estatus = _filtros[index];
                final selected = estatus == _filtro;
                return ChoiceChip(
                  label: Text(_filtroLabel(estatus)),
                  selected: selected,
                  onSelected: (_) => _seleccionarFiltro(estatus),
                  selectedColor: _accentYellow,
                  labelStyle: TextStyle(fontWeight: FontWeight.w600, color: selected ? Colors.black : textColor),
                  backgroundColor: fillColor,
                  side: BorderSide.none,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Cotizacion>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return ErrorState(
                  message: snapshot.error is AuthException
                      ? (snapshot.error as AuthException).message
                      : 'No se pudo cargar las cotizaciones',
                  onRetry: _refresh,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  mutedColor: mutedColor,
                );
              }

              final cotizaciones = snapshot.data!;
              if (cotizaciones.isEmpty) {
                return EmptyState(
                  message: 'No tienes cotizaciones en este estatus',
                  icon: Icons.receipt_long_outlined,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  mutedColor: mutedColor,
                );
              }

              return Column(
                children: [
                  for (final cotizacion in cotizaciones) ...[
                    CotizacionCard(
                      cotizacion: cotizacion,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      onTap: () async {
                        final refrescar = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (context) => CotizacionDetailScreen(cotizacion: cotizacion)),
                        );
                        if (refrescar == true) _refresh();
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
