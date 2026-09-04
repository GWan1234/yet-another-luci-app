// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:yet_another_luci_app/config/app_config.dart';
import 'package:yet_another_luci_app/design/luci_design_system.dart';
import 'package:yet_another_luci_app/providers/supporter_provider.dart';
import 'package:yet_another_luci_app/widgets/luci_toast.dart';

// ---------------------------------------------------------------------------
// Locale-to-currency data model
// ---------------------------------------------------------------------------

/// Currency configuration for a supported locale region.
class _SupportCurrencyConfig {
  final String symbol;
  final String name;
  final List<int> presetAmounts;
  final int minAmount;
  final int maxAmount;
  final bool showUpi;

  const _SupportCurrencyConfig({
    required this.symbol,
    required this.name,
    required this.presetAmounts,
    required this.minAmount,
    required this.maxAmount,
    this.showUpi = false,
  });
}

// Default USD fallback config.
const _usdConfig = _SupportCurrencyConfig(
  symbol: r'$',
  name: 'USD',
  presetAmounts: [12, 24, 60, 120],
  minAmount: 10,
  maxAmount: 1000,
);

/// Country-code (2-letter ISO) -> currency config.
/// Locale strings from [Platform.localeName] look like "en_IN", "de_DE", "pt_BR".
const Map<String, _SupportCurrencyConfig> _localeCurrencyMap = {
  // South Asia
  'IN': _SupportCurrencyConfig(
    symbol: '₹',
    name: 'INR',
    presetAmounts: [1000, 2000, 5000, 10000],
    minAmount: 500,
    maxAmount: 82500,
    showUpi: true,
  ),
  // Euro Zone
  'DE': _SupportCurrencyConfig(
    symbol: '€',
    name: 'EUR',
    presetAmounts: [10, 20, 50, 100],
    minAmount: 5,
    maxAmount: 500,
  ),
  'FR': _SupportCurrencyConfig(
    symbol: '€',
    name: 'EUR',
    presetAmounts: [10, 20, 50, 100],
    minAmount: 5,
    maxAmount: 500,
  ),
  'IT': _SupportCurrencyConfig(
    symbol: '€',
    name: 'EUR',
    presetAmounts: [10, 20, 50, 100],
    minAmount: 5,
    maxAmount: 500,
  ),
  'ES': _SupportCurrencyConfig(
    symbol: '€',
    name: 'EUR',
    presetAmounts: [10, 20, 50, 100],
    minAmount: 5,
    maxAmount: 500,
  ),
  'NL': _SupportCurrencyConfig(
    symbol: '€',
    name: 'EUR',
    presetAmounts: [10, 20, 50, 100],
    minAmount: 5,
    maxAmount: 500,
  ),
  'AT': _SupportCurrencyConfig(
    symbol: '€',
    name: 'EUR',
    presetAmounts: [10, 20, 50, 100],
    minAmount: 5,
    maxAmount: 500,
  ),
  // United Kingdom
  'GB': _SupportCurrencyConfig(
    symbol: '£',
    name: 'GBP',
    presetAmounts: [10, 20, 50, 100],
    minAmount: 5,
    maxAmount: 500,
  ),
  // Canada
  'CA': _SupportCurrencyConfig(
    symbol: r'CA$',
    name: 'CAD',
    presetAmounts: [15, 30, 70, 140],
    minAmount: 8,
    maxAmount: 700,
  ),
  // Australia
  'AU': _SupportCurrencyConfig(
    symbol: r'A$',
    name: 'AUD',
    presetAmounts: [18, 35, 90, 180],
    minAmount: 10,
    maxAmount: 900,
  ),
  // Japan
  'JP': _SupportCurrencyConfig(
    symbol: '¥',
    name: 'JPY',
    presetAmounts: [1500, 3000, 7500, 15000],
    minAmount: 800,
    maxAmount: 75000,
  ),
  // South Korea
  'KR': _SupportCurrencyConfig(
    symbol: '₩',
    name: 'KRW',
    presetAmounts: [15000, 30000, 75000, 150000],
    minAmount: 8000,
    maxAmount: 750000,
  ),
  // Brazil
  'BR': _SupportCurrencyConfig(
    symbol: r'R$',
    name: 'BRL',
    presetAmounts: [50, 100, 250, 500],
    minAmount: 25,
    maxAmount: 2500,
  ),
  // Mexico
  'MX': _SupportCurrencyConfig(
    symbol: r'MX$',
    name: 'MXN',
    presetAmounts: [200, 400, 1000, 2000],
    minAmount: 100,
    maxAmount: 10000,
  ),
  // Singapore
  'SG': _SupportCurrencyConfig(
    symbol: r'S$',
    name: 'SGD',
    presetAmounts: [16, 32, 80, 160],
    minAmount: 8,
    maxAmount: 800,
  ),
  // Russia
  'RU': _SupportCurrencyConfig(
    symbol: '₽',
    name: 'RUB',
    presetAmounts: [1000, 2000, 5000, 10000],
    minAmount: 500,
    maxAmount: 50000,
  ),
  // Turkey
  'TR': _SupportCurrencyConfig(
    symbol: '₺',
    name: 'TRY',
    presetAmounts: [350, 700, 1750, 3500],
    minAmount: 175,
    maxAmount: 17500,
  ),
  // UAE
  'AE': _SupportCurrencyConfig(
    symbol: 'AED',
    name: 'AED',
    presetAmounts: [45, 90, 225, 450],
    minAmount: 22,
    maxAmount: 2250,
  ),
  // Saudi Arabia
  'SA': _SupportCurrencyConfig(
    symbol: 'SAR',
    name: 'SAR',
    presetAmounts: [45, 90, 225, 450],
    minAmount: 22,
    maxAmount: 2250,
  ),
  // Switzerland
  'CH': _SupportCurrencyConfig(
    symbol: 'CHF',
    name: 'CHF',
    presetAmounts: [12, 24, 60, 120],
    minAmount: 6,
    maxAmount: 600,
  ),
  // Sweden
  'SE': _SupportCurrencyConfig(
    symbol: 'kr',
    name: 'SEK',
    presetAmounts: [120, 240, 600, 1200],
    minAmount: 60,
    maxAmount: 6000,
  ),
  // Norway
  'NO': _SupportCurrencyConfig(
    symbol: 'kr',
    name: 'NOK',
    presetAmounts: [120, 240, 600, 1200],
    minAmount: 60,
    maxAmount: 6000,
  ),
  // Poland
  'PL': _SupportCurrencyConfig(
    symbol: 'zł',
    name: 'PLN',
    presetAmounts: [50, 100, 250, 500],
    minAmount: 25,
    maxAmount: 2500,
  ),
};

/// Resolve currency config from current device locale.
/// Falls back to USD for any unrecognised locale.
_SupportCurrencyConfig _resolveCurrencyConfig() {
  try {
    final locale = Platform.localeName.toUpperCase();
    // Locale is typically "en_IN", "de_DE", "pt_BR" — extract the country code
    final parts = locale.split(RegExp(r'[_\-]'));
    final countryCode = parts.length >= 2 ? parts.last : parts.first;
    return _localeCurrencyMap[countryCode] ?? _usdConfig;
  } catch (_) {
    return _usdConfig;
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Screen allowing voluntary developer support through preset amounts, custom amounts,
/// Google Play Store IAP (playstore flavor), or external payment channels (community flavor).
class SupportTheDevScreen extends ConsumerStatefulWidget {
  const SupportTheDevScreen({super.key});

  @override
  ConsumerState<SupportTheDevScreen> createState() =>
      _SupportTheDevScreenState();
}

class _SupportTheDevScreenState extends ConsumerState<SupportTheDevScreen> {
  final TextEditingController _customAmountController =
      TextEditingController();
  int? _selectedPresetAmount;
  String? _customAmountError;

  /// Resolved once per screen lifecycle — locale does not change at runtime.
  late final _SupportCurrencyConfig _currency = _resolveCurrencyConfig();

  String get _currencySymbol => _currency.symbol;
  int get _minAmount => _currency.minAmount;
  int get _maxAmount => _currency.maxAmount;
  List<int> get _presetAmounts => _currency.presetAmounts;
  bool get _showUpi => _currency.showUpi;

  @override
  void initState() {
    super.initState();
    _selectedPresetAmount = _presetAmounts.first;
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  void _validateAndProcessCustomAmount(int amount) {
    if (amount < _minAmount) {
      setState(() {
        _customAmountError =
            'Minimum support amount is $_currencySymbol$_minAmount';
      });
      return;
    }
    if (amount > _maxAmount) {
      setState(() {
        _customAmountError =
            'Maximum support amount is $_currencySymbol$_maxAmount per transaction';
      });
      return;
    }

    setState(() {
      _customAmountError = null;
    });

    FocusScope.of(context).unfocus();

    // Custom amounts are only available on community flavor.
    // Play Store flavor hides the custom amount card entirely per billing policy.
    if (AppConfig.razorpayUrl.isNotEmpty) {
      _launchExternalPaymentUrl(AppConfig.razorpayUrl, 'Razorpay');
    }
    _showCommunityManualConfirmationDialog(amount);
  }

  void _submitPresetSupport(int amount) {
    if (AppConfig.isMonetizationEnabled) {
      final index = _presetAmounts.indexOf(amount);
      final productId = SupporterProducts.getProductIdForIndex(index);
      ref.read(supporterProvider.notifier).initiatePurchase(productId);
    } else {
      if (AppConfig.razorpayUrl.isNotEmpty) {
        _launchExternalPaymentUrl(AppConfig.razorpayUrl, 'Razorpay');
      }
      _showCommunityManualConfirmationDialog(amount);
    }
  }

  void _showCommunityManualConfirmationDialog(int amount) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Support'),
          content: Text(
            'Have you completed your payment of $_currencySymbol$amount using an external payment method?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(supporterProvider.notifier).markAsSupported();
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _showThankYouBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Padding(
          padding: const EdgeInsets.all(LuciSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  size: 48,
                  color: Colors.pink.shade400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Thank You! ❤️',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your voluntary contribution helps maintain and improve Yet Another LuCI App for everyone.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context); // Pop bottom sheet
                    if (mounted && Navigator.canPop(context)) {
                      Navigator.pop(context); // Pop support screen
                    }
                  },
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchExternalPaymentUrl(
    String url,
    String methodName,
  ) async {
    if (url.trim().isEmpty) {
      context.showToastInfo(
        'Coming Soon',
        subtitle:
            '$methodName payment integration is being finalized. Thank you for your patience!',
      );
      return;
    }

    try {
      final launched = await launchUrlString(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        context.showToastError(
          'Error',
          subtitle: 'Could not launch $methodName payment link.',
        );
      }
    } catch (e) {
      if (mounted) {
        context.showToastError(
          'Error',
          subtitle: 'Could not launch $methodName payment link.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final supporterState = ref.watch(supporterProvider);

    // Error listener
    ref.listen<SupporterState>(supporterProvider, (previous, next) {
      if (next.errorMessage != null) {
        context.showToastError(
          'Support Action Failed',
          subtitle: next.errorMessage!,
        );
        ref.read(supporterProvider.notifier).clearError();
      }

      // Check if user just became a supporter or added support count
      if ((previous?.supportCount ?? 0) < next.supportCount &&
          next.hasSupportedAtLeastOnce) {
        _showThankYouBottomSheet(context);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support the Developer'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: LuciSpacing.lg,
            vertical: LuciSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon & Greeting
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade500.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 48,
                    color: Colors.pink.shade400,
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
                'Yet Another LuCI App is 100% free and open-source. All features and router management remain available to everyone without restrictions.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Supporter Banner if supported before
              if (supporterState.hasSupportedAtLeastOnce) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.pink.shade400.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        color: Colors.pink.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Thank you for your past support! ❤️ Feel free to support again anytime.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Preset Selection Section
              Text(
                'Choose Support Amount',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetAmounts.map((amount) {
                  final isSelected = _selectedPresetAmount == amount;
                  final width = (MediaQuery.of(context).size.width - (LuciSpacing.lg * 2) - 8) / 2;
                  return SizedBox(
                    width: width > 120 ? width : 120,
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          '$_currencySymbol$amount',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: colorScheme.primary,
                      onSelected: supporterState.isLoading
                          ? null
                          : (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedPresetAmount = amount;
                                });
                              }
                            },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Submit Selected Preset Button
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: supporterState.isLoading ||
                          _selectedPresetAmount == null
                      ? null
                      : () => _submitPresetSupport(_selectedPresetAmount!),
                  icon: supporterState.isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.favorite_outline),
                  label: Text(
                    supporterState.isLoading
                        ? 'Processing...'
                        : 'Support with $_currencySymbol${_selectedPresetAmount ?? _presetAmounts.first}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Play Store billing policy note (playstore flavor only)
              if (AppConfig.isMonetizationEnabled) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Payments are processed securely via Google Play. Community builds support additional payment options.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Custom Amount Card — community flavor only
              // Hidden on Play Store flavor: Google Play billing policy prohibits
              // directing IAP users to external payment methods for digital goods.
              if (!AppConfig.isMonetizationEnabled) ...[
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                          'Enter a custom amount (Min $_currencySymbol$_minAmount, Max $_currencySymbol$_maxAmount).',
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
                                enabled: !supporterState.isLoading,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  prefixText: '$_currencySymbol ',
                                  hintText: 'e.g. ${(_minAmount * 3)}',
                                  errorText: _customAmountError,
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: supporterState.isLoading
                                  ? null
                                  : () {
                                      final text =
                                          _customAmountController.text.trim();
                                      final amt = int.tryParse(text);
                                      if (amt == null) {
                                        setState(() {
                                          _customAmountError =
                                              'Please enter a valid number';
                                        });
                                      } else {
                                        _validateAndProcessCustomAmount(amt);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                backgroundColor: colorScheme.secondaryContainer,
                                foregroundColor:
                                    colorScheme.onSecondaryContainer,
                              ),
                              child: const Text('Submit'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Community flavor external payment options.
              // Hidden on Play Store flavor per Google Play billing policy.
              if (!AppConfig.isMonetizationEnabled) ...[
                const SizedBox(height: 24),
                Text(
                  'Community Direct Support',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select your preferred external payment provider:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                // Razorpay Payment Page option (Community edition)
                if (AppConfig.razorpayUrl.isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchExternalPaymentUrl(
                        AppConfig.razorpayUrl,
                        'Razorpay',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                      ),
                      icon: const Icon(Icons.payment_rounded, size: 18),
                      label: const Text(
                        'Support via Razorpay (UPI / Cards / Netbanking)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // Row 1: Stripe / PayPal / Wise
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _launchExternalPaymentUrl(
                          AppConfig.stripeUrl,
                          'Stripe',
                        ),
                        icon: const Icon(Icons.payment, size: 16),
                        label: const Text('Stripe'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _launchExternalPaymentUrl(
                          AppConfig.paypalUrl,
                          'PayPal',
                        ),
                        icon: const Icon(
                          Icons.account_balance_wallet,
                          size: 16,
                        ),
                        label: const Text('PayPal'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _launchExternalPaymentUrl(
                          AppConfig.wiseUrl,
                          'Wise',
                        ),
                        icon: const Icon(Icons.swap_horiz, size: 16),
                        label: const Text('Wise'),
                      ),
                    ),
                  ],
                ),
                // Row 2: UPI (India locale only, per currency config)
                if (_showUpi) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _launchExternalPaymentUrl(
                        AppConfig.upiUrl,
                        'UPI',
                      ),
                      icon: const Icon(Icons.currency_rupee, size: 16),
                      label: const Text('Pay via UPI'),
                    ),
                  ),
                ],
              ],

              // Restore Purchases button (Play Store flavor only)
              if (AppConfig.isMonetizationEnabled) ...[
                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    onPressed: supporterState.isLoading
                        ? null
                        : () => ref
                            .read(supporterProvider.notifier)
                            .restorePurchases(),
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: const Text('Restore Support'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
