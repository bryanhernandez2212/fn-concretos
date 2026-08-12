import 'package:flutter/material.dart';
import 'vehicle.dart';

const _accentYellow = Color(0xFFFFCC00);

/// Report a `VehiculoPendiente`: mechanical failure, tire, or maintenance
/// need. Submitting just confirms and pops until the endpoint is wired.
class VehiclePendingScreen extends StatefulWidget {
  const VehiclePendingScreen({super.key});

  @override
  State<VehiclePendingScreen> createState() => _VehiclePendingScreenState();
}

class _VehiclePendingScreenState extends State<VehiclePendingScreen> {
  final _descriptionController = TextEditingController();
  TipoPendiente _tipo = TipoPendiente.fallaMecanica;
  UrgenciaPendiente _urgencia = UrgenciaPendiente.media;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe el pendiente antes de enviar')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pendiente reportado (demostración)')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.12);
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.045);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar Pendiente'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : _accentYellow,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _SectionLabel(text: 'Tipo de pendiente', textColor: textColor),
          const SizedBox(height: 10),
          _FieldGroup(
            cardColor: cardColor,
            borderColor: borderColor,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tipo in TipoPendiente.values)
                  ChoiceChip(
                    label: Text(tipo.label),
                    avatar: Icon(tipo.icon, size: 16, color: _tipo == tipo ? Colors.black : textColor),
                    selected: _tipo == tipo,
                    onSelected: (_) => setState(() => _tipo = tipo),
                    selectedColor: _accentYellow,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _tipo == tipo ? Colors.black : textColor,
                    ),
                    backgroundColor: fillColor,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel(text: 'Urgencia', textColor: textColor),
          const SizedBox(height: 10),
          _FieldGroup(
            cardColor: cardColor,
            borderColor: borderColor,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final urgencia in UrgenciaPendiente.values)
                  ChoiceChip(
                    label: Text(urgencia.label),
                    selected: _urgencia == urgencia,
                    onSelected: (_) => setState(() => _urgencia = urgencia),
                    selectedColor: urgencia.color,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _urgencia == urgencia ? Colors.white : textColor,
                    ),
                    backgroundColor: fillColor,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel(text: 'Descripción', textColor: textColor),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Describe lo que observaste...',
              hintStyle: TextStyle(color: mutedColor),
              filled: true,
              fillColor: fillColor,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _accentYellow, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentYellow,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Enviar reporte', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color textColor;

  const _SectionLabel({required this.text, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor));
  }
}

class _FieldGroup extends StatelessWidget {
  final Color cardColor;
  final Color borderColor;
  final Widget child;

  const _FieldGroup({required this.cardColor, required this.borderColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}
