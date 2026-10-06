import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

const _accentYellow = AppColors.accent;

/// One row of the "mi vehículo" details card: icon, label, value, with an
/// optional divider below (skipped on the last row).
class DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textColor;
  final Color mutedColor;
  final bool isLast;

  const DetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.textColor,
    required this.mutedColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: mutedColor, size: 18),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 13, color: mutedColor)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value.isEmpty ? '—' : value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: mutedColor.withValues(alpha: 0.15)),
      ],
    );
  }
}

/// A collapsible card grouping [DetailRow]s, e.g. "Identificación" or
/// "Equipamiento" on `VehicleScreen` — starts collapsed so the whole
/// vehículo fits on screen without scrolling; tapping the header toggles it.
/// [resumen] is a one-line preview shown in the header while collapsed.
class DetailSection extends StatefulWidget {
  final IconData icon;
  final String title;
  final String resumen;
  final List<DetailRow> rows;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final bool inicialmenteAbierta;

  const DetailSection({
    super.key,
    required this.icon,
    required this.title,
    required this.resumen,
    required this.rows,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
    this.inicialmenteAbierta = false,
  });

  @override
  State<DetailSection> createState() => _DetailSectionState();
}

class _DetailSectionState extends State<DetailSection> {
  late bool _abierta = widget.inicialmenteAbierta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _abierta ? _accentYellow.withValues(alpha: 0.5) : widget.borderColor,
            ),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => _abierta = !_abierta),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _accentYellow.withValues(alpha: 0.15),
                        ),
                        child: Icon(widget.icon, color: _accentYellow, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: widget.textColor),
                            ),
                            if (!_abierta && widget.resumen.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.resumen,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: widget.mutedColor),
                              ),
                            ],
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _abierta ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more, color: widget.mutedColor),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _abierta
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Column(
                          children: [
                            Divider(height: 1, color: widget.mutedColor.withValues(alpha: 0.15)),
                            ...widget.rows,
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? badgeColor;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback? onTap;

  const NavCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeColor,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentYellow.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: _accentYellow),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (badgeColor != null) ...[
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            subtitle,
                            style: TextStyle(fontSize: 12.5, color: mutedColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: mutedColor),
            ],
          ),
        ),
      ),
    );
  }
}
