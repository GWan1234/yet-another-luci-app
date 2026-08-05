# Project Task Roadmap: LuCI OpenWrt Management App for Android

## Project Objective

Transform `yet-another-luci-app` into a complete, modular, OpenWrt router management application tailored for Android devices across all supported Android versions, adhering strictly to Google Play app publishing guidelines and OpenWrt/LuCI best practices.

---

## Task Breakdown & Status

### Milestone 1: iOS Support Removal & Author Metadata Update

- [x] Remove iOS platform codebase (`ios/` directory and related build scripts/workflows).
- [x] Clean up iOS assets, references, and platform detection in code (e.g., `CupertinoIcons`, `Platform.isIOS`).
- [x] Update author, copyright, and repository metadata across README, documentation, and app files to match Git identity (`Tuhin Garai <tuhingarai123@gmail.com>` / `nightcodex7`).
- [x] Verify flutter/dart project integrity (`flutter analyze` / codebase check).
- [x] Summarize changes and await user authorization for Milestone 2.

---

### Milestone 2: Plugin & Modular Architecture Framework

- [x] Create module loading framework and plugin architecture interface.
- [x] Define coding conventions and module lifecycle contract.
- [x] Implement dynamic module registration mechanism.
- [x] Ensure existing functionality remains unbroken during refactoring.

---

### Milestone 3: Core System Monitoring Framework

- [x] Build Dashboard monitoring skeleton UI.
- [x] Implement CPU status monitoring.
- [x] Implement RAM memory usage display.
- [x] Implement System Load Average stats.
- [x] Implement Router Uptime stats.

---

### Milestone 4: Storage Monitoring

- [x] Implement Filesystem usage overview.
- [x] Display Mounted storage devices.
- [x] Display Overlay FS status and Flash memory usage.

---

### Milestone 5: Network Monitoring

- [x] Display Network interfaces status list.
- [x] Implement RX/TX throughput tabular metrics.
- [x] Display IPv4 & IPv6 addresses per interface.
- [x] Display Gateway connection status.

---

### Milestone 6: Real-Time Charting System

- [x] Create shared line chart component using `fl_chart`.
- [x] Implement dynamic polling engine with configurable interval (1s-10s).
- [x] Implement fixed history buffer (last N points).
- [x] Connect real-time charts for CPU, RAM, and RX/TX Network Throughput.

---

### Milestone 7: Wireless Management

- [x] Display Wireless radios list (`radio0`, `radio1`).
- [x] Display Associated SSIDs & Wireless operating mode (AP/Client/Mesh).
- [x] Display Wireless channel & TX power settings.
- [x] Display Security / Encryption status.
- [x] Display Connected wireless stations associative list with RSSI/signal strength.

---

### Milestone 8: Firewall & Security

- [x] Display Firewall Zones overview (LAN, WAN, etc.).
- [x] Display Inter-zone forwarding rules (e.g., `lan → wan`).
- [x] Display Input, Output, and Forward default policies (ACCEPT/REJECT/DROP).
- [x] Display Port Forwarding (Redirects) & Custom security rules summary.

---

### Milestone 9: DHCP & DNS Management

- [x] Display Active DHCP leases list (hostname, IP, MAC address, remaining lease time).
- [x] Display Static IP DHCP host reservations / mappings.
- [x] Display DNS Forwarders configuration overview (Dnsmasq upstream DNS servers, local domain, rebind protection).

---

### Milestone 10: Services & System Management

- [x] Display Procd system services running status (`dnsmasq`, `firewall`, `dropbear`, `uhttpd`, `network`).
- [x] Provide Service controls (start, stop, restart, enable/disable status indicators).
- [x] Display System Cron jobs list.
- [x] Display Startup init scripts list (`/etc/init.d/*` priority order & status).

---

### Milestone 11: VPN & Connectivity

- [x] Display VPN interfaces list (WireGuard, OpenVPN, Tailscale, IPSec).
- [x] Display WireGuard peers list (public key, endpoint, allowed IPs, transfer RX/TX, latest handshake).
- [x] Display OpenVPN instances status.
- [x] Display Tailscale daemon connection status & node info.
- [x] Display NextDNS / Encrypted DNS status.

---

### Milestone 12: Package & LuCI App Integration

- [x] OPKG & APK Package Manager compatibility (OPKG `.ipk` for OpenWrt <=23.05 and APK `.apk` for OpenWrt 24.10+).
- [x] Search, install, upgrade, and remove package handling via LuCI RPC.
- [x] Dynamic LuCI App discovery (detect installed `luci-app-*` packages like AdGuard Home, WireGuard, SQM, ttyd, Aria2, Samba4).
- [x] Launch shortcuts and status indicators for installed LuCI apps.

---

### Future Milestones (Incremental Roadmap)

- [ ] **Log Viewer & Tools** (Syslog, dmesg, ping/traceroute).
- [ ] **Backup, Restore & Firmware Upgrade** (Sysupgrade, backup archive generation).
