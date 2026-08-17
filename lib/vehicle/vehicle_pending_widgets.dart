import 'package:flutter/material.dart';

class SectionLabel extends StatelessWidget {
  final String text;
  final Color textColor;

  const SectionLabel({super.key, required this.text, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor));
  }
}

