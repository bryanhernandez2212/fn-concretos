import 'package:flutter/material.dart';
import '../widgets/field_group.dart';
import 'dosificacion_widgets.dart';

const _accentYellow = Color(0xFFFFCC00);

/// Reports what was actually pumped/poured at the job site — cemento,
/// arena, grava, agua, aditivo, acelerante — mirroring the `InformePesadora`
/// entity. Operador de Bomba-only (see vistas.md): the backend model exists
/// but has no service/controller/DTO yet, so this stays a mock submission
/// like the other evidence forms until that's built.
class DosificacionScreen extends StatefulWidget {
  final String remisionFolio;

  const DosificacionScreen({super.key, required this.remisionFolio});

  @override
  State<DosificacionScreen> createState() => _DosificacionScreenState();
}

class _DosificacionScreenState extends State<DosificacionScreen> {
  final _cementoController = TextEditingController();
  final _arenaController = TextEditingController();
  final _gravaController = TextEditingController();
  final _aguaController = TextEditingController();
  final _aditivoController = TextEditingController();
  final _aceleranteController = TextEditingController();

  @override
  void dispose() {
    _cementoController.dispose();
    _arenaController.dispose();
    _gravaController.dispose();
    _aguaController.dispose();
    _aditivoController.dispose();
    _aceleranteController.dispose();
    super.dispose();
  }

  void _submit() {
    final requeridos = [_cementoController, _arenaController, _gravaController, _aguaController];
    if (requeridos.any((c) => c.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captura al menos cemento, arena, grava y agua')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reporte de dosificación registrado (demostración)')),
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Dosificación · ${widget.remisionFolio}'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : _accentYellow,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'Captura lo realmente bombeado/vaciado en obra para esta remisión.',
            style: TextStyle(fontSize: 13.5, color: mutedColor),
          ),
          const SizedBox(height: 20),
          FieldGroup(
            cardColor: cardColor,
            borderColor: borderColor,
            expand: true,
            child: Column(
              children: [
                IngredienteField(controller: _cementoController, label: 'Cemento', unidad: 'kg', textColor: textColor, mutedColor: mutedColor),
                const SizedBox(height: 14),
                IngredienteField(controller: _arenaController, label: 'Arena', unidad: 'kg', textColor: textColor, mutedColor: mutedColor),
                const SizedBox(height: 14),
                IngredienteField(controller: _gravaController, label: 'Grava', unidad: 'kg', textColor: textColor, mutedColor: mutedColor),
                const SizedBox(height: 14),
                IngredienteField(controller: _aguaController, label: 'Agua', unidad: 'L', textColor: textColor, mutedColor: mutedColor),
                const SizedBox(height: 14),
                IngredienteField(controller: _aditivoController, label: 'Aditivo', unidad: 'L', textColor: textColor, mutedColor: mutedColor, requerido: false),
                const SizedBox(height: 14),
                IngredienteField(controller: _aceleranteController, label: 'Acelerante', unidad: 'L', textColor: textColor, mutedColor: mutedColor, requerido: false),
              ],
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
