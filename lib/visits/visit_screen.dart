import 'package:flutter/material.dart';

const _accentYellow = Color(0xFFFFCC00);

const _concreteTypes = ['f\'c 150', 'f\'c 200', 'f\'c 250', 'f\'c 300', 'f\'c 350'];

/// Concept screen for a sales rep visiting a job site: capture the site's
/// data and location, then request or create a quote from it. Everything
/// here is a static mock — no maps SDK, no persistence, no backend.
class VisitScreen extends StatefulWidget {
  const VisitScreen({super.key});

  @override
  State<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> {
  final _siteNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController(text: 'Av. Insurgentes Sur 1234, Ciudad de México');
  final _volumeController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedConcreteType = _concreteTypes[1];

  @override
  void dispose() {
    _siteNameController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _volumeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _openInMaps() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Esto abriría Google Maps (demostración)')),
    );
  }

  void _createQuote() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cotización creada (demostración)')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visita a Obra'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : _accentYellow,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const _SectionLabel(text: 'Datos de la obra'),
          const SizedBox(height: 10),
          _FieldGroup(
            children: [
              _StyledField(
                controller: _siteNameController,
                label: 'Nombre de la obra',
                icon: Icons.construction_outlined,
              ),
              const SizedBox(height: 12),
              _StyledField(
                controller: _contactController,
                label: 'Cliente / Contacto',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              _StyledField(
                controller: _phoneController,
                label: 'Teléfono',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel(text: 'Ubicación'),
          const SizedBox(height: 10),
          _FieldGroup(
            children: [
              _MapPreview(onTap: _openInMaps),
              const SizedBox(height: 12),
              _StyledField(
                controller: _addressController,
                label: 'Dirección',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openInMaps,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Abrir en Google Maps'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel(text: 'Detalles de la cotización'),
          const SizedBox(height: 10),
          _FieldGroup(
            children: [
              Text(
                'Tipo de concreto',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in _concreteTypes)
                    ChoiceChip(
                      label: Text(type),
                      selected: _selectedConcreteType == type,
                      onSelected: (_) => setState(() => _selectedConcreteType = type),
                      selectedColor: _accentYellow,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _selectedConcreteType == type
                            ? Colors.black
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.045),
                      side: BorderSide.none,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _StyledField(
                controller: _volumeController,
                label: 'Volumen estimado (m³)',
                icon: Icons.water_drop_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _StyledField(
                controller: _notesController,
                label: 'Notas adicionales',
                icon: Icons.notes_outlined,
                maxLines: 3,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Guardar borrador', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _createQuote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentYellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Crear cotización', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small uppercase heading used to introduce a grouped section.
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

/// Rounded card that groups related fields together, matching the style
/// used across the rest of the app (see profile_screen.dart).
class _FieldGroup extends StatelessWidget {
  final List<Widget> children;

  const _FieldGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

/// Filled, icon-prefixed text field consistent with the edit-profile dialog.
class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;

  const _StyledField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.045);
    final textColor = isDark ? Colors.white : Colors.black87;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: _accentYellow),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
          borderSide: const BorderSide(color: _accentYellow, width: 1.5),
        ),
      ),
    );
  }
}

/// Static mock of a map tile with a pin — stands in for a real Google Maps
/// embed, which would need the maps SDK and an API key.
class _MapPreview extends StatelessWidget {
  final VoidCallback onTap;

  const _MapPreview({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 150,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFB8D8BA), Color(0xFF8FB996)],
                  ),
                ),
              ),
              CustomPaint(painter: _MapGridPainter(), size: Size.infinite),
              const Icon(Icons.location_on, color: Colors.redAccent, size: 42, shadows: [
                Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
              ]),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Toca para abrir el mapa',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
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

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    const step = 22.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) => false;
}
