# Changelog

All notable changes to **Yet Another LuCI App** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-08-06

### Added
- Multi-router management with real-time capability detection (ubus / UCI / exec fallback).
- DSA & Swconfig network bridge/VLAN topology rendering.
- Package Manager support for both OPKG (`opkg`) and APK (`apk`) package engines on OpenWrt 24.10+.
- Dual-parser Firewall & Security management supporting `firewall3` (iptables) and `firewall4` (nftables).
- Wireless security badge classification (WPA3-SAE, WPA2/WPA3 Mixed, Legacy PSK).
- Automatic frequency precision and channel formatting for 2.4GHz / 5GHz / 6GHz radios.
- In-app RPCD ACL remediation dialogs and explicit setup guidance.
- Dual-build architecture: Apache 2.0 Community Edition (unlimited, 100% ad-free) and Play Store Edition.
