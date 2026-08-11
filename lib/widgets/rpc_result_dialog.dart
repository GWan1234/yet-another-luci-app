import 'package:flutter/material.dart';
import '../models/rpc_result.dart';
import '../state/app_state.dart';

class RpcResultUiHelper {
  /// Canonical RPCD ACL remediation command supporting both APK (OpenWrt 25.x+) and OPKG (OpenWrt 24.10 and earlier)
  static const String kRpcdAclRemediationCommand =
      '# OpenWrt 25.x / snapshot (APK):\n'
      'apk update && apk add luci-mod-rpc rpcd-mod-luci rpcd-mod-iwinfo luci-mod-status && /etc/init.d/rpcd restart\n\n'
      '# OpenWrt 24.10 and earlier (OPKG):\n'
      'opkg update && opkg install luci-mod-rpc rpcd-mod-luci rpcd-mod-iwinfo luci-mod-status && /etc/init.d/rpcd restart';

  /// Displays appropriate user feedback (snackbars or dialogs) based on RpcResult status.
  static void handleRpcResult<T>(
    BuildContext context,
    RpcResult<T> result,
    String actionLabel,
  ) {
    if (!context.mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$actionLabel completed successfully.')),
      );
      return;
    }

    if (result.isPermissionDenied) {
      showPermissionDeniedDialog(context, actionLabel);
      return;
    }

    if (result.isMethodNotFound) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action "$actionLabel" is unavailable on this router capabilities profile.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    if (result.status == RpcCallStatus.networkError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error during $actionLabel: ${result.errorMessage}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    // Generic RPC or command execution failure
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 36),
        title: Text('Failed: $actionLabel'),
        content: SingleChildScrollView(
          child: Text(
            result.errorMessage ?? 'An unknown error occurred on the router during operation.',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Displays standard RPCD ACL permission remediation guidance dialog with optional automatic fix button.
  static void showPermissionDeniedDialog(BuildContext context, String actionLabel) {
    showDialog(
      context: context,
      builder: (ctx) => _PermissionDeniedDialog(actionLabel: actionLabel),
    );
  }
}

class _PermissionDeniedDialog extends StatefulWidget {
  final String actionLabel;

  const _PermissionDeniedDialog({required this.actionLabel});

  @override
  State<_PermissionDeniedDialog> createState() => _PermissionDeniedDialogState();
}

class _PermissionDeniedDialogState extends State<_PermissionDeniedDialog> {
  bool _isFixing = false;
  String? _errorMessage;

  Future<void> _handleAutoFix() async {
    setState(() {
      _isFixing = true;
      _errorMessage = null;
    });

    try {
      final success = await AppState.instance.autoFixPermissions(context: context);
      if (!mounted) return;
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissions fixed successfully! Capabilities re-probed.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isFixing = false;
          _errorMessage =
              'Automatic fix failed (session lacks file.exec rights). Please run the manual SSH command below.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFixing = false;
        _errorMessage = 'Automatic fix encountered an error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: const Icon(Icons.security_rounded, color: Colors.amber, size: 36),
      title: const Text('Permission Denied (RPCD ACL)'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your router\'s LuCI RPC user does not have permission to execute "${widget.actionLabel}".',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'To grant access, log in to your router via SSH and install/configure the RPCD ACL modules:\n\n'
              '${RpcResultUiHelper.kRpcdAclRemediationCommand}\n\n'
              'Then restart rpcd or re-log into this app.',
              style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
      actions: [
        if (_isFixing)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          FilledButton.icon(
            onPressed: _handleAutoFix,
            icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
            label: const Text('Fix Automatically'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel / Close'),
        ),
      ],
    );
  }
}
