import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

const _accentYellow = AppColors.accent;

class RouteNavBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const RouteNavBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
    );
  }
}

/// This app's own exit affordance, sitting below the native navigation
/// view's own header/footer chrome (see [RouteNavigationScreen]'s
/// `initialPadding`). Always tappable — arrival flips its look from a quiet
/// outline to a filled "Ruta terminada", but either state pops back to the
/// delivery detail.
class RouteNavBottomBar extends StatelessWidget {
  final bool arrived;
  final VoidCallback onFinish;

  const RouteNavBottomBar({super.key, required this.arrived, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: arrived
            ? ElevatedButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.check_circle, color: Colors.black),
                label: const Text('Ruta terminada', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentYellow,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )
            : OutlinedButton(
                onPressed: onFinish,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Finalizar ruta', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
      ),
    );
  }
}
