import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../catalogo/catalogo_service.dart';
import '../../catalogo/planta.dart';
import '../../finanzas/finanzas_service.dart';
import '../../jefe_planta/jefe_planta_service.dart' show Proveedor;
import '../../theme/app_colors.dart';
import '../../widgets/app_feedback.dart';

class RegistrarValeSheet extends StatefulWidget {
  final List<Proveedor> proveedores;
  final Proveedor? proveedorInicial;

  const RegistrarValeSheet({
    super.key,
    required this.proveedores,
    this.proveedorInicial,
  });

  @override
  State<RegistrarValeSheet> createState() => _RegistrarValeSheetState();
}

class _RegistrarValeSheetState extends State<RegistrarValeSheet> {
  late Proveedor? _proveedorSeleccionado = widget.proveedorInicial ??
      (widget.proveedores.isNotEmpty ? widget.proveedores.first : null);

  String _materialSeleccionado = 'Arena';
  final _otroMaterialCtrl = TextEditingController();

  final _cantidadCtrl = TextEditingController();
  String _unidadSeleccionada = 'm3';

  DateTime _fecha = DateTime.now();
  final _dateFormatter = DateFormat('yyyy-MM-dd');

  final _folioCtrl = TextEditingController();
  final _viajeCtrl = TextEditingController();
  final _minaCtrl = TextEditingController();
  final _transportistaCtrl = TextEditingController();
  final _placasCtrl = TextEditingController();
  final _firmanteCtrl = TextEditingController();

  List<Planta> _plantas = [];
  Planta? _plantaSeleccionada;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cargarPlantas();
  }

  Future<void> _cargarPlantas() async {
    try {
      final plantas = await CatalogoService.plantas();
      if (mounted) {
        setState(() {
          _plantas = plantas;
          if (plantas.isNotEmpty) _plantaSeleccionada = plantas.first;
        });
      }
    } catch (_) {}
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _fecha = picked);
    }
  }

  Future<void> _guardar() async {
    if (_proveedorSeleccionado == null) {
      AppSnack.error(context, 'Selecciona un proveedor');
      return;
    }

    final cant = double.tryParse(_cantidadCtrl.text.trim());
    if (cant == null || cant <= 0) {
      AppSnack.error(context, 'Ingresa una cantidad válida mayor a 0');
      return;
    }

    final material = _materialSeleccionado == 'Otro'
        ? _otroMaterialCtrl.text.trim()
        : _materialSeleccionado;

    if (material.isEmpty) {
      AppSnack.error(context, 'Indica el material del vale');
      return;
    }

    setState(() => _enviando = true);

    final body = <String, dynamic>{
      'proveedorId': _proveedorSeleccionado!.id,
      'fecha': _dateFormatter.format(_fecha),
      'cantidad': cant,
      'unidad': _unidadSeleccionada,
      'material': material,
      if (_folioCtrl.text.trim().isNotEmpty) 'folioVale': _folioCtrl.text.trim(),
      if (_viajeCtrl.text.trim().isNotEmpty) 'numeroViaje': _viajeCtrl.text.trim(),
      if (_minaCtrl.text.trim().isNotEmpty) 'minaOrigen': _minaCtrl.text.trim(),
      if (_transportistaCtrl.text.trim().isNotEmpty)
        'transportista': _transportistaCtrl.text.trim(),
      if (_placasCtrl.text.trim().isNotEmpty) 'placas': _placasCtrl.text.trim(),
      if (_firmanteCtrl.text.trim().isNotEmpty) 'firmante': _firmanteCtrl.text.trim(),
      if (_plantaSeleccionada != null) 'plantaId': _plantaSeleccionada!.id,
    };

    try {
      final creado = await FinanzasService.registrarValeEntradaMaterial(body);
      if (mounted) {
        Navigator.of(context).pop(creado);
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: bottomInset + 20,
        ),
        child: SingleChildScrollView(
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
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppColors.accent, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Registrar Vale de Entrada',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Proveedor
              DropdownButtonFormField<Proveedor>(
                initialValue: _proveedorSeleccionado,
                decoration: InputDecoration(
                  labelText: 'Proveedor *',
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
                    child: Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (p) => setState(() => _proveedorSeleccionado = p),
              ),
              const SizedBox(height: 12),

              // Material & Fecha row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _materialSeleccionado,
                      decoration: InputDecoration(
                        labelText: 'Material *',
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border(context)),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Arena', child: Text('Arena')),
                        DropdownMenuItem(value: 'Grava', child: Text('Grava')),
                        DropdownMenuItem(value: 'Agua', child: Text('Agua')),
                        DropdownMenuItem(value: 'Aditivo', child: Text('Aditivo')),
                        DropdownMenuItem(value: 'Otro', child: Text('Otro...')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _materialSeleccionado = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _seleccionarFecha,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fecha *', style: TextStyle(fontSize: 11, color: mutedColor)),
                            const SizedBox(height: 2),
                            Text(
                              _dateFormatter.format(_fecha),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_materialSeleccionado == 'Otro') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _otroMaterialCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nombre del material *',
                    hintText: 'Ej. Cemento, Sello...',
                    filled: true,
                    fillColor: AppColors.card(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border(context)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Cantidad y Unidad
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _cantidadCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Cantidad *',
                        hintText: '0.00',
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border(context)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unidadSeleccionada,
                      decoration: InputDecoration(
                        labelText: 'Unidad',
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border(context)),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'm3', child: Text('m³')),
                        DropdownMenuItem(value: 'ton', child: Text('Ton')),
                        DropdownMenuItem(value: 'viaje', child: Text('Viaje')),
                        DropdownMenuItem(value: 'lts', child: Text('Lts')),
                        DropdownMenuItem(value: 'pza', child: Text('Pza')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _unidadSeleccionada = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Folio Vale & Número de viaje
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _folioCtrl,
                      decoration: InputDecoration(
                        labelText: 'Folio del vale',
                        hintText: 'Ej. V-2024-01',
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border(context)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _viajeCtrl,
                      decoration: InputDecoration(
                        labelText: 'N° de viaje',
                        hintText: 'Ej. 03',
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border(context)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Transportista y Placas
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _transportistaCtrl,
                      decoration: InputDecoration(
                        labelText: 'Transportista',
                        hintText: 'Nombre chofer',
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border(context)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _placasCtrl,
                      decoration: InputDecoration(
                        labelText: 'Placas',
                        hintText: 'CW-1234',
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border(context)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Mina origen y Firmante
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minaCtrl,
                      decoration: InputDecoration(
                        labelText: 'Mina / Origen',
                        hintText: 'Ej. Cantera Sur',
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border(context)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _firmanteCtrl,
                      decoration: InputDecoration(
                        labelText: 'Firmante receptor',
                        hintText: 'Nombre quien recibe',
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border(context)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_plantas.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<Planta>(
                  initialValue: _plantaSeleccionada,
                  decoration: InputDecoration(
                    labelText: 'Planta de recepción',
                    filled: true,
                    fillColor: AppColors.card(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border(context)),
                    ),
                  ),
                  items: _plantas.map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (p) => setState(() => _plantaSeleccionada = p),
                ),
              ],
              const SizedBox(height: 20),

              // Submit Button
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
                  onPressed: _enviando ? null : _guardar,
                  child: _enviando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text(
                          'Registrar Vale de Entrada',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
