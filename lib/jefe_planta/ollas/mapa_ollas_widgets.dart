import 'package:flutter/material.dart';
import '../../operaciones/rastreo_gps.dart';
import '../../theme/app_colors.dart';
import '../../widgets/info_pill.dart';
import '../jefe_planta_service.dart';
import '../jefe_planta_widgets.dart';
import 'ollas_widgets.dart';

/// Marker color: the Ollas tab's tones, or grey when the last fix is stale.
Color colorMarcadorOlla(OllaPlanta olla, UbicacionOlla ubicacion) {
  if (!ubicacion.reciente) return AppColors.neutral;
  if (olla.enRuta) return AppColors.accent;
  return colorEstatusOperativo(olla.estatusOperativo);
}

String haceCuanto(DateTime? fecha) {
  if (fecha == null) return 'Sin hora de captura';
  final d = DateTime.now().difference(fecha);
  if (d.inMinutes < 1) return 'Hace un momento';
  if (d.inMinutes < 60) return 'Hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'Hace ${d.inHours} h';
  return d.inDays == 1 ? 'Hace 1 día' : 'Hace ${d.inDays} días';
}

/// Bottom card for the olla tapped on the map.
class UbicacionOllaCard extends StatelessWidget {
  final OllaPlanta olla;
  final UbicacionOlla ubicacion;
  final String plantaNombre;

  /// Null hides the close button.
  final VoidCallback? onCerrar;

  const UbicacionOllaCard({
    super.key,
    required this.olla,
    required this.ubicacion,
    required this.plantaNombre,
    this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final color = colorMarcadorOlla(olla, ubicacion);
    final origen = OrigenGpsInfo.parse(ubicacion.origenGps);
    final velocidad = ubicacion.velocidad;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_shipping_outlined, color: color),
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
              EstatusPill(
                label: olla.enRuta
                    ? 'En ruta'
                    : etiquetaEstatusOperativo(olla.estatusOperativo),
                color: olla.enRuta
                    ? AppColors.accent
                    : colorEstatusOperativo(olla.estatusOperativo),
              ),
              if (onCerrar != null)
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: onCerrar,
                  icon: Icon(Icons.close, color: mutedColor),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_outlined, size: 18, color: mutedColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ubicacion.ubicacionTexto ??
                        '${ubicacion.latitud.toStringAsFixed(5)}, ${ubicacion.longitud.toStringAsFixed(5)}',
                    style: TextStyle(fontSize: 13.5, color: textColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoPill(
                icon: ubicacion.reciente
                    ? Icons.schedule
                    : Icons.signal_cellular_connected_no_internet_0_bar,
                text: ubicacion.reciente
                    ? haceCuanto(ubicacion.capturadaEn)
                    : 'Sin señal reciente · ${haceCuanto(ubicacion.capturadaEn).toLowerCase()}',
                mutedColor: mutedColor,
                textColor: textColor,
              ),
              InfoPill(
                icon: origen.icon,
                text: origen.etiqueta,
                mutedColor: mutedColor,
                textColor: textColor,
              ),
              if (velocidad != null && ubicacion.reciente)
                InfoPill(
                  icon: Icons.speed,
                  text: '${velocidad.round()} km/h',
                  mutedColor: mutedColor,
                  textColor: textColor,
                ),
              if (olla.placas != null)
                InfoPill(
                  icon: Icons.pin_outlined,
                  text: olla.placas!,
                  mutedColor: mutedColor,
                  textColor: textColor,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom card when nothing is selected: counts plus a hint.
class ResumenMapaOllasCard extends StatelessWidget {
  final int conUbicacion;
  final int sinSenalReciente;
  final int sinUbicacion;

  const ResumenMapaOllasCard({
    super.key,
    required this.conUbicacion,
    required this.sinSenalReciente,
    required this.sinUbicacion,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conUbicacion == 1
                ? '1 olla en el mapa'
                : '$conUbicacion ollas en el mapa',
            style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (sinSenalReciente > 0)
                '$sinSenalReciente sin señal reciente (en gris)',
              if (sinUbicacion > 0) '$sinUbicacion sin ubicación',
              'Toca una olla para ver su detalle.',
            ].join(' · '),
            style: TextStyle(fontSize: 12.5, color: mutedColor),
          ),
        ],
      ),
    );
  }
}
