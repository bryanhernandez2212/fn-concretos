import 'package:flutter/material.dart';
import 'edit_profile_widgets.dart';

const _accentYellow = Color(0xFFFFCC00);

/// Editor for the fields that have no backend source yet (planta/ciudad —
/// `GET /auth/me` doesn't return them). Usuario/cargo/correo moved to
/// `ProfileScreen`'s real, read-only session data (`AuthService`), so
/// they're no longer editable here — a local edit couldn't actually change
/// them on the backend anyway. Pops with a `Map<String, String>` of the
/// edited fields on save, or `null` on cancel.
class EditProfileScreen extends StatefulWidget {
  final String plant;
  final String city;

  const EditProfileScreen({
    super.key,
    required this.plant,
    required this.city,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _plantController = TextEditingController(text: widget.plant);
  late final _cityController = TextEditingController(text: widget.city);

  @override
  void dispose() {
    _plantController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop({
      'plant': _plantController.text.trim(),
      'city': _cityController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : _accentYellow,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _accentYellow.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: _accentYellow, size: 40),
            ),
          ),
          const SizedBox(height: 24),
          FieldGroup(
            children: [
              EditField(
                controller: _plantController,
                label: 'Planta',
                icon: Icons.factory_outlined,
              ),
              const SizedBox(height: 14),
              EditField(
                controller: _cityController,
                label: 'Ciudad',
                icon: Icons.location_city_outlined,
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
                  child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentYellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
