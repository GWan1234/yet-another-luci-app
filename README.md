# Yet Another LuCI app

<div align="center">
  <h3>Created & Maintained by Tuhin Garai (@nightcodex7)</h3>
  <br>

  <!-- Google Play Store link (Pending release)
  <a href="https://play.google.com/store/apps/details?id=com.nightcode.luci">
    <img src="store-badges/google.webp" alt="Get it on Google Play" style="height:56px;"/>
  </a>
  -->

  ![GitHub all downloads](https://img.shields.io/github/downloads/nightcodex7/yet-another-luci-app/total?style=flat-square&label=Downloads&logo=github&color=0A84FF)

  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/flutter_01.png" width="300"/>
</div>

<br>

**Yet Another LuCI app** is a modern, high-performance Flutter application developed by **Tuhin Garai** (forked from [cogwheel0/luci-mobile](https://github.com/cogwheel0/luci-mobile)) for managing, monitoring, and diagnosing OpenWrt/LuCI routers on mobile devices.

---

## Currently Implemented Features

- **Multiple Router Management & Fast Switching:**
  - Add, edit, remove, and switch seamlessly between unlimited OpenWrt routers with isolated secure credential storage.

- **Dashboard Vitals & Real-Time Metrics:**
  - Live CPU, RAM, and Storage Vitals with animated gauge widgets.
  - Real-time Network Throughput Chart (Rx/Tx Mbps/Kbps) with live scaling.
  - Detailed Network Interfaces Status Cards displaying IP addresses, device names, protocols (DHCP/Static/PPPoE), and UP/DOWN state.
  - Dynamic Wireless Radios Cards (2.4GHz / 5GHz / 6GHz, channels, transmit power, and connected clients count).

- **Client Device Management:**
  - Segmented filtering for **All**, **Wireless**, and **Wired** connected devices.
  - Displays hostnames, MAC addresses, IPv4/IPv6, MAC vendor OUI, connected SSID names, and DHCP lease expiration.
  - Active ARP table neighbor lookup to reliably detect static IP wired clients.
  - Custom MAC Entry interface for Wi-Fi access control.

- **Wireless Radios & SSID Control:**
  - Radio frequency & channel diagnostics across multiple wireless cards (`radio0`, `radio1`, etc.).
  - Connected Clients modal popup per SSID showing exact devices linked to each radio band.

- **OPKG & APK Package Manager:**
  - Automatic system package manager engine detection (OPKG for standard releases, APK for OpenWrt 24.10+ / SNAPSHOT).
  - Search repository packages, install, remove, and update feeds (`opkg update` / `apk update`).
  - Discovered LuCI Apps validator checking installed vs available modules.

- **System Backup, Restore & Flash Operations:**
  - Generate configuration backup archives (`sysupgrade -b /tmp/backup.tar.gz`).
  - Factory reset router configuration (`firstboot -y && reboot`).
  - Save/Dump `mtdblock` partition images directly from `/proc/mtd`.
  - Sysupgrade firmware flasher with options to keep or reset settings.
  - Preserved backup files list viewer (`sysupgrade -l`) and configuration file editor (`/etc/sysupgrade.conf`).

- **Storage Monitoring & Disk Space:**
  - Disk usage analysis across all mounted filesystems (`/`, `/overlay`, `/tmp`, external USB storage).
  - Accurate free/used space calculation in KB/MB/GB.

- **User Setup Cron Jobs:**
  - View, create, edit, and delete scheduled system cron entries (`/etc/crontabs/root`).

- **System Services Diagnostics:**
  - Active status tracking for `procd` daemons and init scripts (Running, Stopped, Enabled, Disabled).
  - Remote control actions: Start, Stop, Restart, Enable, and Disable services.

- **Onboarding & Permission Transparency:**
  - Guided onboarding flow explaining necessary permissions for router communication and storage handling.

---

## Screenshots

| Login | Dashboard | Clients | Interfaces |
|-------|-----------|---------|------------|
| <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/flutter_02.png" width="200"/> | <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/flutter_01.png" width="200"/> | <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/flutter_03.png" width="200"/> | <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/flutter_05.png" width="200"/> |

---

## Installation

<!-- Google Play installation method (Currently not implemented yet)
Get it on **Google Play** once released, or build from source:
-->

Build directly from source:

```bash
git clone https://github.com/nightcodex7/yet-another-luci-app.git
cd yet-another-luci-app
flutter pub get
flutter run
```

- Requires Flutter 3.32.5+ and Dart 3.8+
- Build Android APK: `export JAVA_HOME=/path/to/jdk17 && flutter build apk`

---

## Project Structure

```
lib/
├── config/                 # App configuration & design system
├── models/                 # Data models (client, interface, router)
├── modules/                # Specialized modules (package manager, flash ops, storage, cron, services)
├── screens/                # UI screens (dashboard, clients, interfaces, login, settings)
├── services/               # Business logic (RPC API, secure storage)
├── state/                  # State management (app_state.dart)
├── widgets/                # Reusable UI components
└── main.dart               # App entry point
```

---

## Development & Contribution

- Run in dev mode: `flutter run`
- Build for release: `flutter build apk --release`
- Analyze code: `flutter analyze`

**Contributions welcome!** Please fork, branch, and submit a pull request.

---

## Security & Privacy

- All credentials are stored securely on-device using Android KeyStore / Flutter Secure Storage.
- HTTPS and self-signed certificate support.
- Zero analytics or data tracking.

---

## Troubleshooting

- **Connection Failed:** Check router IP, LuCI web interface, firewall rules, and try HTTP/HTTPS.
- **Authentication Failed:** Verify username/password and admin privileges.
- **No Data Displayed:** Ensure the router has LuCI RPC support installed: `opkg update && opkg install luci-mod-rpc rpcd-mod-luci rpcd-mod-iwinfo luci-mod-status`, restart `rpcd` (or reboot), then verify with `ubus list luci-rpc`.

---

## License

GPL v3.0. See [LICENSE](LICENSE).

---

## Acknowledgments & Credits

- **[cogwheel0/luci-mobile](https://github.com/cogwheel0/luci-mobile)** — This project is forked from `cogwheel0/luci-mobile`. Special thanks and credits to [cogwheel0](https://github.com/cogwheel0) for building the initial foundation and application architecture.
- **OpenWrt Community** — For creating OpenWrt, LuCI, and `luci-rpc` / `rpcd` APIs.
- **Flutter & Dart Team** — For the cross-platform application framework.
- **[OpenWrtManager](https://github.com/hagaygo/OpenWrtManager)** — Additional inspiration for router diagnostic features.

---

**Note:** This app requires an OpenWrt router with LuCI web interface enabled. Make sure your router is properly configured before use.ke sure your router is properly configured before use.

