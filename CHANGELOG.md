# Changelog

All notable changes to **Yet Another LuCI App** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0] - 2026-08-15

### Added
- **Clean Dual-Stream Real-Time Throughput Graph**:
  - Upgraded dashboard and real-time metric charts to a merged continuous line chart for clear network traffic monitoring.
  - Replaced gradient area fills with clean, high-contrast stroke lines and step-responsive curve rendering (`curveSmoothness: 0.25`).
  - Maintained app-wide brand consistency by pairing primary design system Orange (`theme.colorScheme.primary`) for Download (RX) with secondary complementary Cyan/Teal (`theme.colorScheme.secondary`) for Upload (TX).
- **Cloudflare Tunnel Configuration Visibility**:
  - Improved Cloudflare Tunnel ID extraction in the VPN & Connectivity module by parsing tunnel attributes directly from router UCI configurations and encoded token sources.

### Fixed
- **Client Lease Time Formatting & Stale Device Pruning**:
  - Corrected `leaseTime == null` formatting to return `"No active lease"` instead of conflating absent lease data with infinite static leases (`leaseTime == 0`, `"Unlimited"`).
  - Updated offline client retention logic to exclude disconnected, non-static devices with no active DHCP lease (`leaseTime <= 0`), removing stale ghost host hints from the client list while maintaining active devices, dynamic leases, and UCI static IP reservations.

---

## [0.0.9] - 2026-08-14

### Added
- **Expanded VPN & Secure Tunnels Management**:
  - Full configuration overview and state controls for OpenVPN, WireGuard, IPsec, and Cloudflare Tunnels (`cloudflared`).
  - Added real-time tunnel status tracking, public key display, configuration detail parsing, and diagnostic connection tests.
- **Cloudflare Tunnel Token & UCI Parsing**:
  - Integrated automatic extraction of Cloudflare Tunnel attributes and credentials from router `/etc/config/cloudflared` UCI configs and encoded tokens.

### Fixed
- **Storage Metrics Precision**:
  - Normalized statvfs block-size unit calculations to strictly match OpenWrt RPC specs across all storage mount points.

---

## [0.0.8] - 2026-08-13

### Added
- **Dynamic Real-Time Throughput Graph Scaling**:
  - Improved real-time metrics chart autoscale and polling timer integration to eliminate rate spikes and visual rendering artifacts.
  - Enhanced CPU/RAM load calculation and dynamic Y-axis bounds scaling for live bandwidth graphs.

### Fixed
- **Storage Unit Auto-Conversion**:
  - Resolved 1K-blocks vs 512-byte block sizing discrepancies in system storage parsing.
  - Enhanced wired-only router interface discovery and CPU load array normalization.

---

## [0.0.7] - 2026-08-13

### Added
- **Static Lease Management & UI Sync**:
  - Added interactive dialog to add dynamic clients directly to static DHCP leases (`/etc/config/dhcp`) with custom hostname, IP, and lease duration settings.
  - Added one-tap static lease removal with instant UI state synchronization and client list refresh.
- **Firewall & Services Management Features**:
  - Added custom firewall rule management (iptables/nftables) and system init script controls (start/stop/enable/disable/restart).
- **Interface Control & Section Isolation**:
  - Added interface restart, bring-up, and tear-down actions with safety prompts.

---

## [0.0.6] - 2026-08-12

### Added
- **Dynamic Package Manager Engine**:
  - Support for package search, installation, upgrade, and removal across both modern OPKG and APK (OpenWrt 25.x+) package management systems.
- **Internet Access Pause/Resume (Parental Control)**:
  - Added one-tap client internet pause and resume functionality using router firewall rule insertion.
- **Restricted Clients Management**:
  - Introduced standalone Restricted Clients management screen for blocked or access-controlled devices.

### Fixed & Removed
- **Permission & Privacy Optimization**:
  - Removed `AD_ID` permission from Android Manifest for privacy compliance.
  - Enforced single active router session state to prevent multi-router state race conditions.

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
