// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:yet_another_luci_app/config/app_config.dart';
import 'package:yet_another_luci_app/main.dart';
import 'package:yet_another_luci_app/services/secure_storage_service.dart';
import 'package:yet_another_luci_app/utils/url_parser.dart';
import 'package:yet_another_luci_app/widgets/luci_toast.dart';
import 'package:yet_another_luci_app/widgets/theme_router_logo.dart';
import 'package:yet_another_luci_app/widgets/luci_smooth_spinner.dart';
import 'package:yet_another_luci_app/screens/main_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final bool skipAutoLoginCheck;
  const LoginScreen({super.key, this.skipAutoLoginCheck = false});

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
  final _scrollController = ScrollController();

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
            if (_ipController.text.trim().isEmpty) {
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

  Future<bool> _loadSavedCredentialsIntoForm() async {
    try {
      final secureStorage = SecureStorageService();
      final creds = await secureStorage.getCredentials();
      final savedIp = creds['ipAddress'];
      final savedUser = creds['username'];
      final savedPass = creds['password'];

      if (mounted) {
        setState(() {
          if (savedIp != null && savedIp.isNotEmpty) {
            _ipController.text = savedIp;
          }
          if (savedUser != null && savedUser.isNotEmpty) {
            _usernameController.text = savedUser;
          }
          if (savedPass != null && savedPass.isNotEmpty) {
            _passwordController.text = savedPass;
          }
        });
      }

      return savedIp != null && savedIp.isNotEmpty && savedPass != null && savedPass.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _ipController.addListener(_onIpChanged);
    _ipFocusNode.addListener(() => _handleFieldFocus(_ipFocusNode));
    _usernameFocusNode.addListener(() => _handleFieldFocus(_usernameFocusNode));
    _passwordFocusNode.addListener(() => _handleFieldFocus(_passwordFocusNode));
    _usernameController.addListener(_onOtherFieldActivity);
    _passwordController.addListener(_onOtherFieldActivity);
    _loadSavedCredentialsIntoForm().then((_) {
      // Start auto-login only after credentials are loaded, eliminating the
      // race between form pre-fill and the auto-login loading state transition.
      if (!widget.skipAutoLoginCheck) {
        _checkReviewerModeAndAutoLogin();
      }
      _checkAutoFillHintDismissed().then((_) {
        // Only run gateway detection if no saved IP is already in the field
        if (_ipController.text.isEmpty) {
          _detectGatewayIp(isOnInit: true);
        }
      });
    });
    if (widget.skipAutoLoginCheck) {
      _isCheckingAutoLogin = false;
    }
    _logoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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

  void _navigateToMainScreen(BuildContext context) {
    if (!mounted) return;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (disableAnimations) return child;
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          final scaleAnimation = Tween<double>(begin: 0.97, end: 1.0).animate(curved);
          return RepaintBoundary(
            child: FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            ),
          );
        },
        transitionDuration: disableAnimations ? Duration.zero : const Duration(milliseconds: 350),
      ),
    );
  }

  Future<void> _checkReviewerModeAndAutoLogin() async {
    // Check if reviewer mode is enabled
    final secureStorage = SecureStorageService();
    final reviewerModeEnabled = await secureStorage.readValue(
      AppConfig.reviewerModeKey,
    );

    if (reviewerModeEnabled == 'true' && mounted) {
      // Navigate directly to main screen in reviewer mode
      _navigateToMainScreen(context);
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
      _navigateToMainScreen(context);
    }
  }

  void _handleFieldFocus(FocusNode focusNode) {
    if (focusNode.hasFocus) {
      _onOtherFieldActivity();
      final targetContext = focusNode.context;
      if (targetContext == null) return;
      Future.delayed(const Duration(milliseconds: 180), () {
        if (!mounted || !targetContext.mounted) return;
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: 0.5,
        );
      });
    }
  }

  @override
  void dispose() {
    _autoFillHintTimer?.cancel();
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
    _scrollController.dispose();
    _logoAnimController.dispose();
    _progressAnimController.dispose();
    super.dispose();
  }

  Future<void> _tryAutoLogin() async {
    final hasSavedCreds = await _loadSavedCredentialsIntoForm();
    if (!mounted) return;
    final appState = ref.read(appStateProvider);
    final success = await appState.tryAutoLogin(context: context);
    if (!mounted) return;
    if (success) {
      _navigateToMainScreen(context);
    } else {
      setState(() {
        _isCheckingAutoLogin = false;
      });
      if (mounted && hasSavedCreds) {
        context.showToastError(
          'Auto-Login Failed',
          subtitle: 'Connection failed. Check your Wi-Fi and router credentials.',
          showProgressBar: false,
        );
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
          _navigateToMainScreen(context);
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

  void _showHelpBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.help_outline_rounded, color: colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Login Troubleshooting Guide',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildHelpItem(
              context,
              icon: Icons.wifi_find_rounded,
              title: 'Connect to Router Wi-Fi / Network',
              description: 'Ensure your device is directly connected to your router\'s Wi-Fi network or local subnet.',
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              context,
              icon: Icons.lan_rounded,
              title: 'Verify Gateway IP Address',
              description: 'Most OpenWrt routers use 192.168.1.1 or 192.168.0.1. Check your network settings if custom subnets are used.',
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              context,
              icon: Icons.lock_person_rounded,
              title: 'LuCI Admin Credentials',
              description: 'Use the same username (default: root) and password as your standard LuCI browser web interface.',
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              context,
              icon: Icons.https_rounded,
              title: 'Self-Signed SSL / HTTPS Settings',
              description: 'If your router uses HTTPS with self-signed SSL certificates, open Advanced Options and toggle "Use HTTPS".',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openGitHubIssues();
                    },
                    icon: const Icon(Icons.bug_report_rounded, size: 18),
                    label: const Text('GitHub Issues'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Got It'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    final meshColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);

    if (_isCheckingAutoLogin) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const ThemeRouterLogo(width: 64, height: 64),
              ),
              const SizedBox(height: 24),
              LuciSmoothSpinner(
                size: 24,
                strokeWidth: 2.5,
                color: primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Signing in to your router...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final appState = ref.read(appStateProvider);

        if (appState.sysauth != null || appState.reviewerModeEnabled || appState.selectedRouter != null) {
          // Return smoothly to active session main screen
          _navigateToMainScreen(context);
        } else {
          // Check if reviewer mode or saved session is enabled
          final secureStorage = SecureStorageService();
          final reviewerModeEnabled = await secureStorage.readValue(
            AppConfig.reviewerModeKey,
          );

          if (reviewerModeEnabled == 'true') {
            await appState.setReviewerMode(true);
            await appState.fetchDashboardData();
            if (context.mounted) {
              _navigateToMainScreen(context);
            }
          } else {
            // Exit app gracefully to OS home screen rather than showing a blank route
            await SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
        children: [
          // Elegant Matte Network Topology Mesh Background Graphic
          Positioned.fill(
            child: CustomPaint(
              painter: _NetworkTopologyMeshPainter(meshColor: meshColor),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
                final isKeyboardOpen = viewInsetsBottom > 0;
                final isConstrained = constraints.maxHeight < 580;
                final shouldAllowScroll = isKeyboardOpen || isConstrained;

                return SingleChildScrollView(
                  controller: _scrollController,
                  physics: shouldAllowScroll
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 36,
                      maxWidth: 420,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 8),

                          // Header Lockup: Console Identity
                          GestureDetector(
                            onLongPress: _startReviewerModeActivation,
                            onLongPressUp: _cancelReviewerModeActivation,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainer,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const ThemeRouterLogo(
                                    width: 68,
                                    height: 68,
                                    showShadow: false,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Yet Another LuCI App',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onSurface,
                                    letterSpacing: 0.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'OpenWrt Router Console',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),

                                // Console Technical Tag
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'DIRECT LAN CONNECTION',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: primaryColor,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: _isActivatingReviewerMode
                                      ? Padding(
                                          key: const ValueKey('progress'),
                                          padding: const EdgeInsets.only(top: 14),
                                          child: AnimatedBuilder(
                                            animation: _progressAnimController,
                                            builder: (context, child) {
                                              return Column(
                                                children: [
                                                  Text(
                                                    'Hold to activate reviewer mode...',
                                                    style: theme.textTheme.bodySmall?.copyWith(
                                                      color: primaryColor,
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Container(
                                                    width: 240,
                                                    height: 5,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(10),
                                                      color: colorScheme.surfaceContainerHighest,
                                                      border: Border.all(
                                                        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(10),
                                                      child: LinearProgressIndicator(
                                                        value: _progressAnimController.value,
                                                        backgroundColor: Colors.transparent,
                                                        valueColor: AlwaysStoppedAnimation<Color>(
                                                          primaryColor,
                                                        ),
                                                        minHeight: 5,
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
                          const SizedBox(height: 18),

                          // Matte Form Card (Network Endpoint Console)
                          Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(18.0),
                            child: AutofillGroup(
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    // Network Target Endpoint Banner
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.lan_outlined,
                                          size: 15,
                                          color: primaryColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'TARGET ROUTER ENDPOINT',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Router Address Field
                                    Tooltip(
                                      message: 'Enter the IP address, hostname, or full URL of your router',
                                      child: TextFormField(
                                        key: const ValueKey('login_ip_field'),
                                        controller: _ipController,
                                        focusNode: _ipFocusNode,
                                        keyboardType: TextInputType.url,
                                        scrollPadding: EdgeInsets.only(
                                          bottom: viewInsetsBottom + 120.0,
                                          top: 20.0,
                                        ),
                                        autofillHints: _getRouterAddressAutofillHints(),
                                        decoration: InputDecoration(
                                          labelText: 'Router Address',
                                          filled: true,
                                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(
                                              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(
                                              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(
                                              color: primaryColor,
                                              width: 1.5,
                                            ),
                                          ),
                                          prefixIcon: Icon(
                                            Icons.router_outlined,
                                            color: primaryColor,
                                          ),
                                          suffixIcon: IconButton(
                                            icon: _detectingGatewayIp
                                                ? LuciSmoothSpinner(
                                                    size: 18,
                                                    strokeWidth: 2,
                                                    color: primaryColor,
                                                  )
                                                : Icon(
                                                    Icons.my_location_rounded,
                                                    color: primaryColor,
                                                  ),
                                            tooltip: 'Auto-detect Wi-Fi Gateway IP',
                                            onPressed: () => _detectGatewayIp(),
                                          ),
                                          helperText: 'e.g. 192.168.1.1, router.local:8080',
                                        ),
                                        textInputAction: TextInputAction.next,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter the router address';
                                          }
                                          final parsed = UrlParser.parse(value);
                                          if (!parsed.isValid) {
                                            return parsed.error ?? 'Invalid address format';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),

                                    // Auto-fill hint banner
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 250),
                                      transitionBuilder: (child, animation) => SizeTransition(
                                        sizeFactor: animation,
                                        child: FadeTransition(opacity: animation, child: child),
                                      ),
                                      child: (_showAutoFillHint && _autoFilledIp != null)
                                          ? Container(
                                              key: const ValueKey('autofill_floating_hint'),
                                              margin: const EdgeInsets.only(top: 8, bottom: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: primaryColor.withValues(alpha: 0.4),
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.auto_awesome_rounded,
                                                    size: 14,
                                                    color: primaryColor,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Auto-filled $_autoFilledIp from active network',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: colorScheme.onSurface,
                                                      ),
                                                    ),
                                                  ),
                                                  InkWell(
                                                    onTap: _dismissAutoFillHint,
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(3.0),
                                                      child: Icon(
                                                        Icons.close_rounded,
                                                        size: 15,
                                                        color: colorScheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : const SizedBox(
                                              key: ValueKey('no_autofill_hint'),
                                              height: 8,
                                            ),
                                    ),

                                    const SizedBox(height: 10),

                                    // Username Field
                                    Tooltip(
                                      message: 'Enter your router username',
                                      child: TextFormField(
                                        key: const ValueKey('login_user_field'),
                                        controller: _usernameController,
                                        focusNode: _usernameFocusNode,
                                        keyboardType: TextInputType.text,
                                        scrollPadding: EdgeInsets.only(
                                          bottom: viewInsetsBottom + 120.0,
                                          top: 20.0,
                                        ),
                                        autofillHints: const [
                                          AutofillHints.username,
                                          AutofillHints.email,
                                        ],
                                        decoration: InputDecoration(
                                          labelText: 'Username',
                                          filled: true,
                                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(
                                              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(
                                              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(
                                              color: primaryColor,
                                              width: 1.5,
                                            ),
                                          ),
                                          prefixIcon: Icon(
                                            Icons.person_outlined,
                                            color: primaryColor,
                                          ),
                                          helperText: 'Default is usually root',
                                        ),
                                        textInputAction: TextInputAction.next,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter the username';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),

                                    const SizedBox(height: 10),

                                    // Password Field
                                    Tooltip(
                                      message: 'Enter your router password',
                                      child: TextFormField(
                                        key: const ValueKey('login_pass_field'),
                                        controller: _passwordController,
                                        focusNode: _passwordFocusNode,
                                        obscureText: !_passwordVisible,
                                        keyboardType: TextInputType.visiblePassword,
                                        scrollPadding: EdgeInsets.only(
                                          bottom: viewInsetsBottom + 120.0,
                                          top: 20.0,
                                        ),
                                        autofillHints: const [
                                          AutofillHints.password,
                                        ],
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          filled: true,
                                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(
                                              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(
                                              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(
                                              color: primaryColor,
                                              width: 1.5,
                                            ),
                                          ),
                                          prefixIcon: Icon(
                                            Icons.lock_outlined,
                                            color: primaryColor,
                                          ),
                                          helperText: 'Your router password',
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _passwordVisible
                                                  ? Icons.visibility_outlined
                                                  : Icons.visibility_off_outlined,
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                            onPressed: () => setState(
                                              () => _passwordVisible = !_passwordVisible,
                                            ),
                                            tooltip: _passwordVisible ? 'Hide password' : 'Show password',
                                          ),
                                        ),
                                        textInputAction: TextInputAction.done,
                                      ),
                                    ),

                                    // Error Message Banner
                                    Consumer(
                                      builder: (context, ref, child) {
                                        final appState = ref.watch(appStateProvider);
                                        return AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 300),
                                          child: appState.errorMessage != null
                                              ? Padding(
                                                  key: const ValueKey('error'),
                                                  padding: const EdgeInsets.only(top: 14.0),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: colorScheme.errorContainer,
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: colorScheme.error.withValues(alpha: 0.3),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.error_outline_rounded,
                                                          color: colorScheme.onErrorContainer,
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Text(
                                                            appState.errorMessage!,
                                                            style: theme.textTheme.bodyMedium?.copyWith(
                                                              color: colorScheme.onErrorContainer,
                                                              fontWeight: FontWeight.w600,
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

                                    const SizedBox(height: 18),

                                    // Matte Tactile Connect Action Button
                                    Consumer(
                                      builder: (context, ref, child) {
                                        final appState = ref.watch(appStateProvider);
                                        return TweenAnimationBuilder<double>(
                                          duration: const Duration(milliseconds: 100),
                                          tween: Tween<double>(
                                            begin: 1,
                                            end: appState.isLoading ? 0.98 : 1,
                                          ),
                                          builder: (context, scale, child) {
                                            return Transform.scale(
                                              scale: scale,
                                              child: child,
                                            );
                                          },
                                          child: FilledButton(
                                            onPressed: appState.isLoading ? null : _connect,
                                            style: FilledButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 16),
                                              backgroundColor: primaryColor,
                                              foregroundColor: colorScheme.onPrimary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: appState.isLoading
                                                ? LuciSmoothSpinner(
                                                    size: 22,
                                                    strokeWidth: 2.5,
                                                    color: colorScheme.onPrimary,
                                                  )
                                                : Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: const [
                                                      Icon(
                                                        Icons.arrow_forward_rounded,
                                                        size: 18,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'CONNECT TO ROUTER',
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.bold,
                                                          letterSpacing: 0.6,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        );
                                      },
                                    ),

                                    const SizedBox(height: 14),

                                    // Direct Local Connection Security Assurance Panel
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.shield_outlined,
                                            size: 18,
                                            color: primaryColor,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: 'Direct Local Connection: ',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                      color: colorScheme.onSurface,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: 'Communicates exclusively with your local OpenWrt router over LAN/Wi-Fi. Zero analytics or cloud servers.',
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

                          const Spacer(),
                          const SizedBox(height: 14),

                          // Need Help Link
                          Tooltip(
                            message: 'Open troubleshooting guide',
                            child: TextButton(
                              onPressed: () => _showHelpBottomSheet(context),
                              style: TextButton.styleFrom(
                                foregroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: const Text(
                                'Need help?',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),

                          // Version Display
                          FutureBuilder<PackageInfo>(
                            future: PackageInfo.fromPlatform(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox.shrink();
                              }
                              final info = snapshot.data!;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Text(
                                  'Version ${info.version}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
}


/// Attractive Network Topology Mesh Background Graphic
class _NetworkTopologyMeshPainter extends CustomPainter {
  final Color meshColor;

  _NetworkTopologyMeshPainter({required this.meshColor});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = meshColor
      ..strokeWidth = 1.0;

    final nodePaint = Paint()
      ..color = meshColor.withValues(alpha: (meshColor.a * 1.8).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    const double spacing = 64.0;
    final int cols = (size.width / spacing).ceil() + 1;
    final int rows = (size.height / spacing).ceil() + 1;

    // Generate deterministic grid node offsets for an architectural isometric mesh
    final List<List<Offset>> grid = [];

    for (int r = 0; r < rows; r++) {
      final List<Offset> row = [];
      for (int c = 0; c < cols; c++) {
        final double x = c * spacing + (r % 2 == 1 ? spacing * 0.5 : 0.0);
        final double y = r * spacing * 0.866; // Hexagonal vertical ratio
        row.add(Offset(x, y));
      }
      grid.add(row);
    }

    // Draw isometric connecting lines
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final Offset pt = grid[r][c];

        // Right connection
        if (c + 1 < cols) {
          canvas.drawLine(pt, grid[r][c + 1], linePaint);
        }
        // Down-right connection
        if (r + 1 < rows) {
          if (r % 2 == 0) {
            if (c < cols) canvas.drawLine(pt, grid[r + 1][c], linePaint);
            if (c - 1 >= 0) canvas.drawLine(pt, grid[r + 1][c - 1], linePaint);
          } else {
            if (c < cols) canvas.drawLine(pt, grid[r + 1][c], linePaint);
            if (c + 1 < cols) canvas.drawLine(pt, grid[r + 1][c + 1], linePaint);
          }
        }

        // Draw small node points at alternate intersections
        if ((r + c) % 3 == 0) {
          canvas.drawCircle(pt, 2.0, nodePaint);
        }
      }
    }

    // Border tick marks / scale indicators for technical feel
    final tickPaint = Paint()
      ..color = meshColor.withValues(alpha: (meshColor.a * 2.0).clamp(0.0, 1.0))
      ..strokeWidth = 1.2;

    const double tickLen = 6.0;
    for (double y = 40; y < size.height - 40; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(tickLen, y), tickPaint);
      canvas.drawLine(Offset(size.width - tickLen, y), Offset(size.width, y), tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkTopologyMeshPainter oldDelegate) {
    return oldDelegate.meshColor != meshColor;
  }
}
