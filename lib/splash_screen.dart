import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  void _navigateToLogin() async {
    // Wait for 3 seconds before navigating
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          // Dark overlay similar to login screen
          color: Colors.black.withOpacity(0.4),
          child: Center(
            // Sin animación de entrada: la pantalla nativa de arranque ya
            // muestra este mismo logo, por lo que debe verse idéntico desde
            // el primer frame para que se perciba como una sola pantalla.
            child: Image.asset(
              'assets/images/logo.png',
              width: 250,
              // Fallback icon in case logo is missing or loading fails
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.business,
                  color: Color(0xFFFFCC00),
                  size: 100,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
