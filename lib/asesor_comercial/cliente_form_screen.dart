import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../direccion/comercial_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import 'asesor_comercial_service.dart';

const _tipos = ['particular', 'corporativo'];

/// Registers a new cliente (`POST /clientes`) — the first step of Asesor
/// Comercial's "agregar obra" flow when the advisor is at a site whose
/// cliente isn't in the system yet either, reached from
/// `ClientePickerScreen`'s "Nuevo cliente" action. Pops with the created
/// [Cliente] so the caller can move straight on to `ObraFormScreen`.
class ClienteFormScreen extends StatefulWidget {
  const ClienteFormScreen({super.key});

  @override
  State<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends State<ClienteFormScreen> {
  final _nombreController = TextEditingController();
  final _numeroClienteController = TextEditingController();
  final _rfcController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _correoController = TextEditingController();
  String _tipo = _tipos.first;
  bool _requiereFactura = false;
  bool _enviando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _numeroClienteController.dispose();
    _rfcController.dispose();
    _telefonoController.dispose();
    _correoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      AppSnack.error(context, 'Ingresa el nombre del cliente');
      return;
    }

    setState(() => _enviando = true);
    try {
      final asesor = await AsesorComercialService.miAsesor();
      final cliente = await ComercialService.crearCliente(
        nombre: nombre,
        numeroCliente: _numeroClienteController.text.trim(),
        tipo: _tipo,
        rfc: _rfcController.text.trim(),
        telefono: _telefonoController.text.trim(),
        correo: _correoController.text.trim(),
        requiereFacturaDefault: _requiereFactura,
        asesorAsignadoId: asesor?.id,
      );
      if (!mounted) return;
      AppSnack.success(context, 'Cliente registrado');
      Navigator.of(context).pop(cliente);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo registrar el cliente');
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
        title: const Text('Nuevo cliente'),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          TextField(
            controller: _nombreController,
            style: TextStyle(color: textColor),
            decoration: _decoration('Nombre del cliente', mutedColor, fillColor),
          ),
          const SizedBox(height: 12),
          Row(
            children: _tipos.map((tipo) {
              final selected = tipo == _tipo;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: tipo == _tipos.first ? 8 : 0, left: tipo == _tipos.first ? 0 : 8),
                  child: ChoiceChip(
                    label: Text(tipo == 'particular' ? 'Particular' : 'Corporativo'),
                    selected: selected,
                    onSelected: (_) => setState(() => _tipo = tipo),
                    selectedColor: AppColors.accent,
                    labelStyle: TextStyle(color: selected ? Colors.black : textColor, fontWeight: FontWeight.w600),
                    backgroundColor: fillColor,
                    side: BorderSide.none,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _numeroClienteController,
            style: TextStyle(color: textColor),
            decoration: _decoration('Número de cliente (opcional)', mutedColor, fillColor),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _telefonoController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: textColor),
            decoration: _decoration('Teléfono (opcional)', mutedColor, fillColor),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _correoController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: textColor),
            decoration: _decoration('Correo (opcional)', mutedColor, fillColor),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rfcController,
            style: TextStyle(color: textColor),
            decoration: _decoration('RFC (opcional)', mutedColor, fillColor),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _requiereFactura,
            onChanged: (value) => setState(() => _requiereFactura = value),
            title: Text('Requiere factura', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.accent,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 20),
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
                  : const Text('Registrar cliente', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
