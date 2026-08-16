import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import 'vehicle.dart';
import 'vehicle_pending_widgets.dart';

const _accentYellow = Color(0xFFFFCC00);

/// Report a `VehiculoPendiente`: mechanical failure, tire, or maintenance
/// need. Real `POST /vehiculos/{vehiculoId}/pendientes` — `vehiculoId` comes
/// from `VehicleScreen`'s `VehiculoService.miVehiculo()` lookup. Backend's
/// `VehiculoPendienteRequest` has no urgencia field at all, so that selector
/// was dropped rather than collecting input the server would just discard.
class VehiclePendingScreen extends StatefulWidget {
  final int vehiculoId;

  const VehiclePendingScreen({super.key, required this.vehiculoId});

  @override
  State<VehiclePendingScreen> createState() => _VehiclePendingScreenState();
}

class _VehiclePendingScreenState extends State<VehiclePendingScreen> {
  final _descriptionController = TextEditingController();
  TipoPendiente _tipo = TipoPendiente.fallaMecanica;
  bool _enviando = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe el pendiente antes de enviar')),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      await OperacionesService.registrarPendienteVehiculo(
        widget.vehiculoId,
        tipoPendiente: _tipo.backendValue,
        descripcion: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pendiente reportado')),
      );
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reportar el pendiente')),
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
          SectionLabel(text: 'Tipo de pendiente', textColor: textColor),
          const SizedBox(height: 10),
          FieldGroup(
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
          SectionLabel(text: 'Descripción', textColor: textColor),
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
                  : const Text('Enviar reporte', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
