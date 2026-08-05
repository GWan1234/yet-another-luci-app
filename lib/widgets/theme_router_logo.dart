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
    final isDark = theme.brightness == Brightness.dark;
    
    Widget imageWidget = ClipRRect(
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

    if (showShadow) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.cyan : Colors.blue).withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
