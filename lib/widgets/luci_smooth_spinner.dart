// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// A smooth, constant-speed 360° circular progress spinner for Yet Another LuCI App.
/// Replaces standard indeterminate CircularProgressIndicator (which accelerates and decelerates
/// giving a "boomerang" rubber-banding effect) with a fluid, continuous rotation.
class LuciSmoothSpinner extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color? color;
  final double strokeAlign;

  const LuciSmoothSpinner({
    super.key,
    this.size = 24.0,
    this.strokeWidth = 2.5,
    this.color,
    this.strokeAlign = CircularProgressIndicator.strokeAlignCenter,
  });

  @override
  State<LuciSmoothSpinner> createState() => _LuciSmoothSpinnerState();
}

class _LuciSmoothSpinnerState extends State<LuciSmoothSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spinnerColor = widget.color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RepaintBoundary(
        child: RotationTransition(
          turns: _controller,
          child: CircularProgressIndicator(
            strokeWidth: widget.strokeWidth,
            strokeCap: StrokeCap.round,
            strokeAlign: widget.strokeAlign,
            value: 0.72,
            valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
            backgroundColor: spinnerColor.withValues(alpha: 0.16),
          ),
        ),
      ),
    );
  }
}
