import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';

const _accentYellow = AppColors.accent;

/// Digital signature capture for a delivery: the person receiving in obra
/// signs on-screen with a finger/stylus, backed by `RemisionFirma`. The pad
/// takes up most of the screen — signing is the whole point of this view —
/// with "Limpiar" to reset and try again if it came out wrong, and "Aceptar
/// firma" to confirm.
///
/// Accepting: renders the pad to a PNG, requests a presigned upload URL
/// (`POST /evidencias/presigned-url`), `PUT`s the bytes there directly, then
/// registers the signature (`POST /remisiones/{id}/firma`) with the
/// resulting `publicUrl`. Requires [permisoOperarRemisiones].
///
/// `FirmaRequest.operadorId` would be the id of whoever receives at the job
/// site, but this app has no lookup against `administracion-service` to
/// resolve a name to that id — and the field isn't schema-required — so it's
/// omitted; the driver's hand-typed name goes in `comentarios` instead.
class SignatureScreen extends StatefulWidget {
  final int remisionId;
  final String remisionFolio;

  const SignatureScreen({super.key, required this.remisionId, required this.remisionFolio});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final _nameController = TextEditingController();
  final List<List<Offset>> _strokes = [];
  final _signatureKey = GlobalKey();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() => _strokes.add([details.localPosition]));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _strokes.last.add(details.localPosition));
  }

  void _clear() => setState(() => _strokes.clear());

  Future<void> _accept() async {
    if (_strokes.isEmpty) {
      setState(() => _errorText = 'Falta capturar la firma');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final boundary = _signatureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final nombreArchivo = 'firma_${widget.remisionId}_${DateTime.now().millisecondsSinceEpoch}.png';
      final presigned = await OperacionesService.presignedUploadUrl(
        carpeta: 'remision-firmas',
        nombreArchivo: nombreArchivo,
        contentType: 'image/png',
      );
      await OperacionesService.subirArchivoPresignado(presigned.uploadUrl, pngBytes, 'image/png');
      final nombre = _nameController.text.trim();
      await OperacionesService.registrarFirma(
        widget.remisionId,
        firmaDigitalUrl: presigned.publicUrl,
        comentarios: nombre.isEmpty ? null : 'Recibido por: $nombre',
      );

      if (!mounted) return;
      AppSnack.success(context, 'Firma guardada');
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.12);
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.045);

    return Scaffold(
      appBar: AppBar(
        title: Text('Firma · ${widget.remisionFolio}'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              Text(
                'Pide a quien recibe que firme para confirmar la entrega',
                style: TextStyle(fontSize: 13.5, color: mutedColor),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Nombre de quien recibe',
                  prefixIcon: const Icon(Icons.person_outline, size: 20, color: _accentYellow),
                  filled: true,
                  fillColor: fillColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _accentYellow, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // The signature pad: the main event of this screen, so it
              // gets whatever vertical space is left over.
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: RepaintBoundary(
                      key: _signatureKey,
                      child: Stack(
                        children: [
                          Container(color: Colors.white),
                          if (_strokes.isEmpty)
                            const Center(
                              child: Text('Firme aquí', style: TextStyle(color: Colors.black26, fontSize: 16)),
                            ),
                          GestureDetector(
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            child: CustomPaint(
                              painter: _SignaturePainter(_strokes),
                              size: Size.infinite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _clear,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Limpiar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _accept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentYellow,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: _accentYellow.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                            )
                          : const Text('Aceptar firma', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      for (var i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
