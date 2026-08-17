// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Manages manual update checks against GitHub Releases for the Community build flavor.
class UpdateCheckerService {
  static const String _githubReleasesUrl =
      'https://api.github.com/repos/nightcodex7/yet-another-luci-app/releases';

  /// Performs a manual check for updates on GitHub Releases and displays an interactive dialog.
  static Future<void> checkForUpdates(BuildContext context) async {
    // Display progress dialog
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking for updates...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersionStr = info.version.trim();

      final response = await http.get(
        Uri.parse(_githubReleasesUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'YetAnotherLuCIApp/${info.version}',
        },
      ).timeout(const Duration(seconds: 10));

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading
      }

      if (response.statusCode == 200) {
        final rawData = json.decode(response.body);
        Map<String, dynamic>? latestRelease;

        if (rawData is List && rawData.isNotEmpty) {
          final validReleases = rawData
              .whereType<Map<String, dynamic>>()
              .where((r) => r['draft'] != true)
              .toList();
          if (validReleases.isNotEmpty) {
            latestRelease = validReleases.first;
          }
        } else if (rawData is Map<String, dynamic>) {
          latestRelease = rawData;
        }

        if (latestRelease != null) {
          final rawTagName = (latestRelease['tag_name'] as String? ?? '').trim();
          final latestVersionStr = rawTagName.startsWith('v')
              ? rawTagName.substring(1)
              : rawTagName;
          final htmlUrl = latestRelease['html_url'] as String? ??
              'https://github.com/nightcodex7/yet-another-luci-app/releases';
          final releaseNotes =
              latestRelease['body'] as String? ?? 'No release notes available.';

          final bool isUpdateAvailable =
              _isVersionNewer(currentVersionStr, latestVersionStr);

          if (!context.mounted) return;

          if (isUpdateAvailable) {
            _showUpdateAvailableDialog(
              context,
              currentVersion: currentVersionStr,
              latestVersion: latestVersionStr,
              releaseNotes: releaseNotes,
              downloadUrl: htmlUrl,
            );
          } else {
            _showUpToDateDialog(context, currentVersion: currentVersionStr);
          }
        } else {
          if (!context.mounted) return;
          _showErrorDialog(context, 'No releases found on GitHub.');
        }
      } else {
        if (!context.mounted) return;
        _showErrorDialog(context, 'Unable to check for updates at this time.');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading if open
        _showErrorDialog(
          context,
          'Could not connect to GitHub to check for updates.',
        );
      }
    }
  }

  static bool _isVersionNewer(String current, String latest) {
    if (current == latest) return false;

    // Strip build numbers (+1) and prerelease suffixes (-beta) for semantic comparison
    final currentClean = current.split('+').first.split('-').first.trim();
    final latestClean = latest.split('+').first.split('-').first.trim();

    if (currentClean == latestClean) return false;

    final currentParts = currentClean
        .split('.')
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'\D'), '')) ?? 0)
        .toList();
    final latestParts = latestClean
        .split('.')
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'\D'), '')) ?? 0)
        .toList();

    for (int i = 0; i < latestParts.length; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      if (latestParts[i] > currentPart) return true;
      if (latestParts[i] < currentPart) return false;
    }
    return false;
  }

  static void _showUpdateAvailableDialog(
    BuildContext context, {
    required String currentVersion,
    required String latestVersion,
    required String releaseNotes,
    required String downloadUrl,
  }) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Update Available'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text('v$currentVersion',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                  Text('v$latestVersion',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Release Notes:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Text(
                  releaseNotes,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await launchUrlString(downloadUrl,
                  mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download'),
          ),
        ],
      ),
    );
  }

  static void _showUpToDateDialog(BuildContext context,
      {required String currentVersion}) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Up to Date'),
          ],
        ),
        content: Text(
          'You are running the latest version of Yet Another LuCI App (v$currentVersion).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange),
            SizedBox(width: 12),
            Text('Check Failed'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
