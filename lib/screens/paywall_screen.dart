import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/providers/entitlement_provider.dart';

/// Screen displaying voluntary developer support options with country-specific localization,
/// minimum threshold ($20 USD / ₹899 INR), custom support amount entry, and purchase restoration.
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
    ref.read(entitlementProvider.notifier).updateEntitlement(EntitlementTier.lifetime);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Thank you so much for supporting with $_currencySymbol$amount! ❤️'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entitlement = ref.watch(entitlementProvider);

    final minPriceStr = _isIndia ? '₹899' : '\$20';
    final generousPriceStr = _isIndia ? '₹1,999' : '\$50';
    final championPriceStr = _isIndia ? '₹3,999' : '\$100';

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
                  const SizedBox(height: 24),

                  // Main Recommended Support Tier (Minimum Support)
                  _buildTierCard(
                    context,
                    ref,
                    title: 'Developer Supporter',
                    price: '$minPriceStr one-time',
                    productId: PlayBillingProducts.lifetimeUnlimited,
                    limitDescription: 'Direct support for continuous updates & maintenance (Min. $minPriceStr)',
                    badgeText: 'MINIMUM SUPPORT',
                    isCurrent: entitlement.tier == EntitlementTier.lifetime,
                    isHighlight: true,
                    tier: EntitlementTier.lifetime,
                  ),
                  const SizedBox(height: 14),

                  // Preset Tier Options
                  Row(
                    children: [
                      Expanded(
                        child: _buildSmallTipCard(
                          context,
                          ref,
                          title: 'Generous',
                          price: generousPriceStr,
                          productId: PlayBillingProducts.plusMonthly,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSmallTipCard(
                          context,
                          ref,
                          title: 'Champion',
                          price: championPriceStr,
                          productId: PlayBillingProducts.proMonthly,
                        ),
                      ),
                    ],
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
                            'Want to give more? Enter a custom support amount (Minimum $_currencySymbol$_minAmount).',
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
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
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
                      onPressed: entitlement.isLoading
                          ? null
                          : () async {
                              await ref.read(entitlementProvider.notifier).restorePurchases();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Purchases restored successfully.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
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

  Widget _buildTierCard(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String price,
    required String productId,
    required String limitDescription,
    required String badgeText,
    required EntitlementTier tier,
    bool isCurrent = false,
    bool isHighlight = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entitlementState = ref.watch(entitlementProvider);

    final productDetails = entitlementState.availableProducts.cast<dynamic>().firstWhere(
          (p) => p.id == productId,
          orElse: () => null,
        );

    final displayPrice = productDetails != null ? productDetails.price as String : price;

    return Card(
      elevation: isHighlight ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: isHighlight
              ? colorScheme.primary
              : isCurrent
                  ? colorScheme.outline
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: isHighlight || isCurrent ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHighlight
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isHighlight
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              displayPrice,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle_outline, size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    limitDescription,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.block_flipped, size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  '100% Ad-Free Interface',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isCurrent
                    ? null
                    : () async {
                        if (productDetails != null) {
                          await ref.read(entitlementProvider.notifier).buyProduct(productDetails);
                        } else {
                          await ref.read(entitlementProvider.notifier).updateEntitlement(tier);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Thank you for supporting Yet Another LuCI App! ($displayPrice)'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isHighlight ? colorScheme.primary : null,
                  foregroundColor: isHighlight ? colorScheme.onPrimary : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  isCurrent
                      ? 'Active Supporter'
                      : entitlementState.isLoading
                          ? 'Processing...'
                          : 'Support ($displayPrice)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallTipCard(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String price,
    required String productId,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entitlementState = ref.watch(entitlementProvider);

    final productDetails = entitlementState.availableProducts.cast<dynamic>().firstWhere(
          (p) => p.id == productId,
          orElse: () => null,
        );

    final displayPrice = productDetails != null ? productDetails.price as String : price;

    return OutlinedButton(
      onPressed: entitlementState.isLoading
          ? null
          : () async {
              if (productDetails != null) {
                await ref.read(entitlementProvider.notifier).buyProduct(productDetails);
              } else {
                await ref.read(entitlementProvider.notifier).updateEntitlement(EntitlementTier.lifetime);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Thank you for supporting with $title ($displayPrice)! ❤️'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        '$title ($displayPrice)',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}
