import 'package:flutter/material.dart';
import '../models/rpc_result.dart';

class RpcResultUiHelper {
  /// Canonical RPCD ACL remediation command matching README.md
  static const String kRpcdAclRemediationCommand =
      'opkg update\n'
      'opkg install luci-mod-rpc rpcd-mod-luci rpcd-mod-iwinfo luci-mod-status\n'
      '/etc/init.d/rpcd restart';

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

  /// Displays standard RPCD ACL permission remediation guidance dialog.
  static void showPermissionDeniedDialog(BuildContext context, String actionLabel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.security_rounded, color: Colors.amber, size: 36),
        title: const Text('Permission Denied (RPCD ACL)'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your router\'s LuCI RPC user does not have permission to execute "$actionLabel".',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'To grant access, log in to your router via SSH and install/configure the RPCD ACL modules:\n\n'
                '$kRpcdAclRemediationCommand\n\n'
                'Then restart rpcd or re-log into this app.',
                style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
