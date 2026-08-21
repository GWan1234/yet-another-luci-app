// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// A modular, adaptive vector & asset router logo for Yet Another LuCI App.
/// Renders cleanly in both Light and Dark themes with orange accent details,
/// avoiding black-box artifacting and ensuring Play Store compliance.
class ThemeRouterLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool showShadow;

  const ThemeRouterLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;

    final double size = width ?? height ?? 80;

    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/app_logo_router_clean.png',
        width: size,
        height: size,
        fit: fit,
        color: theme.brightness == Brightness.dark ? Colors.white : colorScheme.onSurface,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/app_logo_transparent.png',
            width: size,
            height: size,
            fit: fit,
            color: theme.brightness == Brightness.dark ? Colors.white : colorScheme.onSurface,
            colorBlendMode: BlendMode.srcIn,
            errorBuilder: (context, error, stackTrace) {
              return CustomPaint(
                size: Size(size, size),
                painter: ModularRouterLogoPainter(
                  chassisColor: colorScheme.onSurface,
                  accentColor: primaryColor,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Modular vector router icon painter with Play Store compliant geometry and orange accents.
class ModularRouterLogoPainter extends CustomPainter {
  final Color chassisColor;
  final Color accentColor;

  ModularRouterLogoPainter({
    required this.chassisColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final chassisPaint = Paint()
      ..color = chassisColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;



    final dotPaint = Paint()
      ..color = chassisColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    final activeDotPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    // 1. Antennas (Left, Center, Right)
    // Left Antenna
    canvas.drawLine(
      Offset(w * 0.28, h * 0.48),
      Offset(w * 0.22, h * 0.28),
      chassisPaint,
    );
    // Center Antenna
    canvas.drawLine(
      Offset(w * 0.50, h * 0.44),
      Offset(w * 0.50, h * 0.22),
      chassisPaint,
    );
    // Right Antenna
    canvas.drawLine(
      Offset(w * 0.72, h * 0.48),
      Offset(w * 0.78, h * 0.28),
      chassisPaint,
    );



    // 3. Router Main Body / Chassis Base
    final RRect chassisBody = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.48, w * 0.72, h * 0.28),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(chassisBody, chassisPaint);

    // Bottom Stand Legs
    canvas.drawLine(
      Offset(w * 0.22, h * 0.76),
      Offset(w * 0.18, h * 0.84),
      chassisPaint,
    );
    canvas.drawLine(
      Offset(w * 0.78, h * 0.76),
      Offset(w * 0.82, h * 0.84),
      chassisPaint,
    );

    // 4. Front Status LED Indicators
    final double dotRadius = w * 0.025;
    final double dotY = h * 0.62;
    canvas.drawCircle(Offset(w * 0.32, dotY), dotRadius, activeDotPaint);
    canvas.drawCircle(Offset(w * 0.44, dotY), dotRadius, dotPaint);
    canvas.drawCircle(Offset(w * 0.56, dotY), dotRadius, dotPaint);
    canvas.drawCircle(Offset(w * 0.68, dotY), dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(covariant ModularRouterLogoPainter oldDelegate) {
    return oldDelegate.chassisColor != chassisColor ||
        oldDelegate.accentColor != accentColor;
  }
}
