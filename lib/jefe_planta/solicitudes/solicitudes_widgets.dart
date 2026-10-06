import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/info_pill.dart';
import '../jefe_planta_mock.dart';
import '../jefe_planta_widgets.dart';

Color colorEstatusSolicitud(String estatus) => switch (estatus) {
  estatusSolicitudAutorizada => AppColors.success,
  estatusSolicitudRechazada => AppColors.error,
  estatusSolicitudPendiente => AppColors.warning,
  _ => AppColors.accent,
};

IconData iconoArea(String area) => switch (area) {
  'Producción' => Icons.factory_outlined,
  'Mantenimiento' => Icons.build_outlined,
  'Flota' => Icons.local_shipping_outlined,
  'Laboratorio' => Icons.science_outlined,
  'Seguridad' => Icons.health_and_safety_outlined,
  _ => Icons.inventory_2_outlined,
};

/// One solicitud de compra in the Solicitudes tab.
class SolicitudCard extends StatelessWidget {
  final SolicitudCompra solicitud;
  final VoidCallback onTap;

  const SolicitudCard({
    super.key,
    required this.solicitud,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    return Material(
      color: AppColors.card(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(iconoArea(solicitud.area), size: 18, color: mutedColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      solicitud.area,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  EstatusPill(
                    label: etiquetaEstatusSolicitud(solicitud.estatus),
                    color: colorEstatusSolicitud(solicitud.estatus),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                solicitud.concepto,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              if (solicitud.montoEstimado != null) ...[
                const SizedBox(height: 4),
                Text(
                  monedaJp.format(solicitud.montoEstimado),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoPill(
                    icon: Icons.tag,
                    text: 'SC-${solicitud.id}',
                    mutedColor: mutedColor,
                    textColor: textColor,
                  ),
                  InfoPill(
                    icon: Icons.calendar_today_outlined,
                    text: fechaCortaJp(solicitud.createdAt),
                    mutedColor: mutedColor,
                    textColor: textColor,
                  ),
                  if (solicitud.cotizacionAdjuntaUrl != null)
                    InfoPill(
                      icon: Icons.attach_file,
                      text: 'Cotización',
                      mutedColor: mutedColor,
                      textColor: textColor,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bitácora timeline: one dot + line per entry, newest first.
class BitacoraTimeline extends StatelessWidget {
  final List<BitacoraSolicitud> pasos;

  const BitacoraTimeline({super.key, required this.pasos});

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final lineColor = AppColors.border(context, alpha: 0.15);
    return Column(
      children: [
        for (var i = 0; i < pasos.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == 0 ? AppColors.accent : lineColor,
                        ),
                      ),
                      if (i < pasos.length - 1)
                        Expanded(child: Container(width: 2, color: lineColor)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pasos[i].accion,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${pasos[i].usuario} · ${fechaCortaJp(pasos[i].fecha)} '
                          '${pasos[i].fecha.hour.toString().padLeft(2, '0')}:${pasos[i].fecha.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 12, color: mutedColor),
                        ),
                        if (pasos[i].comentario != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '“${pasos[i].comentario}”',
                            style: TextStyle(fontSize: 13, color: textColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
