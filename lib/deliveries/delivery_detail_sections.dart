import 'package:flutter/material.dart';
import '../operaciones/evidencia.dart';
import '../operaciones/remision_tracking.dart';
import '../theme/app_colors.dart';
import '../widgets/field_group.dart';
import 'delivery_detail_widgets.dart';
import 'remision.dart';

/// The 7-step sequential progression, excluding [HitoEntrega.conIncidencia]
/// (an exception state, not a step to render in a linear stepper).
const secuenciaHitos = [
  HitoEntrega.cargandoPlanta,
  HitoEntrega.salioPlanta,
  HitoEntrega.enCamino,
  HitoEntrega.proximoLlegar,
  HitoEntrega.enObra,
  HitoEntrega.descargando,
  HitoEntrega.entregado,
];

const _accentYellow = AppColors.accent;

/// Bold section heading used between `DeliveryDetailScreen`'s sections
/// ("Ubicación y ruta", "Avanzar hito de entrega", "Evidencia de entrega").
class DeliverySectionTitle extends StatelessWidget {
  final String title;
  final Color textColor;

  const DeliverySectionTitle({super.key, required this.title, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
    );
  }
}

/// "Ubicación y ruta" section: the entry point into `RouteNavigationScreen`.
/// Whether it shows at all is decided by the caller (`_puedeIniciarRuta`).
class RouteSection extends StatelessWidget {
  /// Once the truck has already left planta at least once, the button reads
  /// "Regresar a la ruta" instead of "Iniciar ruta".
  final bool yaInicio;
  final Color textColor;
  final VoidCallback onPressed;

  const RouteSection({super.key, required this.yaInicio, required this.textColor, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DeliverySectionTitle(title: 'Ubicación y ruta', textColor: textColor),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(
              Icons.navigation,
              color: Colors.black,
            ),
            label: Text(
              yaInicio ? 'Regresar a la ruta' : 'Iniciar ruta',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentYellow,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Body of the "Avanzar hito de entrega" section once the Remisión detail has
/// loaded: horarios card plus either the linear [secuenciaHitos] stepper with
/// its "Avanzar a ..." button, or — for an unrecognized estatus — just the raw
/// status text.
class HitoStepperSection extends StatelessWidget {
  final RemisionResumen detalle;
  final bool avanzando;
  final ValueChanged<HitoEntrega> onAvanzar;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const HitoStepperSection({
    super.key,
    required this.detalle,
    required this.avanzando,
    required this.onAvanzar,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final horarios = <(String, DateTime?)>[
      ('Cargó en planta', detalle.horaCarga),
      ('Salida de planta', detalle.horaSalida),
      ('Llegada a obra', detalle.horaLlegadaObra),
      ('Entrega', detalle.horaEntrega),
    ].where((h) => h.$2 != null).toList();

    // A blank estatus resolves to `cargandoPlanta` (see
    // `HitoEntrega.fromBackendValue`) — null here only means
    // a genuinely unrecognized status (`con_atraso`, etc).
    final current = HitoEntrega.fromBackendValue(
      detalle.estatus,
    );
    if (current == null) {
      debugPrint(
        'DeliveryDetailScreen: unrecognized estatus="${detalle.estatus}"',
      );
      // con_atraso / con_incidencia / anything else unrecognized:
      // no known "next" step, so show the raw status instead of
      // a stepper we can't meaningfully advance.
      return Column(
        children: [
          if (horarios.isNotEmpty) ...[
            HorariosCard(
              horarios: horarios,
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
            const SizedBox(height: 12),
          ],
          FieldGroup(
            cardColor: cardColor,
            borderColor: borderColor,
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                detalle.estatus,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final isFinal = current == HitoEntrega.entregado;
    final currentIndex = secuenciaHitos.indexOf(current);

    return Column(
      children: [
        if (horarios.isNotEmpty) ...[
          HorariosCard(
            horarios: horarios,
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 12),
        ],
        FieldGroup(
          cardColor: cardColor,
          borderColor: borderColor,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final hito in secuenciaHitos)
                HitoRow(
                  hito: hito,
                  current: current,
                  isLast: hito == secuenciaHitos.last,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isFinal || avanzando
                ? null
                : () => onAvanzar(
                    secuenciaHitos[currentIndex + 1],
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentYellow,
              foregroundColor: Colors.black,
              disabledBackgroundColor: _accentYellow.withValues(
                alpha: 0.3,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: avanzando
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    isFinal
                        ? 'Entrega finalizada'
                        : 'Avanzar a "${secuenciaHitos[currentIndex + 1].label}"',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// "Firma digital de entrega" row. [firma] is the most recent firma on file
/// (null if none yet), which flips the row into a "Firmada" status pill;
/// what tapping does in each case is up to [onTap].
class FirmaActionRow extends StatelessWidget {
  final FirmaResponse? firma;
  final bool habilitado;
  final VoidCallback onTap;
  final Color textColor;
  final Color mutedColor;

  const FirmaActionRow({
    super.key,
    required this.firma,
    required this.habilitado,
    required this.onTap,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return ActionRow(
      icon: Icons.draw_outlined,
      label: 'Firma digital de entrega',
      textColor: textColor,
      mutedColor: mutedColor,
      enabled: habilitado,
      statusLabel: firma != null ? 'Firmada' : null,
      statusColor: firma != null ? AppColors.success : null,
      onTap: onTap,
    );
  }
}

/// "Foto / evidencia de entrega" row. [archivos] is already narrowed to
/// `foto_evidencia` entries; a non-empty list shows an "N fotos" status pill.
class EvidenciaActionRow extends StatelessWidget {
  final List<ArchivoResponse> archivos;
  final bool habilitado;
  final VoidCallback onTap;
  final Color textColor;
  final Color mutedColor;

  const EvidenciaActionRow({
    super.key,
    required this.archivos,
    required this.habilitado,
    required this.onTap,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return ActionRow(
      icon: Icons.photo_camera_outlined,
      label: 'Foto / evidencia de entrega',
      textColor: textColor,
      mutedColor: mutedColor,
      enabled: habilitado,
      statusLabel: archivos.isNotEmpty ? (archivos.length == 1 ? '1 foto' : '${archivos.length} fotos') : null,
      statusColor: archivos.isNotEmpty ? AppColors.success : null,
      onTap: onTap,
    );
  }
}

/// Operador de Bomba-only rows at the bottom of "Evidencia de entrega":
/// dosificación always, prueba de concreto fresco only when [mostrarPrueba]
/// (a Remisión exists and the session can operate on it). Each row is
/// preceded by its own divider.
class OperadorBombaRows extends StatelessWidget {
  final bool mostrarPrueba;
  final VoidCallback onDosificacion;
  final VoidCallback onPruebaConcreto;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const OperadorBombaRows({
    super.key,
    required this.mostrarPrueba,
    required this.onDosificacion,
    required this.onPruebaConcreto,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(height: 1, color: borderColor),
        ActionRow(
          icon: Icons.water_drop_outlined,
          label: 'Reporte de dosificación',
          textColor: textColor,
          mutedColor: mutedColor,
          onTap: onDosificacion,
        ),
        if (mostrarPrueba) ...[
          Divider(height: 1, color: borderColor),
          ActionRow(
            icon: Icons.science_outlined,
            label: 'Prueba de concreto fresco',
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: onPruebaConcreto,
          ),
        ],
      ],
    );
  }
}
