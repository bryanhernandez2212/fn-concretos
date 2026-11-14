import 'package:flutter/material.dart';
import '../../catalogo/planta.dart';
import '../../theme/app_colors.dart';
import '../../widgets/info_pill.dart';
import '../jefe_planta_service.dart';
import '../jefe_planta_widgets.dart';

/// Tones from the web's `estatusOperativo` catalog.
Color colorEstatusOperativo(String estatus) => switch (estatus) {
  estatusOperativoOperando => AppColors.success,
  estatusOperativoAccidentada => AppColors.error,
  _ => AppColors.warning,
};

/// An olla en ruta can't change planta mid-trip.
bool puedeMoverse(OllaPlanta o) => !o.enRuta;

/// Count tile in the Ollas summary row.
class ResumenFlotaTile extends StatelessWidget {
  final String label;
  final int valor;
  final Color color;

  const ResumenFlotaTile({
    super.key,
    required this.label,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$valor',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.mutedText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One olla in the Ollas tab, with its "Mover" action.
class OllaCard extends StatelessWidget {
  final OllaPlanta olla;
  final String plantaNombre;
  final String? operadorNombre;
  final VoidCallback? onMover;

  /// Opens the map centered on this olla.
  final VoidCallback onUbicacion;

  const OllaCard({
    super.key,
    required this.olla,
    required this.plantaNombre,
    this.operadorNombre,
    required this.onMover,
    required this.onUbicacion,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final estatusColor = colorEstatusOperativo(olla.estatusOperativo);
    final movible = puedeMoverse(olla);
    final botonSecundario = OutlinedButton.styleFrom(
      foregroundColor: textColor,
      side: BorderSide(color: AppColors.border(context, alpha: 0.15)),
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: estatusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.local_shipping_outlined, color: estatusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      olla.numeroUnidad,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    Text(
                      plantaNombre,
                      style: TextStyle(fontSize: 12.5, color: mutedColor),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  EstatusPill(
                    label: etiquetaEstatusOperativo(olla.estatusOperativo),
                    color: estatusColor,
                  ),
                  if (olla.enRuta) ...[
                    const SizedBox(height: 4),
                    const EstatusPill(
                      label: 'En ruta',
                      color: AppColors.accent,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (olla.placas != null)
                InfoPill(
                  icon: Icons.pin_outlined,
                  text: olla.placas!,
                  mutedColor: mutedColor,
                  textColor: textColor,
                ),
              InfoPill(
                icon: Icons.water_drop_outlined,
                text: m3(olla.capacidadM3),
                mutedColor: mutedColor,
                textColor: textColor,
              ),
              InfoPill(
                icon: Icons.person_outline,
                text: olla.conductorAsignadoId == null
                    ? 'Sin operador'
                    : operadorNombre ?? 'Operador #${olla.conductorAsignadoId}',
                mutedColor: mutedColor,
                textColor: textColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onUbicacion,
                  icon: Icon(Icons.gps_fixed, color: AppColors.accentFg(context)),
                  label: const Text('Ubicación'),
                  style: botonSecundario,
                ),
              ),
              if (onMover != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: movible ? onMover : null,
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(movible ? 'Mover de planta' : 'En ruta'),
                    style: botonSecundario,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to pick the destination planta for an olla. Pops the
/// chosen [Planta], or null if dismissed.
class MoverOllaSheet extends StatefulWidget {
  final OllaPlanta olla;
  final List<Planta> plantas;

  const MoverOllaSheet({super.key, required this.olla, required this.plantas});

  @override
  State<MoverOllaSheet> createState() => _MoverOllaSheetState();
}

class _MoverOllaSheetState extends State<MoverOllaSheet> {
  Planta? _destino;

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final destinos = widget.plantas
        .where((p) => p.id != widget.olla.plantaAsignadaId)
        .toList();
    final origen = widget.plantas
        .where((p) => p.id == widget.olla.plantaAsignadaId)
        .firstOrNull;

    // The planta list scrolls on its own; header and button stay put.
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetHeader(
                title: 'Mover ${widget.olla.numeroUnidad}',
                subtitle:
                    'Actualmente en ${origen?.nombre ?? '#${widget.olla.plantaAsignadaId}'}',
              ),
              const SizedBox(height: 16),
              Text(
                'Planta destino',
                style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final p in destinos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: _destino?.id == p.id
                              ? AppColors.accent.withValues(alpha: 0.12)
                              : AppColors.card(context),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => _destino = p),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _destino?.id == p.id
                                      ? AppColors.accent
                                      : AppColors.border(context),
                                  width: _destino?.id == p.id ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.factory_outlined,
                                    color: _destino?.id == p.id
                                        ? AppColors.accent
                                        : mutedColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.nombre,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: textColor,
                                          ),
                                        ),
                                        if (p.tipoPlantaNombre != null)
                                          Text(
                                            p.tipoPlantaNombre!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: mutedColor,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (_destino?.id == p.id)
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppColors.accent,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _destino == null
                      ? null
                      : () => Navigator.of(context).pop(_destino),
                  // The default disabled grey nearly vanishes on the dark sheet.
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    disabledBackgroundColor: AppColors.border(
                      context,
                      alpha: 0.12,
                    ),
                    disabledForegroundColor: textColor.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _destino == null
                        ? 'Elige una planta'
                        : 'Mover a ${_destino!.nombre}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
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
