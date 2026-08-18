// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../main.dart';
import '../../../state/app_state.dart';

class SystemBackupUpgradeScreen extends ConsumerStatefulWidget {
  const SystemBackupUpgradeScreen({super.key});

  @override
  ConsumerState<SystemBackupUpgradeScreen> createState() => _SystemBackupUpgradeScreenState();
}

class _SystemBackupUpgradeScreenState extends ConsumerState<SystemBackupUpgradeScreen> {
  final bool _keepSettings = true;
  bool _isProcessing = false;
  String? _statusMessage;

  // Mtdblock state
  List<Map<String, String>> _mtdList = [];
  String? _selectedMtdDevice;

  @override
  void initState() {
    super.initState();
    _loadMtdBlocks();
  }

  Future<void> _loadMtdBlocks() async {
    final appState = ref.read(appStateProvider);
    try {
      final mtdOutput = await appState.executeRouterCommandOutput('cat', ['/proc/mtd']);
      if (mtdOutput != null && mtdOutput.isNotEmpty) {
        final lines = mtdOutput.split('\n');
        final parsed = <Map<String, String>>[];
        for (final line in lines) {
          if (line.startsWith('mtd')) {
            final parts = line.split(':');
            final dev = parts[0].trim();
            final rest = parts.length > 1 ? parts[1].trim() : '';
            final match = RegExp(r'"([^"]+)"').firstMatch(rest);
            final name = match != null ? match.group(1)! : dev;
            parsed.add({'device': '/dev/$dev', 'name': '$name ($dev)'});
          }
        }
        if (parsed.isNotEmpty) {
          setState(() {
            _mtdList = parsed;
            _selectedMtdDevice = parsed.first['device'];
          });
          return;
        }
      }
    } catch (_) {}

    // Fallback default choices
    setState(() {
      _mtdList = [
        {'device': '/dev/mtd0', 'name': 'u-boot (mtd0)'},
        {'device': '/dev/mtd1', 'name': 'firmware (mtd1)'},
        {'device': '/dev/mtd2', 'name': 'ubootenv (mtd2)'},
        {'device': '/dev/mtd3', 'name': 'art (mtd3)'},
      ];
      _selectedMtdDevice = '/dev/mtd0';
    });
  }

  Future<void> _showCurrentBackupFileList() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Fetching preserved backup files list...';
    });

    final appState = ref.read(appStateProvider);
    String? fileList = await appState.executeRouterCommandOutput('sh', ['-c', 'sysupgrade -l']);
    if (fileList == null || fileList.trim().isEmpty) {
      fileList = await appState.executeRouterCommandOutput('sysupgrade', ['-l']);
    }
    if (fileList == null || fileList.trim().isEmpty) {
      fileList = await appState.executeRouterCommandOutput('/sbin/sysupgrade', ['-l']);
    }
    if (fileList == null || fileList.trim().isEmpty) {
      fileList = await appState.executeRouterCommandOutput('cat', ['/etc/sysupgrade.conf']);
    }

    setState(() => _isProcessing = false);

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Preserved Backup File List (sysupgrade -l)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: SelectableText(
                    fileList != null && fileList.trim().isNotEmpty
                        ? fileList.trim()
                        : 'No file list returned from router.',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List?> _readRouterFileAsBytes(AppState appState, String filePath) async {
    // Check file size
    final sizeStr = await appState.executeRouterCommandOutput('sh', ['-c', 'wc -c "$filePath"']);
    int? totalSize;
    if (sizeStr != null && sizeStr.trim().isNotEmpty) {
      final parts = sizeStr.trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        totalSize = int.tryParse(parts.first);
      }
    }

    const chunkSize = 32768; // 32 KB chunk
    final List<int> accumulatedBytes = [];

    if (totalSize != null && totalSize > 0) {
      int offset = 0;
      int chunkIndex = 0;
      while (offset < totalSize) {
        final chunkB64 = await appState.executeRouterCommandOutput(
          'sh',
          ['-c', 'dd if="$filePath" bs=$chunkSize skip=$chunkIndex count=1 2>/dev/null | base64'],
        );

        if (chunkB64 != null && chunkB64.trim().isNotEmpty) {
          final cleanB64 = chunkB64.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '').trim();
          try {
            final decoded = base64Decode(cleanB64);
            if (decoded.isNotEmpty) {
              accumulatedBytes.addAll(decoded);
            } else {
              break;
            }
          } catch (_) {
            break;
          }
        } else {
          break;
        }
        offset += chunkSize;
        chunkIndex++;
      }

      if (accumulatedBytes.isNotEmpty) {
        return Uint8List.fromList(accumulatedBytes);
      }
    }

    // Fallback 1: single base64 call
    String? b64Str = await appState.executeRouterCommandOutput('sh', ['-c', 'base64 "$filePath"']);
    if (b64Str == null || b64Str.trim().isEmpty) {
      b64Str = await appState.executeRouterCommandOutput('base64', [filePath]);
    }

    if (b64Str != null && b64Str.trim().isNotEmpty) {
      try {
        final cleanB64 = b64Str.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '').trim();
        return base64Decode(cleanB64);
      } catch (_) {}
    }

    // Fallback 2: hexdump
    final hexStr = await appState.executeRouterCommandOutput('sh', ['-c', 'hexdump -v -e \'1/1 "%02x"\' "$filePath"']);
    if (hexStr != null && hexStr.trim().isNotEmpty) {
      final cleanHex = hexStr.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '').trim();
      final List<int> byteList = [];
      for (var i = 0; i < cleanHex.length; i += 2) {
        if (i + 2 <= cleanHex.length) {
          byteList.add(int.parse(cleanHex.substring(i, i + 2), radix: 16));
        }
      }
      if (byteList.isNotEmpty) {
        return Uint8List.fromList(byteList);
      }
    }

    return null;
  }

  // ignore: unused_element
  Future<void> _handleGenerateBackup() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Generating configuration backup on router...';
    });

    final appState = ref.read(appStateProvider);
    try {
      bool genSuccess = await appState.executeRouterCommand('sh', ['-c', 'sysupgrade -b /tmp/backup.tar.gz']);
      if (!genSuccess) {
        genSuccess = await appState.executeRouterCommand('sysupgrade', ['-b', '/tmp/backup.tar.gz']);
      }
      if (!genSuccess) {
        genSuccess = await appState.executeRouterCommand('sh', ['-c', 'tar -czf /tmp/backup.tar.gz -C / etc/config etc/passwd etc/shadow etc/dropbear etc/uhttpd etc/dnsmasq.conf /etc/sysupgrade.conf']);
      }

      setState(() {
        _statusMessage = 'Downloading backup archive...';
      });

      final bytes = await _readRouterFileAsBytes(appState, '/tmp/backup.tar.gz');
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Failed to read generated backup file from router.');
      }

      String? savePath;
      try {
        final result = await FilePicker.saveFile(
          dialogTitle: 'Save Backup Archive',
          fileName: 'backup-${DateTime.now().millisecondsSinceEpoch ~/ 1000}.tar.gz',
          type: FileType.any,
          bytes: bytes,
        );
        savePath = result?.path;
      } catch (_) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/backup-${DateTime.now().millisecondsSinceEpoch ~/ 1000}.tar.gz');
        await file.writeAsBytes(bytes);
        savePath = file.path;
      }

      if (savePath != null && savePath.isNotEmpty) {
        final saveFile = File(savePath);
        if (!await saveFile.exists()) {
          await saveFile.writeAsBytes(bytes);
        }
      }

      setState(() => _isProcessing = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(savePath != null ? 'Backup archive downloaded to: $savePath' : 'Backup downloaded successfully.'),
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleUploadArchive() async {
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (pickedFiles.isEmpty) {
        return;
      }

      final pickedFile = pickedFiles.first;
      Uint8List? fileBytes;
      if (pickedFile.path != null) {
        fileBytes = await File(pickedFile.path!).readAsBytes();
      }

      if (fileBytes == null || fileBytes.isEmpty) {
        throw Exception('Could not read chosen archive file.');
      }

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Uploading archive to router...';
      });

      final appState = ref.read(appStateProvider);
      final b64Str = base64Encode(fileBytes);

      // Write b64 content to /tmp/uploaded_backup.tar.gz in chunks
      const chunkSize = 30000;
      await appState.executeRouterCommand('sh', ['-c', 'rm -f /tmp/uploaded_backup.tar.gz.b64 /tmp/uploaded_backup.tar.gz']);
      for (var i = 0; i < b64Str.length; i += chunkSize) {
        final end = (i + chunkSize < b64Str.length) ? i + chunkSize : b64Str.length;
        final chunk = b64Str.substring(i, end);
        await appState.executeRouterCommand('sh', ['-c', 'echo -n "$chunk" >> /tmp/uploaded_backup.tar.gz.b64']);
      }

      await appState.executeRouterCommand('sh', ['-c', 'base64 -d /tmp/uploaded_backup.tar.gz.b64 > /tmp/uploaded_backup.tar.gz && rm -f /tmp/uploaded_backup.tar.gz.b64']);

      setState(() {
        _statusMessage = 'Restoring backup configuration...';
      });

      final restoreSuccess = await appState.executeRouterCommand('sysupgrade', ['-r', '/tmp/uploaded_backup.tar.gz']);
      final fallbackSuccess = !restoreSuccess ? await appState.executeRouterCommand('tar', ['-xzf', '/tmp/uploaded_backup.tar.gz', '-C', '/']) : true;

      setState(() => _isProcessing = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((restoreSuccess || fallbackSuccess) ? 'Configuration restored successfully from archive.' : 'Failed to restore backup configuration.'),
          backgroundColor: (restoreSuccess || fallbackSuccess) ? Colors.teal : Colors.red,
        ),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload archive: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleFactoryReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Perform Reset?'),
          ],
        ),
        content: const Text(
          'This will erase all custom configurations and reset firmware to factory default state. Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Perform reset'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Performing factory reset...';
    });

    final appState = ref.read(appStateProvider);
    final success = await appState.executeRouterCommand('firstboot', ['-y']);
    if (success) {
      await appState.executeRouterCommand('reboot', []);
    }

    setState(() => _isProcessing = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Reset initiated. Router is rebooting...'
              : 'Failed to perform reset.',
        ),
        backgroundColor: success ? Colors.orange : Colors.red,
      ),
    );
  }

  Future<void> _handleSaveMtdblock() async {
    if (_selectedMtdDevice == null) return;
    final dev = _selectedMtdDevice!;
    final filename = dev.split('/').last;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Saving mtdblock ($dev)...';
    });

    final appState = ref.read(appStateProvider);
    try {
      final success = await appState.executeRouterCommand('dd', ['if=$dev', 'of=/tmp/$filename.bin']);
      if (!success) throw Exception('Failed to create mtdblock dump on router');

      final bytes = await _readRouterFileAsBytes(appState, '/tmp/$filename.bin');
      if (bytes == null || bytes.isEmpty) throw Exception('Failed to read mtdblock dump from router');

      String? savePath;
      try {
        final result = await FilePicker.saveFile(
          dialogTitle: 'Save mtdblock file',
          fileName: '$filename.bin',
          type: FileType.any,
          bytes: bytes,
        );
        savePath = result?.path;
      } catch (_) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$filename.bin');
        await file.writeAsBytes(bytes);
        savePath = file.path;
      }

      setState(() => _isProcessing = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(savePath != null ? 'Saved $filename.bin to $savePath' : 'Saved $filename.bin'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save mtdblock: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ignore: unused_element
  Future<void> _handlePerformSysupgrade() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue, size: 28),
            SizedBox(width: 10),
            Text('Flash Firmware'),
          ],
        ),
        content: Text(
          'Are you sure you want to flash the firmware image?\n\n'
          'Settings mode: ${_keepSettings ? "Keep settings (-k)" : "Overwrite settings (-n)"}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Flash image'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Flashing firmware via sysupgrade...';
    });

    final appState = ref.read(appStateProvider);
    final args = <String>[];
    if (_keepSettings) {
      args.add('-k');
    } else {
      args.add('-n');
    }

    final success = await appState.executeRouterCommand('sysupgrade', args);

    setState(() => _isProcessing = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Sysupgrade initiated successfully.'
              : 'Failed to trigger sysupgrade.',
        ),
        backgroundColor: success ? Colors.teal : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup / Flash Firmware'),
      ),
      body: Stack(
        children: [
          _buildActionsView(context),
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage ?? 'Processing...',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionsView(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // 1. Backup Section
        _buildSectionCard(
          title: 'Backup',
          icon: Icons.archive_outlined,
          iconColor: Colors.teal,
          description: 'Click "View preserved backup file list" to view files that will be saved during configuration updates.',
          actionWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: null,
                icon: const Icon(Icons.download),
                label: const Text('Generate & Download archive (Future Improvement)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isProcessing ? null : _showCurrentBackupFileList,
                icon: const Icon(Icons.list_alt),
                label: const Text('View preserved backup file list'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Restore Section
        _buildSectionCard(
          title: 'Restore',
          icon: Icons.restore_outlined,
          iconColor: Colors.red,
          description:
              'To restore configuration files, upload a previously generated backup archive file. To reset firmware to its default initial state, click "Perform reset".',
          actionWidget: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isProcessing ? null : _handleFactoryReset,
                  child: const Text('Perform reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isProcessing ? null : _handleUploadArchive,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload archive...'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Save mtdblock contents
        _buildSectionCard(
          title: 'Save mtdblock contents',
          icon: Icons.sd_storage_outlined,
          iconColor: Colors.amber.shade800,
          description: 'Click "Save mtdblock" to download specified mtdblock file. (NOTE: THIS FEATURE IS FOR PROFESSIONALS!)',
          actionWidget: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedMtdDevice,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: _mtdList.map((m) {
                    return DropdownMenuItem<String>(
                      value: m['device'],
                      child: Text(m['name']!, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedMtdDevice = val),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isProcessing ? null : _handleSaveMtdblock,
                child: const Text('Save mtdblock'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 4. Flash new firmware image
        _buildSectionCard(
          title: 'Flash new firmware image',
          icon: Icons.system_update_alt,
          iconColor: Colors.blue,
          isFutureImprovement: true,
          description: 'Upload a sysupgrade-compatible image here to replace the running firmware. (Currently disabled - coming in a future update)',
          actionWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                title: const Text('Keep settings and current configuration', style: TextStyle(fontSize: 13, color: Colors.grey)),
                value: _keepSettings,
                onChanged: null,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: null,
                  child: const Text('Flash image (Future Improvement)'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String description,
    required Widget actionWidget,
    bool isFutureImprovement = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isFutureImprovement)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade400, width: 0.8),
                    ),
                    child: Text(
                      'Future Improvement',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            actionWidget,
          ],
        ),
      ),
    );
  }
}
