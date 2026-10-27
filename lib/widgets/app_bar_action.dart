import 'package:blast_qr/color_scheme.dart';
import 'package:flutter/material.dart';

class AppBarAction extends StatelessWidget {
  const AppBarAction({super.key, required this.icon, required this.onPressed});

  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
        style: IconButton.styleFrom(
          backgroundColor: context.color.primaryContainer,
          foregroundColor: context.color.onPrimaryContainer,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.4),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}
