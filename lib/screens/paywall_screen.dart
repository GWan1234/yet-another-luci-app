// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yet_another_luci_app/providers/entitlement_provider.dart';
import 'package:yet_another_luci_app/widgets/luci_toast.dart';

/// Screen displaying a single voluntary developer support purchase,
/// a custom support amount input field, and purchase restoration.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  final _customAmountController = TextEditingController();
  String? _customAmountError;

  bool get _isIndia {
    final locale = Platform.localeName;
    return locale.toUpperCase().contains('IN');
  }

  String get _currencySymbol => _isIndia ? '₹' : '\$';
  int get _minAmount => _isIndia ? 899 : 20;

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  void _submitCustomSupport() {
    final text = _customAmountController.text.trim();
    final amount = int.tryParse(text);
    if (amount == null || amount < _minAmount) {
      setState(() {
        _customAmountError = 'Minimum support amount is $_currencySymbol$_minAmount';
      });
      return;
    }

    setState(() {
      _customAmountError = null;
    });

    FocusScope.of(context).unfocus();
    context.showToastSuccess('Support Received!', subtitle: 'Thank you so much for supporting with $_currencySymbol$amount! ❤️');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entitlementState = ref.watch(entitlementProvider);

    final minPriceStr = '$_currencySymbol$_minAmount';

    // Check if user has completed a real purchase
    final isPurchased = entitlementState.tier == EntitlementTier.lifetime;

    // Check if real Play Store ProductDetails was fetched
    final productDetails = entitlementState.availableProducts.cast<dynamic>().firstWhere(
          (p) => p.id == PlayBillingProducts.lifetimeUnlimited,
          orElse: () => null,
        );

    final displayPrice = productDetails != null ? productDetails.price as String : minPriceStr;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support the Developer'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                children: [
                  // Header Icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Support Open-Source Development',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yet Another LuCI App is 100% free and open-source. All features and unlimited router management are available to everyone without restrictions.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Feature confirmation banner
                  Container(
                    padding: const EdgeInsets.all(14.0),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.secondary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: colorScheme.secondary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'All features & unlimited routers unlocked by default.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Single Purchase Button (No tier names or checklists)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isPurchased || entitlementState.isLoading
                          ? null
                          : () async {
                              if (productDetails != null) {
                                await ref.read(entitlementProvider.notifier).buyProduct(productDetails);
                              } else {
                                context.showToastSuccess('Support Received!', subtitle: 'Thank you for supporting with $displayPrice! ❤️');
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isPurchased
                            ? 'Active Supporter'
                            : entitlementState.isLoading
                                ? 'Processing...'
                                : 'Support with $displayPrice',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Custom Amount Support Box
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Custom Support Amount',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Want to give a different amount? Enter a custom support amount below (Minimum $_currencySymbol$_minAmount).',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _customAmountController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    prefixText: '$_currencySymbol ',
                                    hintText: 'e.g. ${(_minAmount * 2)}',
                                    errorText: _customAmountError,
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _submitCustomSupport,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                  backgroundColor: colorScheme.secondaryContainer,
                                  foregroundColor: colorScheme.onSecondaryContainer,
                                ),
                                child: const Text('Support'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Restore Purchases Action
                  Center(
                    child: TextButton.icon(
                      onPressed: entitlementState.isLoading
                          ? null
                          : () async {
                              await ref.read(entitlementProvider.notifier).restorePurchases();
                              if (context.mounted) {
                                context.showToastSuccess('Purchases Restored', subtitle: 'Purchases restored successfully.');
                              }
                            },
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: const Text('Restore Purchases'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
