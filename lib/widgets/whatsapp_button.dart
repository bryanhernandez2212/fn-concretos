import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_feedback.dart';

const _whatsappGreen = Color(0xFF25D366);

/// Opens a WhatsApp chat with [telefono] via the `wa.me` deep link (works
/// whether or not WhatsApp is installed — falls back to the web client).
/// `telefono` comes back from the backend as a plain national number without
/// a country code (e.g. `"9611234501"`), so Mexico's country code (`52`) is
/// prefixed before building the link.
Future<void> abrirWhatsApp(BuildContext context, String telefono) async {
  final digits = telefono.replaceAll(RegExp(r'\D'), '');
  final numero = digits.startsWith('52') ? digits : '52$digits';
  final abierto = await launchUrl(Uri.parse('https://wa.me/$numero'), mode: LaunchMode.externalApplication);
  if (!abierto && context.mounted) {
    AppSnack.error(context, 'No se pudo abrir WhatsApp');
  }
}

/// Small outlined button that opens [abrirWhatsApp] for [telefono] — used
/// wherever a screen shows a cliente's contact info with
/// `whatsappDisponible == true` (`direccion/PedidoDetailScreen`,
/// `deliveries/DeliveryDetailScreen`).
class WhatsappButton extends StatelessWidget {
  final String telefono;

  const WhatsappButton({super.key, required this.telefono});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => abrirWhatsApp(context, telefono),
      style: OutlinedButton.styleFrom(
        foregroundColor: _whatsappGreen,
        side: const BorderSide(color: _whatsappGreen),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16),
      label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
    );
  }
}
