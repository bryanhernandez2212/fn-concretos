import 'package:flutter/material.dart';
import 'visit_screen_widgets.dart';

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
          const SectionLabel(text: 'Datos de la obra'),
          const SizedBox(height: 10),
          FieldGroup(
            children: [
              StyledField(
                controller: _siteNameController,
                label: 'Nombre de la obra',
                icon: Icons.construction_outlined,
              ),
              const SizedBox(height: 12),
              StyledField(
                controller: _contactController,
                label: 'Cliente / Contacto',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              StyledField(
                controller: _phoneController,
                label: 'Teléfono',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionLabel(text: 'Ubicación'),
          const SizedBox(height: 10),
          FieldGroup(
            children: [
              MapPreview(onTap: _openInMaps),
              const SizedBox(height: 12),
              StyledField(
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
          const SectionLabel(text: 'Detalles de la cotización'),
          const SizedBox(height: 10),
          FieldGroup(
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
              StyledField(
                controller: _volumeController,
                label: 'Volumen estimado (m³)',
                icon: Icons.water_drop_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              StyledField(
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
