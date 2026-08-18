import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/video/splash.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      }).catchError((_) {
        _navigateToLogin();
      });
    _controller.addListener(_onVideoTick);
  }

  void _onVideoTick() {
    final value = _controller.value;
    if (value.isInitialized &&
        !value.isPlaying &&
        value.position >= value.duration) {
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => const LoginScreen()));
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
