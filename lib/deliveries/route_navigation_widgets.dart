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

/// This app's own exit affordance, floating over the native navigation
/// view's own header/footer chrome rather than replacing it — its
/// background is transparent (unlike a plain bottom sheet) specifically so
/// the SDK's own ETA/footer card, speedometer, and trip-progress-bar stay
/// visible underneath it instead of being covered by an opaque bar. Always
/// tappable — arrival flips its look from a quiet outline to a filled
/// "Ruta terminada", but either state pops back to the delivery detail
/// immediately via [onFinish], with no exit confirmation: a deliberate tap
/// on this labeled button already is the driver's confirmation, unlike the
/// screen's separate back arrow.
///
/// This widget (and the floating back button) also turned out to matter for
/// the native view's own sizing, not just its own visual role: removing it
/// from the `Stack` entirely (an earlier attempt at fixing the coverage
/// problem above) made the whole native navigation view collapse to a tiny
/// box in a corner on a real device instead of filling the screen. The
/// mechanism isn't documented by the plugin, but empirically this app's own
/// Stack needs at least this non-positioned, full-width child present for
/// the platform view to size correctly — so the fix here is to make it
/// visually transparent, not to remove it.
class RouteNavBottomBar extends StatelessWidget {
  final bool arrived;
  final VoidCallback onFinish;

  const RouteNavBottomBar({super.key, required this.arrived, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Matches RouteNavigationScreen's `initialPadding.bottom` (the zone
      // reserved along the bottom of the map for the SDK's own footer/ETA
      // card) so this button sits vertically centered in that same band,
      // next to the native minutes/distance readout, instead of down at the
      // screen's physical bottom edge below it.
      height: 96 + MediaQuery.of(context).padding.bottom,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerRight,
        child: arrived
            ? ElevatedButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.check_circle, color: Colors.black),
                label: const Text('Ruta terminada', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentYellow,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )
            : OutlinedButton(
                onPressed: onFinish,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.55),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Finalizar ruta', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
      ),
    );
  }
}
