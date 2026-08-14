import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import 'remision.dart';

const _accentYellow = Color(0xFFFFCC00);

/// Registers a "prueba de concreto fresco" (revenimiento/masa unitaria/
/// temperatura/rendimiento field test) via the real `POST
/// /pruebas-concreto-fresco`. Operador de Bomba-only, and only reachable
/// when `remision.remisionId != null` (see `DeliveryDetailScreen`) — the
/// test is tied to a specific remisión, so there's nothing real to attach
/// it to before one exists.
class PruebaConcretoScreen extends StatefulWidget {
  final Remision remision;

  const PruebaConcretoScreen({super.key, required this.remision});

  @override
  State<PruebaConcretoScreen> createState() => _PruebaConcretoScreenState();
}

class _PruebaConcretoScreenState extends State<PruebaConcretoScreen> {
  final _revenimientoController = TextEditingController();
  final _masaUnitariaController = TextEditingController();
  final _temperaturaController = TextEditingController();
  final _rendimientoController = TextEditingController();
  final _observacionesController = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _revenimientoController.dispose();
    _masaUnitariaController.dispose();
    _temperaturaController.dispose();
    _rendimientoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final revenimiento = _revenimientoController.text.trim();
    final masaUnitaria = double.tryParse(_masaUnitariaController.text.trim());
    final temperatura = double.tryParse(_temperaturaController.text.trim());
    final rendimiento = double.tryParse(_rendimientoController.text.trim());

    if (revenimiento.isEmpty || masaUnitaria == null || temperatura == null || rendimiento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captura revenimiento, masa unitaria, temperatura y rendimiento')),
      );
      return;
    }

    final remisionId = widget.remision.remisionId;
    if (remisionId == null) return;

    setState(() => _enviando = true);
    try {
      await OperacionesService.registrarPruebaConcreto(
        remisionId: remisionId,
        pedidoId: widget.remision.pedidoId,
        clienteId: widget.remision.clienteId,
        obraId: widget.remision.obraId,
        revenimiento: revenimiento,
        masaUnitaria: masaUnitaria,
        temperatura: temperatura,
        rendimiento: rendimiento,
        observaciones: _observacionesController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prueba de concreto fresco registrada')),
      );
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo registrar la prueba')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
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
        title: Text('Prueba de concreto · ${widget.remision.folio}'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : _accentYellow,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'Captura la prueba de concreto fresco realizada en obra para esta remisión.',
            style: TextStyle(fontSize: 13.5, color: mutedColor),
          ),
          const SizedBox(height: 20),
          _FieldGroup(
            cardColor: cardColor,
            borderColor: borderColor,
            child: Column(
              children: [
                _TextField(
                  controller: _revenimientoController,
                  label: 'Revenimiento',
                  hint: 'p. ej. 10 cm',
                  textColor: textColor,
                  mutedColor: mutedColor,
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 14),
                _TextField(
                  controller: _masaUnitariaController,
                  label: 'Masa unitaria',
                  unidad: 'kg/m³',
                  textColor: textColor,
                  mutedColor: mutedColor,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                _TextField(
                  controller: _temperaturaController,
                  label: 'Temperatura',
                  unidad: '°C',
                  textColor: textColor,
                  mutedColor: mutedColor,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                ),
                const SizedBox(height: 14),
                _TextField(
                  controller: _rendimientoController,
                  label: 'Rendimiento',
                  unidad: 'm³',
                  textColor: textColor,
                  mutedColor: mutedColor,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                _TextField(
                  controller: _observacionesController,
                  label: 'Observaciones (opcional)',
                  textColor: textColor,
                  mutedColor: mutedColor,
                  keyboardType: TextInputType.text,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _enviando ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentYellow,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _enviando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                  : const Text('Enviar prueba', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
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

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? unidad;
  final String? hint;
  final Color textColor;
  final Color mutedColor;
  final TextInputType keyboardType;

  const _TextField({
    required this.controller,
    required this.label,
    this.unidad,
    this.hint,
    required this.textColor,
    required this.mutedColor,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.045);

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: unidad,
        suffixStyle: TextStyle(color: mutedColor),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _accentYellow, width: 1.5),
        ),
      ),
    );
  }
}
