import 'package:flutter/material.dart';

const _accentYellow = Color(0xFFFFCC00);

/// Digital signature capture for a delivery: the client signs on-screen
/// with a finger/stylus, backed by `RemisionFirma`. The pad takes up most
/// of the screen — signing is the whole point of this view — with
/// "Limpiar" to reset and try again if it came out wrong, and "Aceptar
/// firma" to confirm. Purely local drawing — accepting just pops back with
/// a confirmation until the endpoint is wired.
class SignatureScreen extends StatefulWidget {
  final String remisionFolio;

  const SignatureScreen({super.key, required this.remisionFolio});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final _nameController = TextEditingController();
  final List<List<Offset>> _strokes = [];

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

  void _accept() {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falta capturar la firma')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Firma guardada (demostración)')),
    );
    Navigator.of(context).pop();
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
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : _accentYellow,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              Text(
                'Pide al cliente que firme para confirmar la entrega',
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
                    child: Stack(
                      children: [
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
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _clear,
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
                      onPressed: _accept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentYellow,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Aceptar firma', style: TextStyle(fontWeight: FontWeight.w700)),
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
