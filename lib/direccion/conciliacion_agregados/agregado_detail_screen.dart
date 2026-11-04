import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import '../../catalogo/catalogo_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_feedback.dart';
import 'conciliacion_agregados_widgets.dart';

/// The three catalog types surfaced in this feature.
enum TipoAgregado { material, insumo, servicio }

/// Detail/edit screen for a material, insumo or servicio.
/// Pushed from `ConciliacionAgregadosScreen`; pops `true` when a record was
/// created or updated so the list refreshes.
class AgregadoDetailScreen extends StatefulWidget {
  /// `null` means "creating a new record" mode.
  final int? id;
  final TipoAgregado tipo;

  const AgregadoDetailScreen({super.key, this.id, required this.tipo});

  @override
  State<AgregadoDetailScreen> createState() => _AgregadoDetailScreenState();
}

class _AgregadoDetailScreenState extends State<AgregadoDetailScreen> {
  late final bool _esNuevo = widget.id == null;
  final bool _puedeAdministrar =
      AuthService.permisos.contains('catalogo.administrar');

  late final _nombreCtrl = TextEditingController();
  late final _unidadCtrl = TextEditingController();
  late final _categoriaCtrl = TextEditingController();
  late final _descripcionCtrl = TextEditingController();

  bool _cargando = true;
  bool _enviando = false;
  String? _errorCarga;
  String _estatus = '';

  @override
  void initState() {
    super.initState();
    if (_esNuevo) {
      _cargando = false;
    } else {
      _cargarDetalle();
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _unidadCtrl.dispose();
    _categoriaCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDetalle() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      switch (widget.tipo) {
        case TipoAgregado.material:
          final m = await CatalogoService.material(widget.id!);
          _nombreCtrl.text = m.nombre;
          _unidadCtrl.text = m.unidad;
          _descripcionCtrl.text = m.descripcion ?? '';
          _estatus = m.estatus;
          break;
        case TipoAgregado.insumo:
          final i = await CatalogoService.insumo(widget.id!);
          _nombreCtrl.text = i.nombre;
          _unidadCtrl.text = i.unidad;
          _categoriaCtrl.text = i.categoria ?? '';
          _descripcionCtrl.text = i.descripcion ?? '';
          _estatus = i.estatus;
          break;
        case TipoAgregado.servicio:
          final s = await CatalogoService.servicio(widget.id!);
          _nombreCtrl.text = s.nombre;
          _descripcionCtrl.text = s.descripcion ?? '';
          _estatus = s.estatus;
          break;
      }
    } on AuthException catch (e) {
      _errorCarga = e.message;
    } catch (_) {
      _errorCarga = 'No se pudo cargar el detalle';
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      AppSnack.error(context, 'El nombre es requerido');
      return;
    }
    if (widget.tipo != TipoAgregado.servicio && _unidadCtrl.text.trim().isEmpty) {
      AppSnack.error(context, 'La unidad es requerida');
      return;
    }

    setState(() => _enviando = true);
    try {
      if (_esNuevo) {
        await _crear(nombre);
      } else {
        await _actualizar(nombre);
      }
      if (!mounted) return;
      AppSnack.success(context, _esNuevo ? 'Registrado correctamente' : 'Actualizado correctamente');
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;
      AppSnack.error(context, e.message);
      setState(() => _enviando = false);
    }
  }

  Future<void> _crear(String nombre) async {
    switch (widget.tipo) {
      case TipoAgregado.material:
        await CatalogoService.crearMaterial(
          nombre: nombre,
          unidad: _unidadCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim(),
        );
        break;
      case TipoAgregado.insumo:
        await CatalogoService.crearInsumo(
          nombre: nombre,
          unidad: _unidadCtrl.text.trim(),
          categoria: _categoriaCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim(),
        );
        break;
      case TipoAgregado.servicio:
        await CatalogoService.crearServicio(
          nombre: nombre,
          descripcion: _descripcionCtrl.text.trim(),
        );
        break;
    }
  }

  Future<void> _actualizar(String nombre) async {
    switch (widget.tipo) {
      case TipoAgregado.material:
        await CatalogoService.actualizarMaterial(
          widget.id!,
          nombre: nombre,
          unidad: _unidadCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim(),
        );
        break;
      case TipoAgregado.insumo:
        await CatalogoService.actualizarInsumo(
          widget.id!,
          nombre: nombre,
          unidad: _unidadCtrl.text.trim(),
          categoria: _categoriaCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim(),
        );
        break;
      case TipoAgregado.servicio:
        await CatalogoService.actualizarServicio(
          widget.id!,
          nombre: nombre,
          descripcion: _descripcionCtrl.text.trim(),
        );
        break;
    }
  }

  String get _tituloTipo {
    switch (widget.tipo) {
      case TipoAgregado.material:
        return 'Material';
      case TipoAgregado.insumo:
        return 'Insumo';
      case TipoAgregado.servicio:
        return 'Servicio';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);

    Widget body;
    if (_cargando) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_errorCarga != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AgregadosMensaje(
            icon: Icons.error_outline,
            iconColor: Colors.redAccent,
            mensaje: _errorCarga!,
            onRetry: _cargarDetalle,
          ),
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (!_esNuevo && _estatus.isNotEmpty) ...[
            Row(
              children: [
                Text('Estatus', style: TextStyle(fontSize: 13, color: mutedColor)),
                const Spacer(),
                EstatusAgregadoChip(estatus: _estatus),
              ],
            ),
            const SizedBox(height: 20),
          ],
          AgregadoSeccion(
            titulo: _esNuevo ? 'Nuevo $_tituloTipo' : 'Datos del $_tituloTipo',
            children: [
              _buildTextField(
                controller: _nombreCtrl,
                label: 'Nombre *',
                hint: 'Ej: ${widget.tipo == TipoAgregado.material ? 'Arena' : widget.tipo == TipoAgregado.insumo ? 'Aceite motor' : 'Mantenimiento'}',
                enabled: _puedeAdministrar,
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              if (widget.tipo != TipoAgregado.servicio) ...[
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _unidadCtrl,
                  label: 'Unidad *',
                  hint: 'Ej: m³, kg, litro, pieza',
                  enabled: _puedeAdministrar,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ],
              if (widget.tipo == TipoAgregado.insumo) ...[
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _categoriaCtrl,
                  label: 'Categoría',
                  hint: 'Ej: refacciones, consumibles',
                  enabled: _puedeAdministrar,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ],
              const SizedBox(height: 12),
              _buildTextField(
                controller: _descripcionCtrl,
                label: 'Descripción',
                hint: 'Descripción opcional',
                maxLines: 3,
                enabled: _puedeAdministrar,
                textColor: textColor,
                mutedColor: mutedColor,
              ),
            ],
          ),
          if (!_esNuevo) ...[
            AgregadoSeccion(
              titulo: 'Información',
              children: [
                AgregadoDatoRow(label: 'ID', value: '${widget.id}'),
                AgregadoDatoRow(label: 'Tipo', value: _tituloTipo),
              ],
            ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_esNuevo ? 'Nuevo $_tituloTipo' : _tituloTipo),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: body,
      bottomNavigationBar: (_cargando || _errorCarga != null || !_puedeAdministrar)
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(color: AppColors.border(context)),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _enviando ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _enviando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            _esNuevo ? 'Registrar' : 'Guardar cambios',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool enabled,
    required Color textColor,
    required Color mutedColor,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: mutedColor)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: mutedColor.withValues(alpha: 0.5)),
            filled: true,
            fillColor: textColor.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
