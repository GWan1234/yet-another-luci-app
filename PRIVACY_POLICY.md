# Privacy Policy

**Yet Another LuCI App** (by Tuhin Garai / nightcode)  
Last updated: August 26, 2026

Yet Another LuCI App ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how our mobile application ("App") handles your information when you use the App to manage your OpenWrt/LuCI routers.

---

## 1. Local Network Data & Local-First Architecture

### a. Local Router Credentials & Configuration Data
- The App requires your router's IP address, port, username, and password to establish direct connections with your OpenWrt router on your local Wi-Fi or VPN network.
- All router credentials are encrypted and stored locally on your device using hardware-backed secure storage (via `flutter_secure_storage` / KeyStore).
- Credentials and network layout data are used **exclusively** for direct HTTP/HTTPS and JSON-RPC communication between your mobile device and your OpenWrt router.
- We do **not** collect, transmit, upload, or store your router credentials, IP addresses, network topology, or router configurations on any external server or developer database.

### b. Local Network Access Permission
- To discover, monitor, and manage OpenWrt routers on modern Android versions (Android 15+ / API 35+ / API 37), the App requests the `ACCESS_LOCAL_NETWORK` runtime permission.
- This permission is used strictly to establish socket and HTTP/HTTPS connections to local gateway IP addresses (such as `192.168.1.1` or `10.0.0.1`).

---

## 2. Edition Breakdown & Third-Party Services

### a. Community Edition (GitHub Releases / FOSS)
- **100% Free & Ad-Free**: Contains zero advertisements, does not collect Advertising IDs (`AD_ID`), and does not integrate third-party ad networks.
- **No In-App Purchases**: Fully open-source under the Apache License 2.0 with unlimited router profiles.
- **Zero Telemetry or Analytics**: Contains no background tracking, crash telemetry, or third-party analytics SDKs.

### b. Play Store / Official Edition (Google Play)
- **Support the Developer & In-App Billing (Google Play Billing)**:
  - The App may feature optional "Support the Developer" voluntary contributions, tip jars, or feature tier upgrades.
  - All financial transactions are processed securely directly by the **Google Play Store**.
  - The App never collects, receives, or stores credit card details, bank account numbers, or billing addresses.
- **Optional Ad Services & Consent (Google AdMob & UMP SDK)**:
  - If optional ad-supported tiers or banner features are enabled in Play Store builds, advertisements are powered by **Google AdMob**.
  - **Data Collection**: Google AdMob may collect non-sensitive device identifiers (such as Advertising ID), IP address, coarse location, and interaction metrics for ad delivery and fraud prevention.
  - **GDPR / Regional Consent**: In regions subject to privacy laws (e.g. EU/EEA, UK), the **Google User Messaging Platform (UMP) SDK** prompts users for explicit consent before serving personalized ads. Users may review or revoke consent at any time in App settings.

---

## 3. Data Sharing and Disclosure

- **Zero Router Data Sharing**: Router passwords, IP addresses, UCI configurations, and connected device logs are **never shared** with any third party.
- **Google Play & AdMob Services**: Where enabled in Play Store builds, billing receipts and non-sensitive advertising IDs are handled directly by Google Services in compliance with [Google's Privacy Policy](https://policies.google.com/privacy).

---

## 4. Security

- Router passwords and session tokens (`sysauth`) remain stored securely in device hardware-backed storage.
- The App supports HTTPS protocol connections, custom ports, and SSL verification options to secure local network and VPN traffic.

---

## 5. Children's Privacy

- The App is not directed to children under the age of 13. We do not knowingly collect personal information from children.

---

## 6. Play Console Data Safety Compliance

This Privacy Policy matches the declarations in the Google Play Console Data Safety form:
- **Local Data Only**: Router credentials and network data remain on the user's local device.
- **Optional Ad & Purchase Data**: Device IDs (AdMob) and Purchase History (Google Play Billing) are processed only where billing/ad features are active in Play Store distribution builds.

---

## 7. Contact & Official Policy Links

If you have questions, concerns, or requests regarding this Privacy Policy, please contact us:
- **Email**: tuhingarai.dev+privacy@gmail.com
- **Website Privacy Policy**: [https://nightcode.co.in/privacy-policy.html](https://nightcode.co.in/privacy-policy.html)
- **Terms & Conditions**: [https://nightcode.co.in/terms.html](https://nightcode.co.in/terms.html)
- **GitHub Repository**: [https://github.com/nightcodex7/yet-another-luci-app](https://github.com/nightcodex7/yet-another-luci-app)

