import 'package:flutter/material.dart';

/// Gradient brand wordmark used anywhere the Orah name is presented as a logo.
class OrahWordmark extends StatelessWidget {
  const OrahWordmark({super.key, this.fontSize = 28, this.fontWeight = FontWeight.w500, this.textAlign = TextAlign.start});

  final double fontSize;
  final FontWeight fontWeight;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF9EDFB7), Color(0xFF83D0C9), Color(0xFF7AB8E8)],
      ).createShader(bounds),
      child: Text(
        'orah',
        textAlign: textAlign,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: -fontSize * 0.055,
          height: 1.05,
          color: Colors.white,
        ),
      ),
    );
  }
}
