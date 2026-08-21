import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'auth_service.dart';
import 'biometric_lock_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _controller;
  late final Future<bool> _restoreSessionFuture;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Kicked off in parallel with the video so the network round trip isn't
    // extra wait time on top of playback — by the time the video finishes
    // (or fails to load) this is almost always already settled.
    _restoreSessionFuture = AuthService.restoreSession();
    _controller = VideoPlayerController.asset('assets/video/splash.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      }).catchError((_) {
        _navigateNext();
      });
    _controller.addListener(_onVideoTick);
  }

  void _onVideoTick() {
    final value = _controller.value;
    if (value.isInitialized &&
        !value.isPlaying &&
        value.position >= value.duration) {
      _navigateNext();
    }
  }

  Future<void> _navigateNext() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    final restored = await _restoreSessionFuture;
    if (!mounted) return;
    final Widget destination;
    if (!restored) {
      destination = const LoginScreen();
    } else if (AuthService.biometricHabilitado) {
      destination = const BiometricLockScreen();
    } else {
      destination = destinationForSession();
    }
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => destination));
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Same color as the native launch screen (drawable/launch_background.xml,
      // LaunchScreen.storyboard) so there's no visible flash while the video
      // is still initializing.
      backgroundColor: const Color(0xFF15181B),
      body: _controller.value.isInitialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          : const SizedBox.expand(),
    );
  }
}
