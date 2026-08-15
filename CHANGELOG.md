# Changelog

All notable changes to **Yet Another LuCI App** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0] - 2026-08-15

### Added
- **Cloudflare-Style Real-Time Throughput Graph**:
  - Upgraded dashboard and real-time metric charts to a merged continuous line chart inspired by Cloudflare Speed Test aesthetics.
  - Replaced gradient area fills with clean, high-contrast stroke lines and step-responsive curve rendering (`curveSmoothness: 0.25`).
  - Integrated high-contrast brand color distinction: Cloudflare Amber/Orange (`#F38020`) for Download (RX) and Cloudflare Purple (`#8C54FF`) for Upload (TX), synchronized across speed indicators, tags, and tooltips.
- **Cloudflare Tunnel Configuration Visibility**:
  - Improved Cloudflare Tunnel ID extraction in the VPN & Connectivity module by parsing tunnel attributes directly from router UCI configurations and encoded token sources.

---

## [0.0.5] - 2026-08-11

> [!NOTE]  
> **Release Note**: Version `0.0.4-beta` was intentionally skipped due to internal release and stability issues to ensure full reliability for this release.

### Added
- **Wi-Fi Access Control & Auto-Revert Safety Guard**:
  - Added per-radio/per-SSID MAC allow-list control with interactive device selection (from connected clients or manual MAC input).
  - Implemented background shell script auto-revert timer (25 seconds) on the router to protect users from accidental lockout if Wi-Fi connectivity is severed during access rule updates.
  - Added real-time UCI config pre-checking to automatically restore checkbox allow/deny states on client selection.
- **Low-Risk Router Management Actions**:
  - Integrated fast router actions: Reboot Router, Restart Network Services, Reload Wireless Services, and Toggle Wireless Radios with explicit user confirmation prompts.
- **Multi-Platform Package Remediation Instructions**:
  - Updated RPCD ACL remediation instructions to provide platform-specific commands for both modern APK (OpenWrt 25.x+) and legacy OPKG (OpenWrt 24.10 and earlier) package managers.

### Fixed
- **Storage Monitoring Unit-Conversion Engine**:
  - Eliminated magnitude-based unit guessing heuristics (`rawSize < 100GB`), replacing it with explicit `StorageDataSource` format typing (`rpcJson`, `dfKBlocks`, `dfHuman`).
  - Fixed double-conversion bug that caused `/tmp` (tmpfs) to report as `120.17 GB` and total system storage as `53.09 GB`.
  - Ensured ground-truth byte calculations for all mount points (`/`, `/overlay`, `/rom`, `/tmp`, external USB storage) and aggregate storage metrics.

---

## [0.0.4] - 2026-08-10

### Added
- **Client IPv6 Address Expand/Collapse & Deduplication**:
  - Automatically deduplicated client IPv6 address lists and added an interactive `Show X more IPv6 address(es)` / `Collapse IPv6 addresses` toggle for device cards with multiple ULA or link-local IPv6 addresses.
- **Adaptive Wireless Throughput Rate Formatting**:
  - Formatted wireless station Rx/Tx rates dynamically in human-readable units (`Gbps`, `Mbps`, `Kbps`, or `B/s`) based on connection throughput.
- **WAN & Public IP Card Identification**:
  - Expanded interface cards on the Interfaces tab now explicitly identify WAN/ISP interfaces and label public IP addresses (`Public IP Address`, `Public IPv6 Address`).

### Fixed
- **Storage & Overlay Root Metric Calculation**:
  - Fixed storage calculation on Dashboard and Storage Monitoring cards to accurately fetch and report root `/` filesystem capacity rather than locking onto the read-only `/rom` SquashFS image (`0 MB / 16 MB`).
- **Dashboard Interface Card Navigation**:
  - Corrected interface card tap and long-press actions on the Dashboard to open the **Interfaces** tab (`InterfacesScreen`) and auto-expand the targeted interface card.
- **About Dialog Link Styling**:
  - Removed underline text decoration from the GitHub repository link in the About popup dialog.

---

## [0.0.3] - 2026-08-10

> [!NOTE]  
> **Release Note**: Versions `0.0.1` and `0.0.2` were internal testing iterations and were intentionally skipped from public release to ensure maximum stability and reliability for this initial public release.

### Added
- **5th Standalone Bottom Navigation Tab — Wireless Management**:
  - Promoted Wireless Management (radio configuration, associated SSIDs, operating mode, channels, TX power, and connected stations) to a dedicated, top-level bottom navigation tab.
  - Redesigned the navigation bar into a symmetrical **2-and-2 split** around the elevated central Dashboard badge button (`Interfaces`, `Clients` | `Dashboard` | `Wireless`, `More`).
- **Dynamic Wi-Fi Gateway Auto-Detection**:
  - One-tap router IP auto-detection on the login screen, dynamically deriving the gateway subnet from active OS Wi-Fi network interfaces rather than relying on hardcoded defaults.
- **Three-State Kernel NUD Client Reachability**:
  - Enhanced client device tracking by parsing Linux kernel neighbor reachability states (🟢 Reachable, 🟡 Stale, ⚪ Disconnected).
- **Live Router Connectivity Indicator**:
  - Real-time connection status dot (green/red) integrated directly into the Dashboard header.
- **Unified Package & Firewall Engine Support**:
  - Support for OPKG (OpenWrt <= 23.05) and APK (OpenWrt >= 24.10) package management backends.
  - Dual firewall rule visualization supporting both `fw3` (iptables) and `fw4` (nftables).
  - DSA (`bridge-vlan`) and `swconfig` network switch topology visualization.

### Changed
- **App-Wide Color Scheme Rebrand**:
  - Transitioned the entire UI theme palette to **nightcode Orange (`#F97316`)** and **Amber (`#FB923C`)** for a bold, distinctive visual identity across both Light and Dark modes.
  - Migrated hardcoded chart line gradients and speed indicators in `DashboardScreen` and `InterfacesScreen` to design system color tokens.
- **Application ID Normalization**:
  - Standardized the Community build package name to `com.nightcode.luci`.
- **Adaptive Wireless Throughput Units**:
  - Formatted wireless station Rx/Tx rates dynamically in human-readable units (`Gbps`, `Mbps`, `Kbps`, or `B/s`) based on connection speed magnitude.
- **Client IPv6 List Expand/Collapse & Deduplication**:
  - Deduplicated IPv6 addresses on client cards and added an interactive expand/collapse toggle for devices with multiple private (ULA) or link-local IPv6 addresses.
- **WAN & Public IP Card Identification**:
  - Expanded interface cards on the Interfaces tab now explicitly identify and label WAN/ISP interfaces and public IP addresses (`Public IP Address`, `Public IPv6 Address`).

### Fixed
- **Storage & Overlay Root Metric Parsing**:
  - Corrected storage calculation on Dashboard and Storage Monitoring cards to fetch root `/` filesystem usage rather than defaulting to the read-only `/rom` SquashFS image (`0 MB / 16 MB`).
- **Dashboard Interface Card Navigation**:
  - Fixed interface status card tap action on the Dashboard to navigate directly to the **Interfaces** tab (`tab 1`) and auto-expand the selected interface card (resolving redirection to Clients tab).
- **Login Keyboard & Focus Stability**:
  - Fixed soft keyboard flickering and focus drops on login form entry by isolating state scope and attaching dedicated `FocusNode` instances.
- **Auto-Reconnect Engine**:
  - Added silent exponential backoff auto-reconnection logic when ubus RPC sessions expire or network transitions occur.
- **Clients List Rendering & Debouncing**:
  - Applied 200ms query debouncing and list key stabilization to eliminate UI micro-jitter on longer client device lists.
- **About Dialog Underline Styling**:
  - Removed underline text decoration from GitHub repository link in the About dialog.
