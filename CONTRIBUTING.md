# Contributing to LuCI Mobile

Thank you for your interest in contributing to LuCI Mobile! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting](#issue-reporting)
- [Feature Requests](#feature-requests)
- [Testing](#testing)
- [Documentation](#documentation)

## Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct. Please be respectful and inclusive in all interactions.

## Getting Started

### Prerequisites

- Flutter SDK (version 3.8.1 or higher)
- Dart SDK
- Git
- An IDE (VS Code, Android Studio, or IntelliJ IDEA)
- OpenWrt router for testing (optional but recommended)

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/nightcodex7/yet-another-luci-app.git
   cd yet-another-luci-app
   ```
3. Add the upstream repository:
   ```bash
   git remote add upstream https://github.com/nightcodex7/yet-another-luci-app.git
   ```

## Development Setup

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Run the App

```bash
flutter run
```

### 3. Set Up Your Development Environment

- Install Flutter and Dart extensions in your IDE
- Configure your IDE for Dart/Flutter development
- Set up a code formatter (dart format)

### 4. Testing Environment

For testing with a real router:
- Set up an OpenWrt router with LuCI web interface
- Configure network access to the router
- Note the router's IP address for testing

## Coding Standards

### Dart/Flutter Standards

- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter analyze` to check for issues
- Format code using `dart format`
- Follow Flutter best practices and conventions

### Code Organization

- Keep files focused and single-purpose
- Use meaningful file and class names
- Group related functionality together
- Follow the existing project structure

### Naming Conventions

- **Files**: Use snake_case (e.g., `api_service.dart`)
- **Classes**: Use PascalCase (e.g., `NetworkInterface`)
- **Variables**: Use camelCase (e.g., `ipAddress`)
- **Constants**: Use SCREAMING_SNAKE_CASE (e.g., `MAX_RETRY_COUNT`)

### Documentation

- Add comments for complex logic
- Document public APIs and methods
- Update README.md for significant changes
- Include examples for new features

## Pull Request Process

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
```

### 2. Make Your Changes

- Write clean, well-documented code
- Follow the coding standards
- Add tests for new functionality
- Update documentation as needed

### 3. Test Your Changes

```bash
# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
dart format .

# Build Android APK
flutter build apk
```

### 4. Commit Your Changes

Use conventional commit messages:

```bash
git commit -m "feat: add new dashboard widget"
git commit -m "fix: resolve authentication timeout issue"
git commit -m "docs: update API documentation"
```

### 5. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then create a Pull Request on GitHub with:

- **Clear title** describing the change
- **Detailed description** of what was changed and why
- **Screenshots** for UI changes
- **Test instructions** for reviewers
- **Related issues** if applicable

### 6. Pull Request Guidelines

- Keep PRs focused and small
- Respond to review comments promptly
- Update PR based on feedback
- Ensure all CI checks pass

## Issue Reporting

### Before Reporting

1. Check existing issues for duplicates
2. Search the documentation
3. Try to reproduce the issue

### Issue Template

When creating an issue, include:

- **Clear title** describing the problem
- **Detailed description** of the issue
- **Steps to reproduce**
- **Expected vs actual behavior**
- **Environment details** (OS, Flutter version, device)
- **Screenshots** if applicable
- **Logs** if available

### Bug Reports

For bug reports, include:

- Flutter version: `flutter --version`
- Device/emulator details
- Steps to reproduce
- Error messages and stack traces
- Router configuration details

### Feature Requests

For feature requests, include:

- Clear description of the feature
- Use cases and benefits
- Mockups or examples if applicable
- Priority level

## Feature Requests

### Guidelines

- Check if the feature already exists
- Consider the impact on existing functionality
- Think about backward compatibility
- Consider the scope and complexity

### Submitting Feature Requests

1. Use the feature request template
2. Provide clear use cases
3. Include mockups or examples
4. Consider implementation complexity

## Testing

### Unit Tests

- Write tests for new functionality
- Maintain good test coverage
- Use meaningful test names
- Mock external dependencies

### Integration Tests

- Test API communication
- Test authentication flows
- Test error handling
- Test different network conditions

### Manual Testing

- Test on different devices
- Test with different router configurations
- Test error scenarios
- Test performance

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run with coverage
flutter test --coverage
```

## Documentation

### Code Documentation

- Document public APIs
- Add inline comments for complex logic
- Update method documentation when changing signatures
- Include examples for complex methods

### User Documentation

- Update README.md for new features
- Add usage examples
- Include troubleshooting guides
- Keep screenshots up to date

### API Documentation

- Document API endpoints
- Include request/response examples
- Document error codes
- Keep API documentation current

## 🛡️ Capability-Detection Architecture & Feature Gating

To ensure seamless support across various OpenWrt releases (from OpenWrt 19.07 up through 24.10+ and SNAPSHOT builds), **Yet Another LuCI App** employs a dynamic capability-detection probing layer.

### Key Guidelines for Contributors:

1. **Avoid Version-String Branching**:
   - Never write code that gates features based on string matching against `system.board.release.version` (e.g. `if (version.contains('24.'))`).
   - Use `RouterCapabilities` (`ref.watch(routerCapabilitiesProvider)` or `appState.capabilities`) instead.

2. **Accessing Capabilities**:
   - Check `capabilities.packageEngine` (`PackageManagerEngine.opkg` vs `.apk`) for software management logic.
   - Check `capabilities.firewallBackend` (`FirewallBackend.fw3` vs `.fw4`) for firewall structures.
   - Check `capabilities.networkModel` (`NetworkModel.dsa` vs `.swconfig`) for switch configuration topology.
   - Check `capabilities.hasObject('ubus_object')` and `capabilities.hasMethod('object', 'method')`.

3. **Conservative Fallback & Caching**:
   - Capabilities are probed once at login/connection time via `rpc.list` and file stat checks (`/etc/apk` vs `/etc/opkg`).
   - Capabilities are cached per-router in encrypted storage (`flutter_secure_storage`).
   - Users can manually re-trigger detection via **Settings ➔ Re-detect Router Capabilities**.
   - If probing fails or times out, the app defaults to conservative/legacy mode (`RouterCapabilities.conservative`) rather than failing or throwing unhandled exceptions.

4. **Reference Implementation — Package Manager Module**:
   - The Package Manager module (`lib/modules/package_manager/`) serves as the canonical reference implementation for consuming `RouterCapabilities` and `RpcResult<T>`.
   - Engine type reads exclusively from `capabilities.packageEngine` (`PackageManagerEngine.opkg`, `.apk`, or `.none`).
   - Shell RPC calls use `RpcResult.classifyExecResult` to evaluate transport status and underlying command exit code / stderr (127 → `methodNotFound`, 126 → `permissionDenied`, non-zero exit code → `failed` with raw stderr attached).
   - If an RPC returns `methodNotFound` against a capability profile, a background capability re-probe is triggered automatically to heal stale caches.

5. **Reference Implementation — Network Interfaces Module (DSA vs swconfig)**:
   - The Interfaces module (`lib/screens/interfaces_screen.dart`, `lib/models/network_topology.dart`) serves as the canonical reference for capability-gated dual-parser architectures.
   - **Genuinely Separate Parsers**: Never use a single merged schema with optional fields across incompatible OpenWrt models. `DsaTopologyParser` processes `bridge-vlan` UCI sections, while `SwconfigTopologyParser` processes legacy `switch_vlan` sections.
   - Parser selection is gated strictly by `capabilities.networkModel`. If `NetworkModel.unknown`, neither parser runs and the UI displays an explicit "topology unavailable" state.
   - **Distinct Empty States**: The UI cleanly differentiates between "Topology Unavailable" (capability model unverified or probe failed) and "Flat Network (0 Configured VLANs)" (legitimate single bridge/flat network).
   - **Shared Error Infrastructure**: Uses `RpcResultUiHelper` (`lib/widgets/rpc_result_dialog.dart`) for standard RPCD ACL remediation dialogs and error alerts across modules.
   - **WAN Protocol Coverage**: Uses `WanProtocol` enum (`dhcp`, `static`, `pppoe`, `dhcpv6`, `dslite`, `map`, `6in4`, `6to4`, `qmi`, `ncm`, `wireguard`). Unrecognized protocols render a generic fallback card displaying raw fields rather than collapsing or failing.

6. **Reference Implementation — Firewall Security Module (fw3/iptables vs fw4/nftables)**:
   - The Firewall module (`lib/modules/firewall_security/`) serves as the third canonical reference implementation for capability-gated dual-parser architectures.
   - **Gated Parsers**: `Fw3FirewallParser` processes iptables-era schemas (`defaults`, `zone`, `forwarding`, `redirect`, `rule`), while `Fw4FirewallParser` processes nftables-era schemas (adds `ipset`/`nftset`, `flow_offloading`, and nftables targets `NOTRACK`, `HELPER`).
   - **Strict Payload Guards**: Enforces that empty or unpopulated payloads (`{}`) evaluate to "Firewall Configuration Unavailable", whereas valid payloads with 0 custom rules evaluate to "No Custom Rules Configured (Default zone policies active)".
   - **Unrecognized Target Fallback**: If a rule references an unrecognized target or custom nftables set, it is rendered with a fallback badge rather than being silently dropped or crashing.

7. **RPCD ACL Architecture Decision**:
   - **No Companion RPCD ACL `.json` File**: The project deliberately does not ship a separate companion RPCD ACL configuration `.json` file in the repository.
   - **Reasoning**: In-app ACL remediation dialogs built across modules (`RpcResultUiHelper` in `lib/widgets/rpc_result_dialog.dart`) surface exact remediation commands (`opkg install luci-mod-rpc rpcd-mod-luci rpcd-mod-iwinfo luci-mod-status`) directly at the point of RPC failure. This provides immediate, actionable guidance without forcing users to discover and install a separately versioned ACL file.
   - **Single Source of Truth**: All RPCD ACL dialogs reference `RpcResultUiHelper.kRpcdAclRemediationCommand`, keeping error remediation guidance unified with `README.md`.

## Review Process

### Code Review Guidelines

- Be constructive and respectful
- Focus on code quality and functionality
- Consider security implications
- Check for performance issues
- Verify documentation updates

### Review Checklist

- [ ] Code follows style guidelines
- [ ] Tests are included and pass
- [ ] Documentation is updated
- [ ] No security vulnerabilities
- [ ] Performance is acceptable
- [ ] Backward compatibility maintained

## Release Process

### Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

- [ ] All tests pass
- [ ] Documentation is updated
- [ ] Changelog is updated
- [ ] Version is bumped
- [ ] Release notes are prepared

## Getting Help

### Questions and Support

- Check the documentation first
- Search existing issues
- Ask questions in discussions
- Join our community channels

### Mentorship

New contributors are welcome! We're happy to:

- Help you get started
- Review your first PR
- Provide guidance on complex features
- Answer questions about the codebase

## Recognition

Contributors will be recognized in:

- Project README
- Release notes
- Contributor hall of fame
- GitHub contributors page

Thank you for contributing to LuCI Mobile! Your contributions help make this project better for everyone. 