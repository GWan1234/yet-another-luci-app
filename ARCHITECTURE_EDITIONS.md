# Architecture & Editions Guide

This document details the architectural separation between the **Community Edition** (FOSS / Apache 2.0) and the **Play Store Edition** of Yet Another LuCI App.

---

## 1. Catalog of Shared vs. Flavor-Specific Files

### Shared Code & Assets (Both Flavors)
- `lib/main.dart` — App entrypoint (initializes `AppConfig` based on compile-time `--dart-define=FLAVOR`).
- `lib/config/app_config.dart` — Central flavor detection (`AppConfig.isCommunityFlavor` vs `AppConfig.isPlayStoreFlavor`).
- `lib/design/` & `lib/widgets/` — UI design system, custom charts, loading indicators, navigation, RPC dialogs.
- `lib/models/` — Data models (`router.dart`, `interface.dart`, `client.dart`, `rpc_result.dart`, `network_topology.dart`).
- `lib/modules/` — All core router management modules (DHCP/DNS, Firewall, Package Manager, System Mon, Storage, Wireless, VPN).
- `lib/services/` — Core API services (`api_service.dart`, `router_service.dart`, `auth_service.dart`, `secure_storage_service.dart`, `update_checker_service.dart`).
- `lib/state/` — Global state management (`app_state.dart`).
- `android/app/src/main/` — Primary Android manifest, Kotlin main activity, drawables, and mipmaps.
- `assets/` — Icons, app logos, mock JSON RPC responses, and screenshot assets.

### Community Edition Only (`--flavor community`)
- `lib/services/update_checker_service.dart` — GitHub Release update checking (gated exclusively to Community builds).
- `android/app/build.gradle.kts` (Community Block) — Flavor-scoped Gradle task that strips `GoogleMobileAdsPlugin` and `InAppPurchasePlugin` from `GeneratedPluginRegistrant.java` and excludes their dependencies during compilation.

### Play Store Edition Only (`--flavor playstore`)
- `lib/services/ad_consent_service.dart` — Google UMP (User Messaging Platform) GDPR consent flow for AdMob.
- `lib/widgets/banner_ad_widget.dart` — Google Mobile Ads banner widget (renders empty container on Community flavor).
- `lib/providers/entitlement_provider.dart` — In-App Purchase entitlement provider for subscriptions (`plus_monthly`, `pro_monthly`, `lifetime_unlimited`).
- `lib/screens/paywall_screen.dart` — Subscription paywall screen for Play Store monetization.
- `android/app/src/playstore/AndroidManifest.xml` — Scoped Android manifest containing the AdMob `com.google.android.gms.ads.APPLICATION_ID` meta-data tag.

---

## 2. Repo Audit Findings (Files to Evaluate for Privacy / Public Repo Boundaries)

| File / Directory | Finding / Recommendation |
| :--- | :--- |
| `fastlane/metadata/android/` | **Play Store Metadata**: Contains Play Store localized text listings, screenshots, and full descriptions. If fastlane is intended to remain internal, this directory could be moved out of the public community repo. |
| `scripts/release.sh` | **Release Shell Script**: Contains internal release automation commands. Verify that no private environment defaults are hardcoded. |
| `android/key.properties.example` | **Safe**: Template file only. No actual passwords or private key binary files exist in repository history. |

---

## 3. Play Store Submission Checklist

To prepare the Play Store flavor for official publication on Google Play Console, complete the following items:

- [ ] **Google Play Developer API Service Account**: Configure `api-key.json` service account credentials in GitHub Secrets for automated Fastlane deployment.
- [ ] **AdMob Production Ad Unit IDs**: Replace Google test AdMob App ID (`ca-app-pub-3940256099942544~3347511713`) with production AdMob App ID and Banner/Interstitial Ad Unit IDs.
- [ ] **In-App Purchase Product IDs**: Configure matching Product IDs in Google Play Console under In-app products / Subscriptions:
  - `plus_monthly`
  - `pro_monthly`
  - `lifetime_unlimited`
- [ ] **Data Safety Form**: Complete Google Play Data Safety declaration in Play Console (declare secure storage of router IP/credentials locally on device, zero third-party data tracking in Community flavor, AdMob data collection in Play Store flavor).
- [ ] **Target API Level Compliance**: Verify `targetSdkVersion = 34` (Android 14) or higher per current Google Play requirements.
- [ ] **Hosted Privacy Policy URL**: Ensure `PRIVACY_POLICY.md` is accessible via a public HTTPS URL (e.g., GitHub Pages or raw GitHub URL) and linked in Play Console listing.
- [ ] **App Content Rating Questionnaire**: Complete IARC content rating questionnaire in Google Play Console.
