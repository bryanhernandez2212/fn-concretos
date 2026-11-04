import 'package:flutter/material.dart';
import '../../operaciones/orden_trabajo_bombeo.dart';
import '../../operaciones/remision_tracking.dart';
import '../../theme/app_colors.dart';
import '../../widgets/field_group.dart';
import '../remision.dart';

/// Text field decoration shared by the abrir/cerrar turno forms.
InputDecoration campoTurno(
  BuildContext context,
  String label, {
  String? hint,
  String? suffix,
  Widget? prefixIcon,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  suffixText: suffix,
  prefixIcon: prefixIcon,
  labelStyle: TextStyle(color: AppColors.mutedText(context)),
  hintStyle: TextStyle(color: AppColors.mutedText(context, alpha: 0.4)),
  filled: true,
  fillColor: AppColors.border(context, alpha: 0.06),
  contentPadding: const EdgeInsets.all(16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide.none,
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
  ),
);

/// Validator for an optional, non-negative decimal field.
String? validarNumeroOpcional(String? v) {
  final t = (v ?? '').replaceAll(',', '.').trim();
  if (t.isEmpty) return null;
  final n = double.tryParse(t);
  return n == null || n < 0 ? 'Cantidad inválida' : null;
}

double? leerNumero(TextEditingController c) =>
    double.tryParse(c.text.replaceAll(',', '.').trim());

String? leerTexto(TextEditingController c) {
  final t = c.text.trim();
  return t.isEmpty ? null : t;
}

String _numero(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Shown when the operator has no open turno: what a turno is and the
/// "Abrir turno" button.
class SinTurnoCard extends StatelessWidget {
  final VoidCallback onAbrir;

  const SinTurnoCard({super.key, required this.onAbrir});

  @override
  Widget build(BuildContext context) {
    return FieldGroup(
      expand: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: AppColors.accent,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No tienes un turno abierto',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Abre tu turno de bombeo con el horómetro de inicio. Al terminar el día lo cierras con el horómetro final y el recibo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.mutedText(context),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAbrir,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'Abrir turno',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The open turno's summary. Rows the backend didn't fill are skipped.
class TurnoActivoCard extends StatelessWidget {
  final OrdenTrabajoBombeo turno;

  /// Remisiones linked to this turno, counted on the client — used when
  /// the backend doesn't send `totalRemisiones`.
  final int remisionesLigadas;

  const TurnoActivoCard({
    super.key,
    required this.turno,
    required this.remisionesLigadas,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final unidad = turno.vehiculoBombaNumeroUnidad;
    final filas = <(IconData, String, String)>[
      if (unidad != null && unidad.isNotEmpty)
        (Icons.local_shipping_outlined, 'Bomba', unidad)
      else if (turno.vehiculoBombaId != null)
        (Icons.local_shipping_outlined, 'Bomba', '#${turno.vehiculoBombaId}'),
      if (turno.fecha != null)
        (Icons.calendar_today_outlined, 'Fecha', turno.fecha!),
      if (turno.horometroInicio != null)
        (
          Icons.speed_outlined,
          'Horómetro inicio',
          _numero(turno.horometroInicio!),
        ),
      (
        Icons.receipt_long_outlined,
        'Remisiones',
        '${turno.totalRemisiones ?? remisionesLigadas}',
      ),
      if (turno.volumenPorCobrar != null)
        (
          Icons.water_drop_outlined,
          'Volumen por cobrar',
          '${_numero(turno.volumenPorCobrar!)} m³',
        ),
      if (turno.auxiliarNombre != null && turno.auxiliarNombre!.isNotEmpty)
        (Icons.person_outline, 'Auxiliar', turno.auxiliarNombre!),
      if (turno.clienteNombre != null && turno.clienteNombre!.isNotEmpty)
        (Icons.business_outlined, 'Cliente', turno.clienteNombre!),
      if (turno.direccionObra != null && turno.direccionObra!.isNotEmpty)
        (Icons.location_on_outlined, 'Obra', turno.direccionObra!),
      if (turno.entreCalles != null && turno.entreCalles!.isNotEmpty)
        (Icons.signpost_outlined, 'Entre calles', turno.entreCalles!),
      if (turno.telefono != null && turno.telefono!.isNotEmpty)
        (Icons.phone_outlined, 'Teléfono', turno.telefono!),
      if (turno.solicitadoPor != null && turno.solicitadoPor!.isNotEmpty)
        (Icons.assignment_ind_outlined, 'Solicitado por', turno.solicitadoPor!),
    ];

    return FieldGroup(
      expand: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  turno.folio.isEmpty ? 'Turno #${turno.id}' : turno.folio,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Abierto',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final (index, (icon, label, valor)) in filas.indexed) ...[
            if (index > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: mutedColor),
                const SizedBox(width: 8),
                SizedBox(
                  width: 128,
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 13.5, color: mutedColor),
                  ),
                ),
                Expanded(
                  child: Text(
                    valor,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (turno.observaciones != null &&
              turno.observaciones!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              turno.observaciones!,
              style: TextStyle(fontSize: 13, color: mutedColor),
            ),
          ],
        ],
      ),
    );
  }
}

/// One remisión linked to the turno: folio, hito and m³ bombeados.
class TurnoRemisionTile extends StatelessWidget {
  final RemisionResumen remision;
  final bool abriendo;
  final VoidCallback onTap;

  const TurnoRemisionTile({
    super.key,
    required this.remision,
    required this.abriendo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final hito = HitoEntrega.fromBackendValue(
      remision.estatus,
      soloBomba: remision.esSoloBomba,
    );
    final metros = remision.metrosBombeados;

    return InkWell(
      onTap: abriendo ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 20,
              color: AppColors.accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    remision.folioRemision.isEmpty
                        ? 'Remisión #${remision.id}'
                        : remision.folioRemision,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hito?.labelPara(soloBomba: remision.esSoloBomba) ??
                        (HitoEntrega.sinIniciar(
                              remision.estatus,
                              soloBomba: remision.esSoloBomba,
                            )
                            ? 'Programado'
                            : remision.estatus),
                    style: TextStyle(fontSize: 12.5, color: mutedColor),
                  ),
                ],
              ),
            ),
            Text(
              metros == null ? 'Sin m³' : '${_numero(metros)} m³',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: metros == null ? mutedColor : textColor,
              ),
            ),
            const SizedBox(width: 8),
            abriendo
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.chevron_right, color: mutedColor),
          ],
        ),
      ),
    );
  }
}
