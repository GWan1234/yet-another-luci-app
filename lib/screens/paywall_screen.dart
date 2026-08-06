import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/providers/entitlement_provider.dart';

/// Modal or screen displaying subscription & lifetime purchase options,
/// tier comparison matrix, and Play Store restore purchases flow.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entitlement = ref.watch(entitlementProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Subscription'),
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
                  // Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Unlock Multi-Router Management',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage multiple OpenWrt routers seamlessly without ads.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Current Tier Status Pill
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Current Plan: ${entitlement.tier.displayName}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tier Options List
                  _buildTierCard(
                    context,
                    ref,
                    title: 'Plus Plan',
                    price: '\$0.99 / month',
                    productId: PlayBillingProducts.plusMonthly,
                    limitDescription: 'Up to 3 OpenWrt Routers',
                    badgeText: 'POPULAR',
                    isCurrent: entitlement.tier == EntitlementTier.plus,
                    tier: EntitlementTier.plus,
                  ),
                  const SizedBox(height: 16),
                  _buildTierCard(
                    context,
                    ref,
                    title: 'Pro Plan',
                    price: '\$1.99 / month',
                    productId: PlayBillingProducts.proMonthly,
                    limitDescription: 'Unlimited OpenWrt Routers',
                    badgeText: 'POWER USER',
                    isCurrent: entitlement.tier == EntitlementTier.pro,
                    tier: EntitlementTier.pro,
                  ),
                  const SizedBox(height: 16),
                  _buildTierCard(
                    context,
                    ref,
                    title: 'Lifetime Pass',
                    price: '\$9.99 one-time',
                    productId: PlayBillingProducts.lifetimeUnlimited,
                    limitDescription: 'Unlimited Routers, Forever Ad-Free',
                    badgeText: 'BEST VALUE',
                    isCurrent: entitlement.tier == EntitlementTier.lifetime,
                    isHighlight: true,
                    tier: EntitlementTier.lifetime,
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

    // Check if real Play Store ProductDetails was fetched
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
                          // Fallback / Sandbox switch for dev preview
                          await ref.read(entitlementProvider.notifier).updateEntitlement(tier);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Switched to ${tier.displayName}!'),
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
                      ? 'Active Plan'
                      : entitlementState.isLoading
                          ? 'Processing...'
                          : 'Select $title',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
