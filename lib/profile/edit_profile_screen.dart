import 'package:flutter/material.dart';

const _accentYellow = Color(0xFFFFCC00);

/// Full-screen profile editor, pushed from [ProfileScreen]. Pops with a
/// `Map<String, String>` of the edited fields on save, or `null` on cancel.
class EditProfileScreen extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String position;
  final String plant;
  final String city;
  final String email;

  const EditProfileScreen({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.position,
    required this.plant,
    required this.city,
    required this.email,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _firstNameController = TextEditingController(text: widget.firstName);
  late final _lastNameController = TextEditingController(text: widget.lastName);
  late final _positionController = TextEditingController(text: widget.position);
  late final _plantController = TextEditingController(text: widget.plant);
  late final _cityController = TextEditingController(text: widget.city);
  late final _emailController = TextEditingController(text: widget.email);

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _positionController.dispose();
    _plantController.dispose();
    _cityController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop({
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'position': _positionController.text.trim(),
      'plant': _plantController.text.trim(),
      'city': _cityController.text.trim(),
      'email': _emailController.text.trim(),
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
          _FieldGroup(
            children: [
              _EditField(
                controller: _firstNameController,
                label: 'Nombre',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 14),
              _EditField(
                controller: _lastNameController,
                label: 'Apellido',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 14),
              _EditField(
                controller: _positionController,
                label: 'Cargo',
                icon: Icons.work_outline,
              ),
              const SizedBox(height: 14),
              _EditField(
                controller: _plantController,
                label: 'Planta',
                icon: Icons.factory_outlined,
              ),
              const SizedBox(height: 14),
              _EditField(
                controller: _cityController,
                label: 'Ciudad',
                icon: Icons.location_city_outlined,
              ),
              const SizedBox(height: 14),
              _EditField(
                controller: _emailController,
                label: 'Correo',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
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

/// Rounded card that groups related fields, matching the style used across
/// the rest of the app (see profile_screen.dart / visit_screen.dart).
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
      child: Column(children: children),
    );
  }
}

/// A filled, icon-prefixed text field used inside the edit-profile screen.
class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  const _EditField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.045);
    final textColor = isDark ? Colors.white : Colors.black87;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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
