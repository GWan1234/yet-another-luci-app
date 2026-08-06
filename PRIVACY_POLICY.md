# Privacy Policy

**Yet Another LuCI App** (by Tuhin Garai)  
Last updated: August 6, 2026

Yet Another LuCI App ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how our mobile application ("App") collects, uses, and safeguards your information when you use the App to manage your OpenWrt/LuCI routers.

---

## 1. Information We Collect

### a. User Credentials & Local Router Data
- The App requires your router's IP address, username, and password to connect to your device.
- These credentials are stored securely on your device using industry-standard hardware-backed encryption (via `flutter_secure_storage`).
- We do **not** collect, transmit, or store your router credentials or network layout on any external servers.

### b. Third-Party Ad Services (Google AdMob & UMP)
- For free-tier users, the App displays banner advertisements powered by **Google AdMob**.
- **Data Collected**: AdMob may automatically collect device identifiers (such as Android Advertising ID / IDFA), IP address, coarse location, and app interaction data for ad serving, personalization, and analytics.
- **GDPR & UK User Consent**: In compliance with EU and UK privacy regulations (GDPR / ePrivacy), the App uses the **Google User Messaging Platform (UMP) SDK** to obtain user consent before requesting or personalizing ads. Users in these regions can manage or revoke consent preferences at any time.

### c. In-App Purchases & Subscriptions (Google Play Billing)
- The App offers optional paid upgrades (Plus, Pro, and Lifetime) to remove ads and expand router limits.
- All payment transactions, billing, and subscription renewals are processed exclusively by **Google Play Store**.
- **Data Handled**: The App receives purchase receipts and entitlement state (e.g., tier level) from Google Play. The App does **not** collect, process, or store payment card numbers, bank information, or billing addresses.

---

## 2. How We Use Your Information

- **Router Management**: Authenticating directly with your router to retrieve and display status, interfaces, firewall rules, and connected clients.
- **Advertising**: Displaying relevant banner ads to free-tier users via AdMob.
- **Entitlement Enforcement**: Verifying active subscription or lifetime purchases to remove ads and unlock multi-router features.

---

## 3. Data Sharing and Disclosure

- **Router Data**: Zero router credentials or router configuration data are shared with third parties.
- **Ad & Billing Partners**: Advertising ID and purchase validation tokens are shared directly with Google AdMob and Google Play Services in accordance with Google's Privacy Policy: [https://policies.google.com/privacy](https://policies.google.com/privacy).

---

## 4. Security

- Router credentials remain stored locally on your device.
- The App supports HTTPS connections and custom port configurations for secure communication with your router.

---

## 5. Children's Privacy

- The App is not intended for use by children under the age of 13.
- We do not knowingly collect personal information from children.

---

## 6. Play Console Data Safety Notice

> **Important Deployment Step**: The Google Play Console "Data Safety" form declarations must be updated in lockstep with the release of this application update to disclose:
> 1. Device or other IDs (Advertising ID) collected by Google AdMob.
> 2. Financial Info / Purchase History handled by Google Play Billing.

---

## 7. Contact Us

If you have any questions or concerns about this Privacy Policy, please contact us at:  
[https://github.com/nightcodex7/yet-another-luci-app/issues](https://github.com/nightcodex7/yet-another-luci-app/issues)