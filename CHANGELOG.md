# Changelog

All notable changes to **Yet Another LuCI App** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

### Fixed
- **Login Keyboard & Focus Stability**:
  - Fixed soft keyboard flickering and focus drops on login form entry by isolating state scope and attaching dedicated `FocusNode` instances.
- **Auto-Reconnect Engine**:
  - Added silent exponential backoff auto-reconnection logic when ubus RPC sessions expire or network transitions occur.
- **Clients List Rendering & Debouncing**:
  - Applied 200ms query debouncing and list key stabilization to eliminate UI micro-jitter on longer client device lists.
