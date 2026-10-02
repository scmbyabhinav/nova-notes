import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The approved Orah launcher mark, reused wherever the brand icon appears.
class OrahLogo extends StatelessWidget {
  const OrahLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: SvgPicture.asset(
          'assets/orah_app_icon.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
          semanticsLabel: 'Orah logo',
        ),
      );
}
