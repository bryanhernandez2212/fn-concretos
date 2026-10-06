import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../widgets/notification_bell_button.dart';

final monedaJp = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

String fechaCortaJp(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String m3(double? v) => v == null
    ? '—'
    : '${v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} m³';

/// Top row shared by every Jefe de Planta tab: round accent icon, title +
/// subtitle, optional action, then the notification bell (action goes
/// before the bell, per the app-wide header convention).
class JefePlantaTabHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const JefePlantaTabHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: 0.18),
          ),
          child: Icon(icon, color: AppColors.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text(context),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedText(context),
                ),
              ),
            ],
          ),
        ),
        if (action != null) ...[action!, const SizedBox(width: 8)],
        const NotificationBellButton(),
      ],
    );
  }
}

/// Visible marker that a screen is still running on mock data, so nobody
/// mistakes the design's sample rows for real ones.
class DatosEjemploBanner extends StatelessWidget {
  const DatosEjemploBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.science_outlined,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Vista de diseño con datos de ejemplo',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.text(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Colored pill for an estatus label.
class EstatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const EstatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Empty / error placeholder card. Passing [onRetry] turns it into the
/// error variant.
class JefePlantaMensaje extends StatelessWidget {
  final IconData icon;
  final String mensaje;
  final VoidCallback? onRetry;

  const JefePlantaMensaje({
    super.key,
    required this.icon,
    required this.mensaje,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final mutedColor = AppColors.mutedText(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: onRetry != null ? AppColors.error : mutedColor,
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            mensaje,
            style: TextStyle(fontSize: 13.5, color: mutedColor),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ],
      ),
    );
  }
}

class JefePlantaCargando extends StatelessWidget {
  const JefePlantaCargando({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 40),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// Horizontal filter chips (null value = "Todas").
class FiltroChips<T> extends StatelessWidget {
  final List<T?> valores;
  final T? seleccionado;
  final String Function(T?) etiqueta;
  final ValueChanged<T?> onSelected;

  const FiltroChips({
    super.key,
    required this.valores,
    required this.seleccionado,
    required this.etiqueta,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: valores.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final v = valores[index];
          final selected = v == seleccionado;
          return ChoiceChip(
            label: Text(etiqueta(v)),
            selected: selected,
            onSelected: (_) => onSelected(v),
            selectedColor: AppColors.accent,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.onAccent : textColor,
            ),
            backgroundColor: AppColors.border(context, alpha: 0.06),
            side: BorderSide.none,
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

/// Label/value row for detail cards.
class DatoRow extends StatelessWidget {
  final String label;
  final String value;

  const DatoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.mutedText(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.text(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small grabber + title used at the top of this feature's bottom sheets.
class SheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SheetHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border(context, alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.text(context),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 13, color: AppColors.mutedText(context)),
          ),
        ],
      ],
    );
  }
}

ButtonStyle botonPrimarioJp() => ElevatedButton.styleFrom(
  backgroundColor: AppColors.accent,
  foregroundColor: AppColors.onAccent,
  padding: const EdgeInsets.symmetric(vertical: 16),
  elevation: 0,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);

InputDecoration campoJp(
  BuildContext context,
  String label, {
  String? hint,
  Widget? prefixIcon,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
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
