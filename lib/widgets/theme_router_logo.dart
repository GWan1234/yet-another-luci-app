// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// A widget that renders the router logo dynamically based on the current theme mode
/// (Light vs. Dark) of the user's device.
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        'assets/images/app_logo.png',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.router_rounded,
            size: width ?? 48,
            color: theme.colorScheme.primary,
          );
        },
      ),
    );
  }
}
