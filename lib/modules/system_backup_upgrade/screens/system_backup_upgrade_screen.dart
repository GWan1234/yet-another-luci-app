import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';

class SystemBackupUpgradeScreen extends ConsumerStatefulWidget {
  const SystemBackupUpgradeScreen({super.key});

  @override
  ConsumerState<SystemBackupUpgradeScreen> createState() => _SystemBackupUpgradeScreenState();
}

class _SystemBackupUpgradeScreenState extends ConsumerState<SystemBackupUpgradeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _keepSettings = true;
  bool _isProcessing = false;
  String? _statusMessage;

  // Mtdblock state
  List<Map<String, String>> _mtdList = [];
  String? _selectedMtdDevice;

  // Sysupgrade conf state
  final TextEditingController _sysupgradeConfController = TextEditingController();
  bool _isLoadingConf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMtdBlocks();
    _loadSysupgradeConf();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sysupgradeConfController.dispose();
    super.dispose();
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

  Future<void> _loadSysupgradeConf() async {
    setState(() => _isLoadingConf = true);
    final appState = ref.read(appStateProvider);
    final content = await appState.executeRouterCommandOutput('cat', ['/etc/sysupgrade.conf']);
    setState(() {
      _isLoadingConf = false;
      if (content != null) {
        _sysupgradeConfController.text = content.trim();
      } else {
        _sysupgradeConfController.text = '# /etc/sysupgrade.conf\n# Add custom files/directories to preserve during sysupgrade\n/etc/shadow\n/etc/passwd\n';
      }
    });
  }

  Future<void> _saveSysupgradeConf() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Saving /etc/sysupgrade.conf...';
    });

    final content = _sysupgradeConfController.text;
    final appState = ref.read(appStateProvider);
    // Write configuration file
    final success = await appState.executeRouterCommand('sh', ['-c', 'echo "$content" > /etc/sysupgrade.conf']);

    setState(() => _isProcessing = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Successfully updated /etc/sysupgrade.conf'
              : 'Failed to write /etc/sysupgrade.conf',
        ),
        backgroundColor: success ? Colors.teal : Colors.red,
      ),
    );
  }

  Future<void> _showCurrentBackupFileList() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Fetching preserved backup files list...';
    });

    final appState = ref.read(appStateProvider);
    final fileList = await appState.executeRouterCommandOutput('sysupgrade', ['-l']);

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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                    fileList != null && fileList.isNotEmpty
                        ? fileList
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

  Future<void> _handleGenerateBackup() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Generating configuration backup...';
    });

    final appState = ref.read(appStateProvider);
    final success = await appState.executeRouterCommand('sysupgrade', ['-b', '/tmp/backup.tar.gz']);

    setState(() => _isProcessing = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Backup archive created on router at /tmp/backup.tar.gz'
              : 'Failed to generate configuration backup.',
        ),
        backgroundColor: success ? Colors.teal : Colors.red,
      ),
    );
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
      _statusMessage = 'Saving mtdblock ($dev) to /tmp/$filename.bin...';
    });

    final appState = ref.read(appStateProvider);
    final success = await appState.executeRouterCommand('dd', ['if=$dev', 'of=/tmp/$filename.bin']);

    setState(() => _isProcessing = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Saved mtdblock $dev to /tmp/$filename.bin'
              : 'Failed to dump mtdblock $dev',
        ),
        backgroundColor: success ? Colors.teal : Colors.red,
      ),
    );
  }

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
        title: const Text('Flash operations'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Actions'),
            Tab(text: 'Configuration'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildActionsTab(context),
              _buildConfigurationTab(context),
            ],
          ),
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

  Widget _buildActionsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // 1. Backup Section
        _buildSectionCard(
          title: 'Backup',
          icon: Icons.archive_outlined,
          iconColor: Colors.teal,
          description: 'Click "Generate archive" to download a tar archive of the current configuration files.',
          actionWidget: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isProcessing ? null : _handleGenerateBackup,
            child: const Text('Generate archive'),
          ),
        ),

        const SizedBox(height: 16),

        // 2. Restore Section
        _buildSectionCard(
          title: 'Restore',
          icon: Icons.restore_outlined,
          iconColor: Colors.red,
          description:
              'To restore configuration files, you can upload a previously generated backup archive here. To reset the firmware to its initial state, click "Perform reset" (only possible with squashfs images).',
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
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Archive upload tool selected. Choose backup tar archive file.')),
                    );
                  },
                  child: const Text('Upload archive...'),
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
          description: 'Upload a sysupgrade-compatible image here to replace the running firmware.',
          actionWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                title: const Text('Keep settings and current configuration', style: TextStyle(fontSize: 13)),
                value: _keepSettings,
                onChanged: (val) => setState(() => _keepSettings = val ?? true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isProcessing ? null : _handlePerformSysupgrade,
                  child: const Text('Flash image...'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigurationTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sysupgrade Configuration Files (/etc/sysupgrade.conf)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This is a list of shell glob patterns for matching files and directories to include during sysupgrade. Modified files in /etc/config/ and certain other configurations are automatically preserved.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isProcessing ? null : _showCurrentBackupFileList,
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Show current backup file list'),
                ),
                const SizedBox(height: 16),
                if (_isLoadingConf)
                  const Center(child: CircularProgressIndicator())
                else
                  TextField(
                    controller: _sysupgradeConfController,
                    maxLines: 12,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      hintText: '# Add custom files or folders line by line',
                    ),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isProcessing ? null : _saveSysupgradeConf,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
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
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
