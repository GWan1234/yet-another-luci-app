// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yet_another_luci_app/main.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:yet_another_luci_app/config/app_config.dart';
import 'package:yet_another_luci_app/services/secure_storage_service.dart';
import 'package:yet_another_luci_app/utils/url_parser.dart';
import 'package:yet_another_luci_app/widgets/luci_toast.dart';
import 'package:yet_another_luci_app/widgets/theme_router_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  final _usernameController = TextEditingController(text: 'root');
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  final _ipFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isCheckingAutoLogin = true;
  bool _passwordVisible = false;
  bool _detectingGatewayIp = false;
  late AnimationController _logoAnimController;
  late AnimationController _progressAnimController;
  bool _isActivatingReviewerMode = false;

  bool _showAutoFillHint = false;
  bool _hasDismissedAutoFillHint = false;
  String? _autoFilledIp;
  Timer? _autoFillHintTimer;

  Future<void> _checkAutoFillHintDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool('hint_dismissed_login_autofill_ip') ?? false;
      if (mounted) {
        setState(() {
          _hasDismissedAutoFillHint = dismissed;
        });
      }
    } catch (_) {
      // Guardrail: ignore storage failure
    }
  }

  Future<void> _dismissAutoFillHint() async {
    _autoFillHintTimer?.cancel();
    _autoFillHintTimer = null;
    if (mounted) {
      setState(() {
        _showAutoFillHint = false;
        _hasDismissedAutoFillHint = true;
      });
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hint_dismissed_login_autofill_ip', true);
    } catch (_) {
      // Guardrail: ignore storage failure
    }
  }

  Future<void> _detectGatewayIp({bool isOnInit = false}) async {
    if (_detectingGatewayIp) return;
    setState(() {
      _detectingGatewayIp = true;
    });

    String? foundGateway;
    bool isMobileData = false;

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      NetworkInterface? wifiOrEthInterface;

      // 1. Check for active Wi-Fi or Ethernet interfaces (wlan, wifi, wl, eth, en, lan)
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        final isWifiOrEth = name.contains('wlan') ||
            name.contains('wifi') ||
            name.contains('wl') ||
            name.contains('eth') ||
            (name.contains('en') && !name.contains('entry')) ||
            name.contains('lan');

        if (isWifiOrEth && interface.addresses.any((a) => !a.isLoopback && a.type == InternetAddressType.IPv4)) {
          wifiOrEthInterface = interface;
          break;
        }
      }

      // 2. Check if mobile data / cellular interface is active and NO Wi-Fi/Ethernet interface is found
      if (wifiOrEthInterface == null) {
        final hasMobileInterface = interfaces.any((interface) {
          final name = interface.name.toLowerCase();
          return name.startsWith('rmnet') ||
              name.startsWith('ccmni') ||
              name.startsWith('pdp') ||
              name.startsWith('wwan') ||
              name.startsWith('cellular') ||
              name.startsWith('mobile') ||
              name.startsWith('gprs') ||
              name.startsWith('3g') ||
              name.startsWith('4g') ||
              name.startsWith('5g') ||
              name.startsWith('lte') ||
              name.startsWith('ppp');
        });

        if (hasMobileInterface) {
          isMobileData = true;
        }
      }

      if (wifiOrEthInterface != null) {
        for (final addr in wifiOrEthInterface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              foundGateway = '${parts[0]}.${parts[1]}.${parts[2]}.1';
              break;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          if (isMobileData) {
            _showAutoFillHint = false;
            if (!isOnInit) {
              context.showToastInfo('Mobile Data Active', subtitle: 'Router IP prefill skipped on cellular connection.', showProgressBar: false);
            }
          } else if (foundGateway != null) {
            _ipController.text = foundGateway;
            _autoFilledIp = foundGateway;
            if (!_hasDismissedAutoFillHint) {
              _showAutoFillHint = true;
              _autoFillHintTimer?.cancel();
              _autoFillHintTimer = null;
            } else {
              _showAutoFillHint = false;
            }
            if (!isOnInit) {
              context.showToastSuccess('Gateway IP Detected', subtitle: foundGateway, showProgressBar: false);
            }
          } else {
            _showAutoFillHint = false;
            if (!isOnInit) {
              context.showToastInfo('No Local Gateway Detected', subtitle: 'Please check your Wi-Fi or Ethernet connection.', showProgressBar: false);
            }
          }
        });
      }
    } catch (_) {
      // Fail silently without clearing inputs
    } finally {
      if (mounted) {
        setState(() {
          _detectingGatewayIp = false;
        });
      }
    }
  }

  void _onOtherFieldActivity() {
    if (_showAutoFillHint && _autoFillHintTimer == null) {
      _startHintTimeout();
    }
  }

  void _startHintTimeout() {
    _autoFillHintTimer?.cancel();
    _autoFillHintTimer = Timer(const Duration(seconds: 4), () {
      _dismissAutoFillHint();
    });
  }

  @override
  void initState() {
    super.initState();
    _ipController.addListener(_onIpChanged);
    _usernameFocusNode.addListener(_onOtherFieldActivity);
    _passwordFocusNode.addListener(_onOtherFieldActivity);
    _usernameController.addListener(_onOtherFieldActivity);
    _passwordController.addListener(_onOtherFieldActivity);
    _checkAutoFillHintDismissed().then((_) {
      _detectGatewayIp(isOnInit: true);
    });
    _checkReviewerModeAndAutoLogin();
    _logoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnimController = AnimationController(
      vsync: this,
      duration: AppConfig.reviewerModeActivationDuration,
    );
    _logoAnimController.forward();
  }

  void _onIpChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<String> _getRouterAddressAutofillHints() {
    return [
      AutofillHints.url,
    ];
  }

  Future<void> _checkReviewerModeAndAutoLogin() async {
    // Check if reviewer mode is enabled
    final secureStorage = SecureStorageService();
    final reviewerModeEnabled = await secureStorage.readValue(
      AppConfig.reviewerModeKey,
    );

    if (reviewerModeEnabled == 'true' && mounted) {
      // Navigate directly to main screen in reviewer mode
      unawaited(Navigator.of(context).pushReplacementNamed('/'));
    } else {
      // Try auto login
      unawaited(_tryAutoLogin());
    }
  }

  void _startReviewerModeActivation() {
    setState(() {
      _isActivatingReviewerMode = true;
    });

    // Start progress animation
    _progressAnimController.forward();

    // Start a timer to check if the user has held for 5 seconds
    Future.delayed(AppConfig.reviewerModeActivationDuration, () {
      if (_isActivatingReviewerMode && mounted) {
        _showReviewerModeDialog();
      }
    });
  }

  void _cancelReviewerModeActivation() {
    setState(() {
      _isActivatingReviewerMode = false;
    });
    // Reset progress animation
    _progressAnimController.reset();
  }

  void _showReviewerModeDialog() {
    _confirmationController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Activate Reviewer Mode?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will enable reviewer mode which bypasses authentication '
                'and provides mock data for app demonstration purposes.',
              ),
              const SizedBox(height: 16),
              const Text(
                'To confirm, type "REVIEWER" below:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmationController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) => TextEditingValue(
                      text: newValue.text.toUpperCase(),
                      selection: newValue.selection,
                    ),
                  ),
                ],
                decoration: const InputDecoration(
                  hintText: 'Type REVIEWER',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _confirmationController.text.trim().toUpperCase() == 'REVIEWER'
                  ? () {
                      Navigator.of(context).pop();
                      _activateReviewerMode();
                    }
                  : null,
              child: const Text('Activate'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _activateReviewerMode() async {
    final appState = ref.read(appStateProvider);
    await appState.setReviewerMode(true);
    await appState.fetchDashboardData();

    if (mounted) {
      unawaited(Navigator.of(context).pushReplacementNamed('/'));
    }
  }

  @override
  void dispose() {
    _autoFillHintTimer?.cancel();
    _usernameFocusNode.removeListener(_onOtherFieldActivity);
    _passwordFocusNode.removeListener(_onOtherFieldActivity);
    _usernameController.removeListener(_onOtherFieldActivity);
    _passwordController.removeListener(_onOtherFieldActivity);
    _ipController.removeListener(_onIpChanged);
    _ipController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    _ipFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _logoAnimController.dispose();
    _progressAnimController.dispose();
    super.dispose();
  }

  Future<void> _tryAutoLogin() async {
    final appState = ref.read(appStateProvider);
    final success = await appState.tryAutoLogin(context: context);
    if (success && mounted) {
      unawaited(Navigator.of(context).pushReplacementNamed('/'));
    } else {
      if (mounted) {
        setState(() {
          _isCheckingAutoLogin = false;
        });
      }
    }
  }

  Future<void> _connect() async {
    if (_formKey.currentState!.validate()) {
      final appState = ref.read(appStateProvider);
      final input = _ipController.text.trim();
      final user = _usernameController.text.trim();
      final pass = _passwordController.text;

      // Parse the input to extract host, port, and protocol
      final parsedUrl = UrlParser.parse(input);

      if (!parsedUrl.isValid) {
        appState.setError(parsedUrl.error ?? 'Invalid address format');
        return;
      }

      FocusScope.of(context).unfocus();

      const actionKey = 'login_connecting';
      if (mounted) {
        context.showToastLoading('Connecting', subtitle: 'Attempting connection to ${parsedUrl.displayUrl}...', actionKey: actionKey);
      }

      try {
        final success = await appState.login(
          parsedUrl.hostWithPort,
          user,
          pass,
          parsedUrl.useHttps,
          fromRouter: false,
          context: context,
        );

        if (success && mounted) {
          LuciToastManager.dismissAllLoading();
          TextInput.finishAutofillContext(shouldSave: true);
          unawaited(Navigator.of(context).pushReplacementNamed('/'));
        } else if (mounted) {
          LuciToastManager.dismissAllLoading();
          final errorMsg = appState.errorMessage ??
              'Connection failed to ${parsedUrl.displayUrl}. Please check host reachability, username, and password.';
          context.showToastError('Connection Failed', subtitle: errorMsg);
        }
      } catch (err) {
        if (mounted) {
          LuciToastManager.dismissAllLoading();
          context.showToastError('Connection Error', subtitle: err.toString());
        }
      } finally {
        // Guarantee loading toast cleanup even if context was unmounted during route push
        LuciToastManager.dismissAllLoading();
      }
    }
  }

  Future<void> _openGitHubIssues() async {
    final url = AppConfig.githubIssuesUrl;
    final success = await launchUrlString(
      url,
      mode: LaunchMode.externalApplication,
    );
    if (!success && mounted) {
      context.showToastError('GitHub Error', subtitle: 'Could not open GitHub issues link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAutoLogin) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Modern gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.18),
                  colorScheme.primaryContainer.withValues(alpha: 0.22),
                  colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),
                        GestureDetector(
                          onLongPress: () {
                            _startReviewerModeActivation();
                          },
                          onLongPressUp: () {
                            _cancelReviewerModeActivation();
                          },
                          child: Column(
                            children: [
                              Column(
                                children: [
                                  const ThemeRouterLogo(
                                    width: 100,
                                    height: 100,
                                    showShadow: true,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Yet Another LuCI App',
                                    style: textTheme.headlineLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Connect to your OpenWrt router',
                                    style: textTheme.titleMedium?.copyWith(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Fast. Secure. Open Source.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _isActivatingReviewerMode
                                    ? Padding(
                                        key: const ValueKey('progress'),
                                        padding: const EdgeInsets.only(top: 24),
                                        child: AnimatedBuilder(
                                          animation: _progressAnimController,
                                          builder: (context, child) {
                                            return Column(
                                              children: [
                                                Text(
                                                  'Hold to activate reviewer mode...',
                                                  style: textTheme.bodySmall
                                                      ?.copyWith(
                                                        color:
                                                            colorScheme.primary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 13,
                                                      ),
                                                ),
                                                const SizedBox(height: 12),
                                                Container(
                                                  width: 280,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    color: colorScheme
                                                        .surfaceContainerHighest
                                                        .withValues(alpha: 0.4),
                                                    border: Border.all(
                                                      color: colorScheme.outline
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    child: LinearProgressIndicator(
                                                      value:
                                                          _progressAnimController
                                                              .value,
                                                      backgroundColor:
                                                          Colors.transparent,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(
                                                            colorScheme.primary
                                                                .withValues(
                                                                  alpha: 0.9,
                                                                ),
                                                          ),
                                                      minHeight: 6,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      )
                                    : const SizedBox(
                                        key: ValueKey('empty'),
                                        height: 0,
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Glassmorphism card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Card(
                              elevation: 8,
                              color: colorScheme.surface.withValues(
                                alpha: 0.85,
                              ),
                              shadowColor: Colors.black.withValues(
                                alpha: 0.08,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: colorScheme.outline.withValues(
                                    alpha: 0.10,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18.0,
                                  vertical: 16.0,
                                ),
                                child: AutofillGroup(
                                  child: Form(
                                  key: _formKey,
                                  child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Tooltip(
                                            message:
                                                'Enter the IP address, hostname, or full URL of your router',
                                            child: TextFormField(
                                              key: const ValueKey('login_ip_field'),
                                              controller: _ipController,
                                              focusNode: _ipFocusNode,
                                              keyboardType: TextInputType.url,
                                              autofillHints: _getRouterAddressAutofillHints(),
                                              decoration: InputDecoration(
                                                labelText: 'Router Address',
                                                border: const OutlineInputBorder(),
                                                prefixIcon: const Icon(
                                                  Icons.router_outlined,
                                                ),
                                                suffixIcon: IconButton(
                                                  icon: _detectingGatewayIp
                                                      ? const SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                        )
                                                      : const Icon(
                                                          Icons.my_location_rounded,
                                                        ),
                                                  tooltip:
                                                      'Auto-detect Wi-Fi Gateway IP',
                                                  onPressed: _detectGatewayIp,
                                                ),
                                                helperText:
                                                    'e.g. 192.168.1.1, router.local:8080',
                                              ),
                                              textInputAction:
                                                  TextInputAction.next,
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return 'Please enter the router address';
                                                }
                                                final parsed = UrlParser.parse(
                                                  value,
                                                );
                                                if (!parsed.isValid) {
                                                  return parsed.error ??
                                                      'Invalid address format';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 250),
                                            transitionBuilder: (child, animation) => SizeTransition(
                                              sizeFactor: animation,
                                              child: FadeTransition(opacity: animation, child: child),
                                            ),
                                            child: (_showAutoFillHint && _autoFilledIp != null)
                                                ? Container(
                                                    key: const ValueKey('autofill_floating_hint'),
                                                    margin: const EdgeInsets.only(top: 4, bottom: 6),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: colorScheme.primaryContainer.withValues(alpha: 0.95),
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(
                                                        color: colorScheme.primary.withValues(alpha: 0.4),
                                                        width: 1.0,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.08),
                                                          blurRadius: 6,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                      children: [
                                                        Icon(
                                                          Icons.arrow_upward_rounded,
                                                          size: 14,
                                                          color: colorScheme.primary,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            'Router IP auto-filled ($_autoFilledIp) as detected from network',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: colorScheme.onPrimaryContainer,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        InkWell(
                                                          onTap: _dismissAutoFillHint,
                                                          borderRadius: BorderRadius.circular(12),
                                                          child: Padding(
                                                            padding: const EdgeInsets.all(2.0),
                                                            child: Icon(
                                                              Icons.close_rounded,
                                                              size: 14,
                                                              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : const SizedBox(
                                                    key: ValueKey('no_autofill_hint'),
                                                    height: 6,
                                                  ),
                                          ),
                                          const SizedBox(height: 10),
                                          Tooltip(
                                            message:
                                                'Enter your router username',
                                            child: TextFormField(
                                              key: const ValueKey('login_user_field'),
                                              controller: _usernameController,
                                              focusNode: _usernameFocusNode,
                                              keyboardType: TextInputType.text,
                                              autofillHints: const [
                                                AutofillHints.username,
                                                AutofillHints.email,
                                              ],
                                              decoration: const InputDecoration(
                                                labelText: 'Username',
                                                border: OutlineInputBorder(),
                                                prefixIcon: Icon(
                                                  Icons.person_outline,
                                                ),
                                                helperText:
                                                    'Default is usually root',
                                              ),
                                              textInputAction:
                                                  TextInputAction.next,
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return 'Please enter the username';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Tooltip(
                                            message:
                                                'Enter your router password',
                                            child: TextFormField(
                                              key: const ValueKey('login_pass_field'),
                                              controller: _passwordController,
                                              focusNode: _passwordFocusNode,
                                              obscureText: !_passwordVisible,
                                              keyboardType: TextInputType.visiblePassword,
                                              autofillHints: const [
                                                AutofillHints.password,
                                              ],
                                              decoration: InputDecoration(
                                                labelText: 'Password',
                                                border:
                                                    const OutlineInputBorder(),
                                                prefixIcon: const Icon(
                                                  Icons.lock_outline,
                                                ),
                                                helperText:
                                                    'Your router password',
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    _passwordVisible
                                                        ? Icons
                                                              .visibility_outlined
                                                        : Icons
                                                              .visibility_off_outlined,
                                                  ),
                                                  onPressed: () => setState(
                                                    () => _passwordVisible =
                                                        !_passwordVisible,
                                                  ),
                                                  tooltip: _passwordVisible
                                                      ? 'Hide password'
                                                      : 'Show password',
                                                ),
                                              ),
                                              textInputAction:
                                                  TextInputAction.done,
                                            ),
                                          ),
                                          Consumer(
                                            builder: (context, ref, child) {
                                              final appState = ref.watch(appStateProvider);
                                              return AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            child: appState.errorMessage != null
                                                ? Padding(
                                                    key: const ValueKey(
                                                      'error',
                                                    ),
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 12.0,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            10,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: colorScheme
                                                            .errorContainer
                                                            .withValues(
                                                              alpha: 1,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.error_outline,
                                                            color: colorScheme
                                                                .onErrorContainer,
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              appState
                                                                  .errorMessage!,
                                                              style: textTheme
                                                                  .bodyMedium
                                                                  ?.copyWith(
                                                                    color: colorScheme
                                                                        .onErrorContainer,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                : const SizedBox.shrink(),
                                          );
                                        },
                                      ),
                                          const SizedBox(height: 16),
                                          Consumer(
                                            builder: (context, ref, child) {
                                              final appState = ref.watch(appStateProvider);
                                              return TweenAnimationBuilder<double>(
                                            duration: const Duration(
                                              milliseconds: 100,
                                            ),
                                            tween: Tween<double>(
                                              begin: 1,
                                              end: appState.isLoading
                                                  ? 0.98
                                                  : 1,
                                            ),
                                            builder: (context, scale, child) {
                                              return Transform.scale(
                                                scale: scale,
                                                child: child,
                                              );
                                            },
                                            child: SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                onPressed: appState.isLoading
                                                    ? null
                                                    : _connect,
                                                style: ElevatedButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 18,
                                                      ),
                                                  textStyle: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                  ),
                                                  elevation: 4,
                                                  backgroundColor:
                                                      colorScheme.primary,
                                                  foregroundColor:
                                                      colorScheme.onPrimary,
                                                ),
                                                child: appState.isLoading
                                                    ? const SizedBox(
                                                        height: 26,
                                                        width: 26,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 3,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                      )
                                                    : Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: const [
                                                          Icon(Icons.login),
                                                          SizedBox(width: 12),
                                                          Text('Connect'),
                                                        ],
                                                      ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                          const SizedBox(height: 16),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  Icons.info_outline,
                                                  size: 20,
                                                  color: colorScheme.primary,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text.rich(
                                                    TextSpan(
                                                      children: [
                                                        TextSpan(
                                                          text: 'Note: ',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 11,
                                                            color: colorScheme.onSurfaceVariant,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text: 'This app communicates exclusively with your local OpenWrt router over LAN/Wi-Fi. No analytics, personal data, or credentials are sent to cloud servers.',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: colorScheme.onSurfaceVariant,
                                                            height: 1.3,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                ),
                              ),
                            ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        Tooltip(
                          message: 'Open GitHub issues for support',
                          child: TextButton(
                            onPressed: _openGitHubIssues,
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                            ),
                            child: const Text('Need help?'),
                          ),
                        ),
                        FutureBuilder<PackageInfo>(
                          future: PackageInfo.fromPlatform(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final info = snapshot.data!;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'Version ${info.version}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
