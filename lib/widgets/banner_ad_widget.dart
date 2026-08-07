import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:luci_mobile/config/app_config.dart';
import 'package:luci_mobile/config/ad_config.dart';
import 'package:luci_mobile/providers/entitlement_provider.dart';

/// Fixed-height banner ad widget gated on entitlement state.
/// Reserves container height upfront to prevent layout shift.
class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  String get _adUnitId => AdConfig.bannerAdUnitId;

  @override
  void initState() {
    super.initState();
    _loadAdIfNeeded();
  }

  void _loadAdIfNeeded() {
    if (!AppConfig.isMonetizationEnabled) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    final entitlement = ref.read(entitlementProvider);
    if (entitlement.isAdFree) return;

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isAdLoaded = false;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isMonetizationEnabled) {
      return const SizedBox.shrink();
    }

    final entitlement = ref.watch(entitlementProvider);

    // Gate visibility strictly on entitlement state
    if (entitlement.isAdFree) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return Container(
      width: double.infinity,
      height: 60.0, // Fixed height to prevent layout shift
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      alignment: Alignment.center,
      child: isMobile && _isAdLoaded && _bannerAd != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: AdWidget(ad: _bannerAd!),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.ad_units_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  isMobile ? 'Loading Sponsor Banner...' : 'Ad Space (Free Tier) — Upgrade to remove',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
    );
  }
}
