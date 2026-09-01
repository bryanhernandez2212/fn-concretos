import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import 'asesor_comercial_service.dart';

/// Form for `POST /solicitudes-diseno` — filed before quoting when an obra
/// needs a special mix design. Resolving viabilidad is a laboratorio-side
/// action, not exposed here; this screen only creates the request.
class SolicitudDisenoScreen extends StatefulWidget {
  final int clienteId;
  final int? obraId;

  const SolicitudDisenoScreen({super.key, required this.clienteId, this.obraId});

  @override
  State<SolicitudDisenoScreen> createState() => _SolicitudDisenoScreenState();
}

class _SolicitudDisenoScreenState extends State<SolicitudDisenoScreen> {
  final _productoController = TextEditingController();
  final _revenimientoController = TextEditingController();
  final _tamanoAgregadoController = TextEditingController();
  final _caracteristicaController = TextEditingController();
  DateTime? _fechaDeseada;
  bool _enviando = false;

  @override
  void dispose() {
    _productoController.dispose();
    _revenimientoController.dispose();
    _tamanoAgregadoController.dispose();
    _caracteristicaController.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final hoy = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: hoy,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 365)),
      locale: const Locale('es'),
      builder: (context, child) {
        final base = Theme.of(context);
        return Theme(
          data: base.copyWith(colorScheme: base.colorScheme.copyWith(primary: AppColors.accent, onPrimary: Colors.black)),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _fechaDeseada = picked);
  }

  Future<void> _submit() async {
    setState(() => _enviando = true);
    try {
      await AsesorComercialService.crearSolicitudDiseno(
        clienteId: widget.clienteId,
        obraId: widget.obraId,
        productoSolicitado: _productoController.text.trim().isEmpty ? null : _productoController.text.trim(),
        revenimiento: _revenimientoController.text.trim().isEmpty ? null : _revenimientoController.text.trim(),
        tamanoAgregado: _tamanoAgregadoController.text.trim().isEmpty ? null : _tamanoAgregadoController.text.trim(),
        caracteristicaEspecial: _caracteristicaController.text.trim().isEmpty ? null : _caracteristicaController.text.trim(),
        fechaDeseada: _fechaDeseada,
      );
      if (!mounted) return;
      AppSnack.success(context, 'Solicitud de diseño enviada al laboratorio');
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo enviar la solicitud');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  InputDecoration _decoration(String hint, Color mutedColor, Color fillColor) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: mutedColor),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final fillColor = AppColors.border(context, alpha: 0.06);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar diseño especial'),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          TextField(controller: _productoController, style: TextStyle(color: textColor), decoration: _decoration('Producto solicitado', mutedColor, fillColor)),
          const SizedBox(height: 12),
          TextField(controller: _revenimientoController, style: TextStyle(color: textColor), decoration: _decoration('Revenimiento deseado', mutedColor, fillColor)),
          const SizedBox(height: 12),
          TextField(controller: _tamanoAgregadoController, style: TextStyle(color: textColor), decoration: _decoration('Tamaño de agregado', mutedColor, fillColor)),
          const SizedBox(height: 12),
          TextField(
            controller: _caracteristicaController,
            maxLines: 3,
            style: TextStyle(color: textColor),
            decoration: _decoration('Característica especial requerida', mutedColor, fillColor),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickFecha,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 18, color: mutedColor),
                  const SizedBox(width: 12),
                  Text(
                    _fechaDeseada == null ? 'Fecha deseada (opcional)' : DateFormat('d/MM/y').format(_fechaDeseada!),
                    style: TextStyle(color: _fechaDeseada == null ? mutedColor : textColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _enviando ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _enviando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                  : const Text('Enviar solicitud', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
