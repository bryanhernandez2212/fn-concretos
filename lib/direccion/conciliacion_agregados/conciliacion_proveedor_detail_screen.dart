import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../finanzas/conciliacion_proveedor.dart';
import '../../finanzas/finanzas_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/info_pill.dart';
import 'conciliacion_agregados_widgets.dart';

final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

class ConciliacionProveedorDetailScreen extends StatefulWidget {
  final ConciliacionProveedor conciliacion;

  const ConciliacionProveedorDetailScreen({
    super.key,
    required this.conciliacion,
  });

  @override
  State<ConciliacionProveedorDetailScreen> createState() =>
      _ConciliacionProveedorDetailScreenState();
}

class _ConciliacionProveedorDetailScreenState
    extends State<ConciliacionProveedorDetailScreen> {
  late ConciliacionProveedor _conciliacion;
  late Future<List<ConciliacionDetalle>> _detalleFuture;
  bool _cambiandoEstatus = false;

  @override
  void initState() {
    super.initState();
    _conciliacion = widget.conciliacion;
    _detalleFuture = _cargarDetalle();
  }

  Future<List<ConciliacionDetalle>> _cargarDetalle() =>
      FinanzasService.detalleConciliacionProveedor(_conciliacion.id);

  void _recargar() {
    setState(() {
      _detalleFuture = _cargarDetalle();
    });
  }

  Future<void> _cambiarEstatus() async {
    const opciones = [
      ('BORRADOR', 'Borrador', Icons.edit_note, AppColors.neutral),
      ('CONCILIADO', 'Conciliado', Icons.check_circle_outline, AppColors.success),
      ('CON_DIFERENCIA', 'Con diferencia', Icons.warning_amber_rounded, AppColors.warning),
      ('APROBADO', 'Aprobado', Icons.verified_outlined, AppColors.success),
      ('PAGADO', 'Pagado', Icons.attach_money, AppColors.success),
      ('CANCELADO', 'Cancelado', Icons.cancel_outlined, AppColors.error),
    ];

    final nuevoEstatus = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceAlt(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                      color: AppColors.mutedText(context).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Cambiar estatus de la conciliación',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 12),
                ...opciones.map((op) {
                  final seleccionado = _conciliacion.estatus.toUpperCase() == op.$1;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(op.$3, color: op.$4),
                    title: Text(
                      op.$2,
                      style: TextStyle(
                        fontWeight: seleccionado ? FontWeight.w800 : FontWeight.w500,
                        color: seleccionado ? AppColors.accent : AppColors.text(context),
                      ),
                    ),
                    trailing: seleccionado
                        ? const Icon(Icons.check, color: AppColors.accent)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(op.$1),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (nuevoEstatus == null || nuevoEstatus == _conciliacion.estatus) return;

    setState(() => _cambiandoEstatus = true);
    try {
      final updated = await FinanzasService.cambiarEstatusConciliacionProveedor(
        _conciliacion.id,
        estatus: nuevoEstatus,
      );
      if (mounted) {
        setState(() {
          _conciliacion = updated;
          _cambiandoEstatus = false;
        });
        AppSnack.success(context, 'Estatus actualizado a ${etiquetaEstatusConciliacion(nuevoEstatus)}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cambiandoEstatus = false);
        AppSnack.error(context, e.toString());
      }
    }
  }

  Future<void> _abrirAgregarRenglon() async {
    final valeCtrl = TextEditingController();
    final entradaCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    final obsCtrl = TextEditingController();
    String estatusSeleccionado = 'CONCILIADO';

    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceAlt(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
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
                          color: AppColors.mutedText(context).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Agregar renglón (Vale vs Entrada)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: valeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'ID Vale',
                              hintText: 'Ej. 101',
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
                            controller: entradaCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'ID Entrada',
                              hintText: 'Ej. 202',
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
                    TextField(
                      controller: montoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Diferencia en monto (\$)',
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.attach_money, size: 20),
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border(context)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: estatusSeleccionado,
                      decoration: InputDecoration(
                        labelText: 'Estatus del renglón',
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border(context)),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'CONCILIADO', child: Text('Conciliado')),
                        DropdownMenuItem(value: 'CON_DIFERENCIA', child: Text('Con diferencia')),
                        DropdownMenuItem(value: 'PENDIENTE', child: Text('Pendiente')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => estatusSeleccionado = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: obsCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Observaciones',
                        hintText: 'Notas sobre la conciliación del renglón...',
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border(context)),
                        ),
                      ),
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
                        onPressed: () async {
                          final valeId = int.tryParse(valeCtrl.text.trim());
                          final entradaId = int.tryParse(entradaCtrl.text.trim());
                          final diff = double.tryParse(montoCtrl.text.trim());

                          try {
                            await FinanzasService.agregarDetalleConciliacionProveedor(
                              _conciliacion.id,
                              valeId: valeId,
                              entradaId: entradaId,
                              estatus: estatusSeleccionado,
                              diferenciaMonto: diff,
                              observaciones: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop(true);
                          } catch (e) {
                            if (ctx.mounted) {
                              AppSnack.error(ctx, e.toString());
                            }
                          }
                        },
                        child: const Text(
                          'Agregar Renglón',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (guardado == true && mounted) {
      AppSnack.success(context, 'Renglón agregado con éxito');
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Conciliación #${_conciliacion.id}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Cambiar estatus',
            onPressed: _cambiandoEstatus ? null : _cambiarEstatus,
            icon: _cambiandoEstatus
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.edit_note),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _recargar(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Header summary card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _conciliacion.proveedorNombre,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ),
                      EstatusConciliacionChip(estatus: _conciliacion.estatus),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_month_outlined, size: 15, color: mutedColor),
                      const SizedBox(width: 6),
                      Text(
                        'Período: ${_conciliacion.periodoInicio}  al  ${_conciliacion.periodoFin}',
                        style: TextStyle(fontSize: 13, color: mutedColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Metrics wrap
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_conciliacion.totalViajes != null)
                        InfoPill(
                          icon: Icons.local_shipping_outlined,
                          text: '${_conciliacion.totalViajes} viajes',
                          mutedColor: mutedColor,
                          textColor: textColor,
                        ),
                      if (_conciliacion.totalArena != null && _conciliacion.totalArena! > 0)
                        InfoPill(
                          icon: Icons.grain,
                          text: '${_conciliacion.totalArena!.toStringAsFixed(1)} m³ arena',
                          mutedColor: mutedColor,
                          textColor: textColor,
                        ),
                      if (_conciliacion.totalGrava != null && _conciliacion.totalGrava! > 0)
                        InfoPill(
                          icon: Icons.landscape_outlined,
                          text: '${_conciliacion.totalGrava!.toStringAsFixed(1)} m³ grava',
                          mutedColor: mutedColor,
                          textColor: textColor,
                        ),
                      if (_conciliacion.totalAgua != null && _conciliacion.totalAgua! > 0)
                        InfoPill(
                          icon: Icons.water_drop_outlined,
                          text: '${_conciliacion.totalAgua!.toStringAsFixed(1)} m³ agua',
                          mutedColor: mutedColor,
                          textColor: textColor,
                        ),
                    ],
                  ),

                  if (_conciliacion.diferenciasDetectadas != null &&
                      _conciliacion.diferenciasDetectadas!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _conciliacion.diferenciasDetectadas!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total a Pagar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: mutedColor,
                        ),
                      ),
                      Text(
                        _conciliacion.totalAPagar != null
                            ? _moneda.format(_conciliacion.totalAPagar)
                            : '\$0.00',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Renglones header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Renglones de Conciliación',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                TextButton.icon(
                  onPressed: _abrirAgregarRenglon,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Renglones list
            FutureBuilder<List<ConciliacionDetalle>>(
              future: _detalleFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            'Error al cargar el detalle: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.mutedText(context)),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _recargar,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.rule_folder_outlined,
                              size: 40, color: AppColors.mutedText(context)),
                          const SizedBox(height: 8),
                          Text(
                            'No hay renglones registrados aún',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Usa el botón "+ Agregar" para registrar la conciliación de un vale vs entrada.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return DetalleConciliacionTile(detalle: items[index]);
                  },
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
