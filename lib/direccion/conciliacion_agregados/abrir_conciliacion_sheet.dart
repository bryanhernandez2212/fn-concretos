import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../finanzas/finanzas_service.dart';
import '../../jefe_planta/jefe_planta_service.dart' show Proveedor;
import '../../theme/app_colors.dart';
import '../../widgets/app_feedback.dart';

class AbrirConciliacionSheet extends StatefulWidget {
  final List<Proveedor> proveedores;
  final Proveedor? proveedorInicial;

  const AbrirConciliacionSheet({
    super.key,
    required this.proveedores,
    this.proveedorInicial,
  });

  @override
  State<AbrirConciliacionSheet> createState() => _AbrirConciliacionSheetState();
}

class _AbrirConciliacionSheetState extends State<AbrirConciliacionSheet> {
  late Proveedor? _proveedorSeleccionado = widget.proveedorInicial ??
      (widget.proveedores.isNotEmpty ? widget.proveedores.first : null);

  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _enviando = false;

  final _dateFormatter = DateFormat('yyyy-MM-dd');

  Future<void> _seleccionarFechaInicio() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaInicio ?? now.subtract(const Duration(days: 15)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _fechaInicio = picked);
    }
  }

  Future<void> _seleccionarFechaFin() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaFin ?? now,
      firstDate: _fechaInicio ?? DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _fechaFin = picked);
    }
  }

  Future<void> _crear() async {
    if (_proveedorSeleccionado == null) {
      AppSnack.error(context, 'Selecciona un proveedor');
      return;
    }
    if (_fechaInicio == null || _fechaFin == null) {
      AppSnack.error(context, 'Selecciona las fechas de inicio y fin');
      return;
    }
    if (_fechaFin!.isBefore(_fechaInicio!)) {
      AppSnack.error(context, 'La fecha final no puede ser anterior a la inicial');
      return;
    }

    setState(() => _enviando = true);
    try {
      final nueva = await FinanzasService.abrirConciliacionProveedor(
        proveedorId: _proveedorSeleccionado!.id,
        periodoInicio: _dateFormatter.format(_fechaInicio!),
        periodoFin: _dateFormatter.format(_fechaFin!),
      );
      if (mounted) {
        Navigator.of(context).pop(nueva);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enviando = false);
        AppSnack.error(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: mutedColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Abrir Conciliación de Proveedor',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),

            // Proveedor selector
            DropdownButtonFormField<Proveedor>(
              initialValue: _proveedorSeleccionado,
              decoration: InputDecoration(
                labelText: 'Proveedor',
                filled: true,
                fillColor: AppColors.card(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border(context)),
                ),
              ),
              items: widget.proveedores.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Text(
                    p.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _proveedorSeleccionado = val);
              },
            ),
            const SizedBox(height: 14),

            // Date pickers row
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _seleccionarFechaInicio,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Inicio', style: TextStyle(fontSize: 11, color: mutedColor)),
                          const SizedBox(height: 4),
                          Text(
                            _fechaInicio != null
                                ? _dateFormatter.format(_fechaInicio!)
                                : 'Seleccionar',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _fechaInicio != null ? textColor : mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _seleccionarFechaFin,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fin', style: TextStyle(fontSize: 11, color: mutedColor)),
                          const SizedBox(height: 4),
                          Text(
                            _fechaFin != null
                                ? _dateFormatter.format(_fechaFin!)
                                : 'Seleccionar',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _fechaFin != null ? textColor : mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _enviando ? null : _crear,
                child: _enviando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                        'Abrir Conciliación',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
