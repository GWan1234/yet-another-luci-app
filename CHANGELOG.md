# Changelog

All notable changes to **Yet Another LuCI App** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.0.3] - 2026-08-10

### Added
- **Localized Developer Support Options**: Localized voluntary support model with minimum support ($20 USD / ₹899 INR in India) and custom support amount entry.
- **Elevated Center Navigation Bar**: Redesigned bottom navigation bar featuring a raised circular action button for the Dashboard tab.
- **Live Router Connection Status Dot**: Dynamic green/amber/red status indicator in the Dashboard header reflecting real-time router reachability.
- **Wi-Fi Gateway Auto-Detect Button**: One-tap gateway IP address detection on the login screen using zero-permission OS network interface inspection.
- **Three-State NUD Client Reachability**: Differentiate client connection states using kernel ARP/neighbor table reachability (🟢 Reachable, 🟡 Stale, ⚪ Disconnected).

### Changed
- **Zero Ads in All Builds**: AdMob ads disabled across both Community and Play Store builds for v0.0.3.
- **Repository Architecture Refinement**: Cleaned up dead-weight duplicate files, restored core public source tree integrity, and isolated Play Store build workflows.

### Fixed
- **Login Form Focus & Keyboard Stability**: Resolved soft keyboard flicker and focus drops during login entry by isolating consumer widgets and attaching dedicated `FocusNode` instances.
- **Auto-Reconnect Engine**: Implemented silent exponential backoff auto-reconnection attempts when API sessions expire or network drops occur.
- **Clients List Jitter & Filtering Performance**: Added 200ms query debouncing and list key stabilization for long client list rendering.

---

## [0.0.2] - 2026-08-10

### Added
- **Public IP Masking Scoping**: Restricted privacy obfuscation toggles strictly to public WAN-facing IP addresses, retaining local LAN IP readability.
- **Voluntary Developer Sponsorship**: Simplified monetization hub into a non-gated voluntary support model with unlimited router access for all users.
- **Manual Release Update Utility**: Integrated check-for-update setting querying official GitHub releases.

### Changed
- **Build Infrastructure**: Upgraded Android build tools to AGP 8.11.1, Kotlin 2.2.20, and verified release bundle size minification via `bundletool`.

---

## [0.0.1] - 2026-08-01

### Added
- **Initial FOSS Release**: Full-featured OpenWrt LuCI mobile client.
- **Smart Network Topology**: Automatic switch topology mapping for both DSA and Swconfig architectures.
- **Package Manager Engines**: Support for OPKG (OpenWrt <= 23.05) and APK (OpenWrt >= 24.10).
- **Firewall Management**: Management interface for fw3 (iptables) and fw4 (nftables).
