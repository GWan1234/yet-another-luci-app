# Yet Another LuCI App

<div align="center">
  <img src="assets/images/app_logo_transparent.png" width="120" alt="App Logo" />
  <h2>Modern OpenWrt & LuCI Router Manager for Mobile</h2>
  <p>Maintained by <b>Tuhin Garai (@nightcodex7)</b></p>

  [![Version](https://img.shields.io/badge/Version-v0.1.6-blue.svg?style=for-the-badge&logo=github)](https://github.com/nightcodex7/yet-another-luci-app/releases)
  [![Flutter](https://img.shields.io/badge/Flutter-3.32.5+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.8+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
  [![License](https://img.shields.io/badge/License-Apache--2.0-blue.svg?style=for-the-badge)](LICENSE)
  [![Build Status](https://img.shields.io/badge/Build-Passing-teal.svg?style=for-the-badge)]()
  [![OpenWrt](https://img.shields.io/badge/OpenWrt-19.07--24.10+-1589F0?style=for-the-badge&logo=openwrt&logoColor=white)](https://openwrt.org)

  <br><br>

  <h3>Dashboard Preview (Light & Dark Theme)</h3>
  <p>
    <img src="assets/screenshots/1_dashboard-light.jpeg" width="340" alt="Dashboard Light Mode" />
    &nbsp;&nbsp;&nbsp;&nbsp;
    <img src="assets/screenshots/2_dashboard-dark.jpeg" width="340" alt="Dashboard Dark Mode" />
  </p>
</div>

<br>

**Yet Another LuCI App** is a modern Flutter mobile application for managing, monitoring, and diagnosing OpenWrt routers. Built with Material 3 design principles, custom micro-animations, self-device guardrails, atomic UCI transaction engines, and full LuCI RPC integration, it brings desktop-class router control directly to mobile devices.

---

## Key Features

### Multi-Router Management & Secure Vault

- **Multi-Device Support:** Manage and switch between multiple OpenWrt routers with isolated credentials stored in native secure storage.
- **Resilient Authentication Stack:** Automatic fallback chain supporting LuCI RPC (`/cgi-bin/luci/rpc/auth`), ubus JSON-RPC (`session.login`), and redirect-aware CGI form authentication (`sysauth` cookies and `stok` tokens).
- **HTTPS & Custom Ports:** Connect via HTTP or HTTPS with custom port configurations and local SSL certificate validation overrides.

### Parental Controls & Scheduled Access

- **Profile-Based Management:** Group connected devices under profiles with customizable access schedules.
- **Automated Access Windows:** Enforces firewall blocking rules during scheduled restriction windows and restores access automatically when windows expire.
- **Domain Filtering & Overrides:** Filter specific domains per profile or toggle instant unrestricted bypass overrides.

### Guest Wi-Fi & Wireless Diagnostics

- **One-Click Guest Networks:** Provision guest Wi-Fi SSIDs with automatic AP client isolation (`ap_isolate=1`) and dedicated firewall zone isolation.
- **Wi-Fi Access Control:** Enforce MAC address allowlists or denylists with direct router UCI synchronization.
- **QR Code Sharing:** Generate on-screen Wi-Fi QR codes for quick client connection.
- **Multi-Band Diagnostics:** Monitor 2.4GHz, 5GHz, and 6GHz radios with frequency details, channel width, transmit power, and connected station bandwidth metrics.

### Self-Device Protection & Atomic UCI Engine

- **Self-Device Guard:** Automatically detects local client IP and MAC addresses to prevent accidental self-lockouts during access rule changes.
- **Atomic UCI Rollback:** Automatically executes `uci revert` across target configuration files if an intermediate multi-step RPC request fails.

### Dashboard & Network Vitals

- **Dual Themes:** Switch seamlessly between Light and Dark Material 3 themes.
- **Animated Gauges:** Live visual gauges for CPU load, RAM usage, Swap space, and root `/` filesystem capacity.
- **Real-Time Throughput Graph:** Smooth live chart displaying network transfer rates (Rx/Tx) with customizable polling intervals.
- **Interface Cards:** Status cards for WAN, LAN, and WWAN showing IP addresses, MACs, protocols, and WAN public IP verification.

### Connected Client Management

- **Unified Client List:** Aggregates active DHCP leases, ARP neighbor entries, and wireless stations into a single view.
- **Device Details:** Displays hostname, IP, MAC address, vendor OUI, connected SSID, and radio band badges.
- **IPv6 Management:** Displays deduplicated IPv6 address lists with toggleable expand/collapse views for multiple private or link-local addresses.
- **Static Leases:** View, add, and modify static DHCP IP assignments.

### OPKG & APK Dual Package Manager

- **Smart Engine Detection:** Automatically switches between standard `opkg` (OpenWrt 21.02–23.05) and modern `apk` (OpenWrt 24.10+) package engines.
- **Package Management:** Search repository feeds, update package lists, install, and remove packages.
- **LuCI App Finder:** Discover and manage installed vs. available LuCI extension modules (`luci-app-*`).

### System Services, VPN & Storage

- **Services Control:** View active `procd` daemons and init scripts; start, stop, restart, enable, or disable services remotely.
- **VPN Monitoring:** Monitor status and interfaces for WireGuard, OpenVPN, Tailscale, and ZeroTier connections.
- **Cron Scheduler:** View and edit system scheduled tasks (`/etc/crontabs/root`).
- **Disk & Storage Monitor:** Monitor disk space breakdown for root `/`, `/overlay`, `/tmp`, and attached USB drives.

### Backup, Restore & Partition Tools

- **Pre-Restore Validation:** Validates gzip headers (`0x1F 0x8B`) and `ustar` archive structures prior to upload to prevent corrupt backup restores.
- **Preserved File Viewer:** Inspect files marked for retention during sysupgrade operations (`sysupgrade -l`).
- **MTD Partition Dumper:** Save binary `mtdblock` partition images directly from `/proc/mtd`.
- **Factory Reset:** Trigger remote system reset (`firstboot -y`) and router reboot.

---

## Screenshots Showcase

<div align="center">
  <p><b>Explore full resolution screenshots of Yet Another LuCI App features:</b></p>
</div>

| Login Screen | Dashboard (Light) | Dashboard (Dark) | Dashboard-1 |
|:---:|:---:|:---:|:---:|
| <img src="assets/screenshots/3_login_page.jpeg" width="180"/> | <img src="assets/screenshots/1_dashboard-light.jpeg" width="180"/> | <img src="assets/screenshots/2_dashboard-dark.jpeg" width="180"/> | <img src="assets/screenshots/4_dashboard-2.jpeg" width="180"/> |

| Dashboard-2 | Clients | Interfaces | Interface-1 |
|:---:|:---:|:---:|:---:|
| <img src="assets/screenshots/5_dashboard-3.jpeg" width="180"/> | <img src="assets/screenshots/6_clients.jpeg" width="180"/> | <img src="assets/screenshots/7_interfaces.jpeg" width="180"/> | <img src="assets/screenshots/8_interfaces-1.jpeg" width="180"/> |

| Wireless Management | System Monitoring | Storage Monitoring | Real-Time Metrics |
|:---:|:---:|:---:|:---:|
| <img src="assets/screenshots/9_wireless.jpeg" width="180"/> | <img src="assets/screenshots/10_system.jpeg" width="180"/> | <img src="assets/screenshots/11_storage.jpeg" width="180"/> | <img src="assets/screenshots/12_realtime_charts.jpeg" width="180"/> |

| DHCP & DNS | Firewall | Firewall-1 | Services & System |
|:---:|:---:|:---:|:---:|
| <img src="assets/screenshots/13_dhcp_dns.jpeg" width="180"/> | <img src="assets/screenshots/14_firewall.jpeg" width="180"/> | <img src="assets/screenshots/15_firewall-1.jpeg" width="180"/> | <img src="assets/screenshots/16_services_system.jpeg" width="180"/> |

| Parental Controls | Parental Controls-1 | OPKG & APK Packages | Settings (PlayStore) |
|:---:|:---:|:---:|:---:|
| <img src="assets/screenshots/17_parental_controls.jpeg" width="180"/> | <img src="assets/screenshots/18_parental_controls-1.jpeg" width="180"/> | <img src="assets/screenshots/19_packagemanager.jpeg" width="180"/> | <img src="assets/screenshots/20-settings-playstore.jpeg" width="180"/> |

| Settings (Community) | More menu | About & App Info | |
|:---:|:---:|:---:|:---:|
| <img src="assets/screenshots/20-settings-community.jpeg" width="180"/> | <img src="assets/screenshots/21-more.jpeg" width="180"/> | <img src="assets/screenshots/22-about.jpeg" width="180"/> | |

<br>

<div align="center">
  <p><i>Navigate to <a href="assets/screenshots/">assets/screenshots/</a> to view the complete collection of screenshots in the repository.</i></p>
</div>

---

## Repository Structure

```
yet-another-luci-app/
├── android/                   # Android native platform code & signing configs
├── assets/                    # Static app assets
│   ├── icons/                 # App launcher icons
│   ├── images/                # Brand graphics & logos
│   ├── mock/                  # Mock diagnostic data for review modes
│   └── screenshots/           # Full app feature screenshots & theme previews
├── fastlane/                  # Google Play Store release metadata & screenshots
├── lib/                       # Main Flutter codebase
│   ├── config/                # Design tokens, themes, app routes, and constants
│   ├── models/                # Data models (Client, Interface, Router, etc.)
│   ├── modules/               # Feature modules (Package Manager, Parental Controls, VPN, Services, Backup, Storage, etc.)
│   ├── providers/             # State & entitlement providers
│   ├── screens/               # Core screens (Dashboard, Clients, Interfaces, Login, Settings, More)
│   ├── services/              # API communication layer, JSON-RPC client, secure storage
│   ├── state/                 # State management engine (Riverpod controllers)
│   ├── utils/                 # Security guardrails, HTTP client managers, platform utilities
│   ├── widgets/               # Reusable UI widgets, animated gauges, throughput charts, topology map
│   └── main.dart              # Application entry point
├── scripts/                   # Auxiliary maintenance scripts
├── store-badges/              # Google Play Store promotional badges
├── test/                      # Unit, widget, and integration test suite
├── pubspec.yaml               # Flutter package specification & dependencies
├── AUDIT_TRACKER.md           # Production hardening & security audit tracker
├── PRIVACY_POLICY.md          # Privacy policy disclosure
├── CONTRIBUTING.md            # Guidelines for open-source contributors
├── CONTRIBUTORS.md            # Creator attribution & maintainer guidelines
└── README.md                  # Project documentation
```

---

## Building & Running

### Prerequisites

- **Flutter SDK:** 3.32.5+
- **Dart SDK:** 3.8+
- **JDK:** OpenJDK 17 or higher
- **Android Studio / Android SDK:** API level 36

### Quick Local Run

```bash
# 1. Clone repository
git clone https://github.com/nightcodex7/yet-another-luci-app.git
cd yet-another-luci-app

# 2. Install dependencies
flutter pub get

# 3. Analyze code quality
flutter analyze

# 4. Run test suite
flutter test

# 5. Run application in dev mode
flutter run
```

---

## Router Requirements & Security

To enable full communication between **Yet Another LuCI App** and your OpenWrt router, ensure the following RPC modules are installed on your router:

```bash
opkg update
opkg install luci-mod-rpc rpcd-mod-luci rpcd-mod-iwinfo luci-mod-status
/etc/init.d/rpcd restart
```

### Security Highlights

- **Zero Analytics:** No tracking telemetry, no cloud relays, zero data collection.
- **Local Vault:** Router IP addresses, credentials, and tokens remain isolated on your local device inside native secure storage.
- **Self-Device Guard:** Active IP/MAC auto-detection prevents self-lockout during network access modifications.
- **Atomic Rollbacks:** Staged UCI changes revert automatically if RPC failures occur, preventing broken router state.
- **SSL Support:** Supports HTTPS RPC endpoints and self-signed SSL certificate bypass options for local subnets.

---

## Contributing

Contributions, bug reports, and feature suggestions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting pull requests.

1. Fork the project.
2. Create your feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

## License & Credits

Distributed under the **Apache License 2.0**. See [`LICENSE`](LICENSE), [`NOTICE`](NOTICE), and [`LICENSE_CHANGE.md`](LICENSE_CHANGE.md) for details.

> [!IMPORTANT]
> **Mandatory Fork Attribution Requirement:** Under Apache License 2.0 (Section 4), all forks and derivative versions of this repository on GitHub **MUST** retain original author credit for **Tuhin Garai (@nightcodex7)** in the `README.md`, `CONTRIBUTORS.md`, `NOTICE`, and repository commit history. Stripping or obscuring original creator attribution on GitHub repository forks is strictly prohibited. See [CONTRIBUTORS.md](CONTRIBUTORS.md) for details.

### Acknowledgments

- **[cogwheel0/luci-mobile](https://github.com/cogwheel0/luci-mobile)** — Special thanks to [cogwheel0](https://github.com/cogwheel0) for building the initial foundation of `luci-mobile`.
- **OpenWrt Project** — Thanks to the OpenWrt developers and community for creating OpenWrt and `rpcd` / `luci-rpc` interfaces.
- **Flutter Framework** — Built with Flutter and Riverpod for high-performance reactive UI rendering.

---
*Maintained by [Tuhin Garai (@nightcodex7)](https://github.com/nightcodex7)*
