import 'package:flutter/material.dart';
import '../visits/visit_screen.dart';

const _accentYellow = Color(0xFFFFCC00);

class _Metric {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
}

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});
}

const _heroMetric = _Metric(
  icon: Icons.receipt_long,
  value: '12',
  label: 'Pedidos activos',
  color: _accentYellow,
);

const _secondaryMetrics = [
  _Metric(
    icon: Icons.local_shipping_outlined,
    value: '3',
    label: 'En camino',
    color: Color(0xFF4CAF50),
  ),
  _Metric(
    icon: Icons.inventory_2_outlined,
    value: '5',
    label: 'Inventario bajo',
    color: Color(0xFFEF5350),
  ),
  _Metric(
    icon: Icons.attach_money,
    value: '\$248k',
    label: 'Ventas del mes',
    color: Color(0xFF42A5F5),
  ),
];

/// Main panel for the "Home" tab: a hero KPI, secondary metrics, quick
/// actions, and a next-visit teaser. Values are static placeholders until
/// there is a backend integration.
class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    final quickActions = [
      _QuickAction(icon: Icons.add_circle_outline, label: 'Nuevo pedido', onTap: () {}),
      _QuickAction(icon: Icons.inventory_2_outlined, label: 'Inventario', onTap: () {}),
      _QuickAction(
        icon: Icons.location_on_outlined,
        label: 'Visitar obra',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const VisitScreen()),
          );
        },
      ),
      _QuickAction(icon: Icons.description_outlined, label: 'Reportes', onTap: () {}),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accentYellow.withValues(alpha: 0.18),
                  ),
                  child: const Icon(Icons.person, color: _accentYellow),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, Juan 👋',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor),
                      ),
                      Text('Así va tu operación hoy', style: TextStyle(fontSize: 13, color: mutedColor)),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cardColor,
                    border: Border.all(color: borderColor),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.notifications_none, color: textColor),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _HeroCard(metric: _heroMetric),
            const SizedBox(height: 20),
            _MetricCard(
              metric: _secondaryMetrics[0],
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              mutedColor: mutedColor,
              wide: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    metric: _secondaryMetrics[1],
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    metric: _secondaryMetrics[2],
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Accesos rápidos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final action in quickActions) ...[
                    _QuickActionButton(
                      action: action,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                    ),
                    const SizedBox(width: 12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            _NextVisitCard(cardColor: cardColor, borderColor: borderColor, textColor: textColor, mutedColor: mutedColor),
          ],
        ),
      ),
    );
  }
}

/// Large, prominent card for the single most important metric — gives the
/// dashboard a clear focal point instead of a wall of equally-weighted boxes.
class _HeroCard extends StatelessWidget {
  final _Metric metric;

  const _HeroCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_accentYellow, Color(0xFFFFA000)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label.toUpperCase(),
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  metric.value,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 44),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.trending_up, color: Colors.black87, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '+3 esta semana',
                      style: TextStyle(color: Colors.black.withValues(alpha: 0.75), fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: -18,
            top: -18,
            child: Icon(metric.icon, size: 130, color: Colors.black.withValues(alpha: 0.08)),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _Metric metric;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final bool wide;

  const _MetricCard({
    required this.metric,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconBadge = Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: metric.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(metric.icon, color: metric.color, size: 18),
    );
    final valueText = Text(
      metric.value,
      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: textColor),
    );
    final labelText = Text(
      metric.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: mutedColor),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: wide
          ? Row(
              children: [
                iconBadge,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [valueText, const SizedBox(height: 2), labelText],
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconBadge,
                const SizedBox(height: 14),
                valueText,
                const SizedBox(height: 2),
                labelText,
              ],
            ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final _QuickAction action;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;

  const _QuickActionButton({
    required this.action,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: action.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accentYellow.withValues(alpha: 0.15),
                  ),
                  child: Icon(action.icon, color: _accentYellow, size: 19),
                ),
                const SizedBox(height: 8),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Teaser card linking to the next scheduled site visit — gives the
/// dashboard actual content instead of only numbers, and surfaces the
/// visits feature from the home screen.
class _NextVisitCard extends StatelessWidget {
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const _NextVisitCard({
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const VisitScreen()),
          );
        },
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
                child: const Icon(Icons.location_on_outlined, color: _accentYellow),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Próxima visita', style: TextStyle(fontSize: 12, color: mutedColor)),
                    const SizedBox(height: 2),
                    Text(
                      'Residencial Las Lomas',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text('25 Nov · 10:00 AM', style: TextStyle(fontSize: 12.5, color: mutedColor)),
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
