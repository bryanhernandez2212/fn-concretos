import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import 'delivery_photo_screen.dart';
import 'dosificacion_screen.dart';
import 'remision.dart';
import 'route_navigation_screen.dart';
import 'signature_screen.dart';

const _accentYellow = Color(0xFFFFCC00);

/// Detail view for a single Remisión: summary, the 9-step hito stepper with
/// a button to advance it, and entry points to firma digital / foto de
/// evidencia (still stubs — built as their own views next).
class DeliveryDetailScreen extends StatefulWidget {
  final Remision remision;

  const DeliveryDetailScreen({super.key, required this.remision});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  late HitoEntrega _current = widget.remision.hitoActual;

  void _avanzarHito() {
    final nextIndex = _current.index + 1;
    if (nextIndex >= HitoEntrega.values.length) return;
    setState(() => _current = HitoEntrega.values[nextIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remision = widget.remision;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.12);
    final isFinal = _current.index == HitoEntrega.values.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(remision.folio),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : _accentYellow,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _SummaryCard(remision: remision, cardColor: cardColor, borderColor: borderColor, textColor: textColor, mutedColor: mutedColor),
          const SizedBox(height: 24),
          Text('Ubicación y ruta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => RouteNavigationScreen(remision: remision)),
                );
              },
              icon: const Icon(Icons.navigation, color: Colors.black),
              label: const Text('Iniciar ruta', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentYellow,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('Avanzar hito de entrega', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 14),
          _FieldGroup(
            cardColor: cardColor,
            borderColor: borderColor,
            child: Column(
              children: [
                for (final hito in HitoEntrega.values)
                  _HitoRow(
                    hito: hito,
                    current: _current,
                    isLast: hito == HitoEntrega.values.last,
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
              onPressed: isFinal ? null : _avanzarHito,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentYellow,
                foregroundColor: Colors.black,
                disabledBackgroundColor: _accentYellow.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                isFinal ? 'Entrega finalizada' : 'Avanzar a "${HitoEntrega.values[_current.index + 1].label}"',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('Evidencia de entrega', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 14),
          _FieldGroup(
            cardColor: cardColor,
            borderColor: borderColor,
            child: Column(
              children: [
                _ActionRow(
                  icon: Icons.draw_outlined,
                  label: 'Firma digital de entrega',
                  textColor: textColor,
                  mutedColor: mutedColor,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => SignatureScreen(remisionFolio: remision.folio)),
                    );
                  },
                ),
                Divider(height: 1, color: borderColor),
                _ActionRow(
                  icon: Icons.photo_camera_outlined,
                  label: 'Foto / evidencia de entrega',
                  textColor: textColor,
                  mutedColor: mutedColor,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => DeliveryPhotoScreen(remisionFolio: remision.folio)),
                    );
                  },
                ),
                if (AuthService.rol == 'Operador de Bomba') ...[
                  Divider(height: 1, color: borderColor),
                  _ActionRow(
                    icon: Icons.water_drop_outlined,
                    label: 'Reporte de dosificación',
                    textColor: textColor,
                    mutedColor: mutedColor,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => DosificacionScreen(remisionFolio: remision.folio)),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Remision remision;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const _SummaryCard({
    required this.remision,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(remision.obra, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 2),
          Text(remision.cliente, style: TextStyle(fontSize: 13.5, color: mutedColor)),
          const SizedBox(height: 14),
          _DetailLine(icon: Icons.location_on_outlined, text: remision.direccion, textColor: textColor, mutedColor: mutedColor),
          const SizedBox(height: 8),
          _DetailLine(icon: Icons.access_time, text: 'Programada: ${remision.horaProgramada}', textColor: textColor, mutedColor: mutedColor),
          const SizedBox(height: 8),
          _DetailLine(icon: Icons.grain, text: '${remision.tipoConcreto} · ${remision.volumenM3} m³', textColor: textColor, mutedColor: mutedColor),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color textColor;
  final Color mutedColor;

  const _DetailLine({required this.icon, required this.text, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: mutedColor),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, color: textColor))),
      ],
    );
  }
}

/// Rounded card wrapper matching the style used across the rest of the app.
class _FieldGroup extends StatelessWidget {
  final Color cardColor;
  final Color borderColor;
  final Widget child;

  const _FieldGroup({required this.cardColor, required this.borderColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

/// One row of the hito stepper: a filled/checked circle for done steps, a
/// highlighted circle for the current one, an outlined circle for what's
/// ahead, connected by a vertical line.
class _HitoRow extends StatelessWidget {
  final HitoEntrega hito;
  final HitoEntrega current;
  final bool isLast;
  final Color textColor;
  final Color mutedColor;

  const _HitoRow({
    required this.hito,
    required this.current,
    required this.isLast,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = hito.index < current.index;
    final isCurrent = hito.index == current.index;
    final circleColor = isDone
        ? const Color(0xFF4CAF50)
        : isCurrent
            ? _accentYellow
            : mutedColor.withValues(alpha: 0.3);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone || isCurrent ? circleColor : Colors.transparent,
                  border: Border.all(color: circleColor, width: 2),
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.black)
                    : null,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 28,
                  color: mutedColor.withValues(alpha: 0.2),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                hito.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrent || isDone ? textColor : mutedColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: _accentYellow),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: textColor)),
              ),
              Icon(Icons.chevron_right, color: mutedColor),
            ],
          ),
        ),
      ),
    );
  }
}
