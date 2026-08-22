// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../core/luci_module.dart';
import 'screens/parental_controls_screen.dart';

class ParentalControlsModule extends LuciModule {
  @override
  String get id => 'parental_controls';

  @override
  String get name => 'Parental Controls';

  @override
  String get description =>
      'Per-device internet scheduling, daily time limits, and content filtering';

  @override
  IconData get icon => Icons.family_restroom_outlined;

  @override
  IconData get selectedIcon => Icons.family_restroom;

  @override
  LuciModuleCategory get category => LuciModuleCategory.security;

  @override
  int get priority => 35;

  @override
  Widget buildScreen(BuildContext context, {Map<String, dynamic>? params}) {
    return const ParentalControlsScreen();
  }
}
