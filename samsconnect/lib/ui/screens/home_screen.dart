import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../providers/connection_provider.dart';
import '../../providers/mirroring_provider.dart';
import '../../providers/file_transfer_provider.dart';
import '../../providers/device_control_provider.dart';
import '../../providers/settings_provider.dart';
import '../../data/models/device.dart';
import '../../data/models/mirroring_config.dart';
import '../../services/mirroring/mirroring_service.dart';
import '../widgets/device_card.dart';
import '../widgets/dashboard/dashboard_summary_view.dart';
import '../widgets/dashboard/apps_manager_view.dart';
import '../widgets/dashboard/file_browser_view.dart';
import '../widgets/dialogs/pattern_unlock_dialog.dart';
import '../widgets/layout/main_layout.dart';
import '../widgets/layout/sidebar.dart';
import '../widgets/layout/top_bar.dart';
import '../widgets/dialogs/about_developer_dialog.dart';
import '../../services/updates/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedId = 'library_devices';

  @override
  void initState() {
    super.initState();

    // Setup device change listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ConnectionProvider>();
      provider.onDeviceChanged = (message) {
        if (!mounted) return;

        // Clear previous snackbars to show the new one immediately
        ScaffoldMessenger.of(context).clearSnackBars();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  message.contains('Disconnected')
                      ? Icons.link_off
                      : Icons.link,
                  color: Theme.of(context).colorScheme.onInverseSurface,
                ),
                const SizedBox(width: 12),
                Text(message),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            width: 400,
            duration: const Duration(seconds: 2),
            backgroundColor: Theme.of(context).colorScheme.inverseSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      };
    });

    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    final updateService = UpdateService();
    final update = await updateService.checkForUpdates();

    if (update != null && mounted) {
      _showUpdateDialog(update);
    }
  }

  void _showUpdateDialog(UpdateInfo update) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue),
            SizedBox(width: 12),
            Text('Update Available'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'A new version of SamsConnect is available: v${update.version}+${update.buildNumber}'),
            const SizedBox(height: 12),
            if (update.releaseNotes != null) ...[
              const Text('Release Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(update.releaseNotes!),
              const SizedBox(height: 12),
            ],
            const Text('Would you like to download it now?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              if (update.downloadUrl != null) {
                launchUrl(Uri.parse(update.downloadUrl!));
              }
              Navigator.pop(context);
            },
            child: const Text('Download Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshDevices() async {
    final provider = context.read<ConnectionProvider>();
    await provider.refreshDevices();
  }

  void _handleSidebarSelection(String id) {
    if (id.startsWith('select_device_')) {
      final deviceId = id.substring(14); // 'select_device_'.length
      final provider = context.read<ConnectionProvider>();

      // Find the device safely
      final index = provider.availableDevices.indexWhere(
        (d) => d.id == deviceId,
      );
      if (index == -1) return;

      final device = provider.availableDevices[index];

      if (provider.connectedDevice?.id != device.id) {
        _connectToDevice(device);
        // Switch to summary for the new device
        setState(() => _selectedId = 'device_summary');
        return;
      }
      // If already connected, clicking the parent name shows summary
      setState(() => _selectedId = 'device_summary');
      return;
    }

    setState(() {
      _selectedId = id;
    });

    // Auto-start mirroring when device_screen is selected
    if (id == 'device_screen') {
      final provider = context.read<ConnectionProvider>();
      if (provider.connectedDevice != null) {
        final device = provider.connectedDevice!;
        final mirroringProvider = context.read<MirroringProvider>();

        // Only start if not already running
        if (mirroringProvider.status != MirroringStatus.running) {
          // Use Future.microtask to ensure the view is rendered first
          Future.microtask(() => _startMirroring(device));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, child) {
        final deviceName = provider.connectedDevice?.name ?? 'Device';

        final sidebarItems = [
          SidebarItem(
            id: 'library',
            label: 'Library',
            icon: Icons.library_books,
            children: [
              SidebarItem(
                id: 'library_devices',
                label: 'Devices',
                icon: Icons.phonelink,
              ),
            ],
          ),
          ...provider.availableDevices.map((device) {
            final isActive = provider.connectedDevice?.id == device.id;
            return SidebarItem(
              id: 'select_device_${device.id}',
              label: device.name,
              icon: device.platform == MobilePlatform.ios
                  ? Icons.apple
                  : Icons.smartphone,
              children: isActive
                  ? [
                      const SidebarItem(
                        id: 'device_summary',
                        label: 'Summary',
                        icon: Icons.dashboard,
                      ),
                      const SidebarItem(
                        id: 'device_apps',
                        label: 'Applications',
                        icon: Icons.apps,
                      ),
                      const SidebarItem(
                        id: 'device_files',
                        label: 'Files',
                        icon: Icons.folder,
                      ),
                      if (device.platform == MobilePlatform.android)
                        const SidebarItem(
                          id: 'device_screen',
                          label: 'Live Screen',
                          icon: Icons.screen_share,
                        ),
                      if (device.platform == MobilePlatform.ios)
                        const SidebarItem(
                          id: 'device_screen',
                          label: 'Mirroring',
                          icon: Icons.cast,
                        ),
                    ]
                  : [],
            );
          }),
        ];

        // Determine Title and Actions based on selection
        String title = 'Devices';
        List<Widget> actions = [];

        switch (_selectedId) {
          case 'library_devices':
            title = 'Device Manager';
            actions = [
              TopBarAction(
                icon: Icons.refresh,
                label: 'Refresh',
                onPressed: _refreshDevices,
              ),
            ];
            break;

          case 'device_summary':
            title = '$deviceName - Summary';
            break;
        }

        return MainLayout(
          sidebarItems: sidebarItems,
          selectedSidebarId: _selectedId,
          onSidebarItemSelected: _handleSidebarSelection,
          title: title,
          actions: actions,
          onThemeToggle: () {
            final settings = context.read<SettingsProvider>();
            settings.toggleDarkMode(!settings.darkMode);
          },
          onSettingsTap: () => _showSettingsDialog(context),
          child: DropTarget(
            onDragDone: (details) =>
                _handleDroppedFiles(context, details, provider.connectedDevice),
            child: Stack(
              children: [_buildContent(provider), _buildTransferOverlay()],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(ConnectionProvider provider) {
    final Map<String, Widget Function()> routes = {
      'library_devices': () => _buildDeviceListView(provider),
      'device_summary': () => provider.connectedDevice != null
          ? DeviceSummaryView(
              device: provider.connectedDevice!,
              info: provider.connectedDevice!.info!,
              onMirroringTap: () =>
                  setState(() => _selectedId = 'device_screen'),
            )
          : const Center(child: CircularProgressIndicator()),
      'device_apps': () => provider.connectedDevice != null
          ? AppsManagerView(device: provider.connectedDevice!)
          : const SizedBox(),
      'device_files': () => provider.connectedDevice != null
          ? FileBrowserView(device: provider.connectedDevice!)
          : const SizedBox(),
      'device_screen': () => provider.connectedDevice != null
          ? _buildScreenMirroringView(provider.connectedDevice!)
          : const SizedBox(),
    };

    // Fallback if trying to access device route while disconnected
    if (_selectedId.startsWith('device_') && provider.connectedDevice == null) {
      return _buildDeviceListView(provider);
    }

    final builder = routes[_selectedId] ?? routes['library_devices']!;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.02, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(_selectedId), child: builder()),
    );
  }

  // --- Views ---

  Widget _buildDeviceListView(ConnectionProvider provider) {
    return RefreshIndicator(
      onRefresh: _refreshDevices,
      child: Column(
        children: [
          if (provider.availableDevices.isEmpty)
            Expanded(child: _buildEmptyState(context))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: provider.availableDevices.length,
                itemBuilder: (context, index) {
                  final device = provider.availableDevices[index];
                  return DeviceCard(
                    device: device,
                    onConnect: () => _connectToDevice(device),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScreenMirroringView(Device device) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Consumer<MirroringProvider>(
              builder: (context, mirroringProvider, child) {
                final isMirroring =
                    mirroringProvider.status == MirroringStatus.running;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isMirroring) ...[
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.cast_connected,
                                size: 64,
                                color: Colors.green,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                device.platform == MobilePlatform.android
                                    ? 'Mirroring Active\nLook for the SamConnect window'
                                    : 'AirPlay Server Ready\n\n1. Open Control Center on iPhone\n2. Tap "Screen Mirroring"\n3. Select "SamConnect - ${device.name}"\n\n(Ensure same Wi-Fi & Firewall allows Discovery)',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: _stopMirroring,
                                icon: const Icon(Icons.stop),
                                label: const Text('Stop Mirroring'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _buildStatsBar(mirroringProvider),
                      const SizedBox(height: 16),
                    ] else if (mirroringProvider.status ==
                        MirroringStatus.starting)
                      Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 24),
                          Text(
                            'Starting SamConnect...',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Preparing mirroring core',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          const Icon(
                            Icons.screen_share,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Start mirroring to view and control ${device.name}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: () => _startMirroring(device),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Start Mirroring'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () => _showQualityPicker(context),
                                icon: const Icon(Icons.settings),
                                label: const Text('Config'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 32),
                    Divider(
                      indent: 32,
                      endIndent: 32,
                      color: Theme.of(context).dividerColor,
                    ),
                    const SizedBox(height: 16),
                    _buildControlPanel(device),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel(Device device) {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                icon: Icons.power_settings_new,
                label: 'Power',
                onPressed: () =>
                    context.read<DeviceControlProvider>().pressPower(device.id),
                color: Colors.red,
              ),
              const SizedBox(width: 8),
              _buildControlButton(
                icon: Icons.volume_down,
                label: 'Vol -',
                onPressed: () =>
                    context.read<DeviceControlProvider>().volumeDown(device.id),
              ),
              const SizedBox(width: 8),
              _buildControlButton(
                icon: Icons.volume_up,
                label: 'Vol +',
                onPressed: () =>
                    context.read<DeviceControlProvider>().volumeUp(device.id),
              ),
              const SizedBox(width: 8),
              _buildControlButton(
                icon: Icons.camera_alt,
                label: 'Snap',
                onPressed: () {}, // TODO: Screenshot
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                icon: Icons.arrow_back,
                label: 'Back',
                onPressed: () =>
                    context.read<DeviceControlProvider>().pressBack(device.id),
              ),
              const SizedBox(width: 8),
              _buildControlButton(
                icon: Icons.home,
                label: 'Home',
                onPressed: () =>
                    context.read<DeviceControlProvider>().pressHome(device.id),
                isPrimary: true,
              ),
              const SizedBox(width: 8),
              _buildControlButton(
                icon: Icons.menu,
                label: 'Recents',
                onPressed: () => context
                    .read<DeviceControlProvider>()
                    .pressRecents(device.id),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _buildControlButton(
              icon: Icons.lock_open,
              label: 'Unlock Device',
              onPressed: () => _showUnlockDialog(device),
              isPrimary: true,
            ),
          ),
        ],
      ),
    );
  }

  // --- Actions & Helpers ---

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: _buildSettingsContent(),
        ),
      ),
    );
  }

  Widget _buildSettingsContent() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Dark Mode'),
                value: settings.darkMode,
                onChanged: (value) => settings.toggleDarkMode(value),
                secondary: const Icon(Icons.brightness_4),
              ),
              const Divider(),
              const Text(
                'Mirroring Defaults',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ListTile(
                title: const Text('Max FPS'),
                trailing: Text('${settings.maxFps}'),
                subtitle: Slider(
                  value: settings.maxFps.toDouble(),
                  min: 15,
                  max: 120,
                  divisions: 7,
                  onChanged: (v) => settings.setMaxFps(v.toInt()),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Developer info'),
                subtitle: const Text('Meet the creator of SamsConnect'),
                leading: const Icon(Icons.badge_outlined),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => const AboutDeveloperDialog(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
    bool isPrimary = false,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: label,
      child: isPrimary
          ? FilledButton.tonalIcon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: color ?? theme.textTheme.bodyMedium?.color,
                side: BorderSide(
                  color: (color ?? theme.dividerColor).withValues(alpha: 0.5),
                ),
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Icon(icon, size: 18),
            ),
    );
  }

  // --- Dialogs & Actions ---

  Future<void> _startMirroring(Device device) async {
    final mirroringProvider = context.read<MirroringProvider>();

    try {
      await mirroringProvider.startMirroring(device);

      if (mounted && mirroringProvider.status == MirroringStatus.running) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Screen mirroring started for ${device.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted && mirroringProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to start mirroring: ${mirroringProvider.errorMessage}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _stopMirroring() async {
    final mirroringProvider = context.read<MirroringProvider>();
    await mirroringProvider.stopMirroring();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Screen mirroring stopped')));
    }
  }

  void _showQualityPicker(BuildContext context) {
    final mirroringProvider = context.read<MirroringProvider>();
    final currentQuality = mirroringProvider.config.quality;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mirroring Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...MirrorQuality.values.map((quality) {
                return RadioListTile<MirrorQuality>(
                  title: Text(_getQualityName(quality)),
                  subtitle: Text(_getQualityDescription(quality)),
                  value: quality,
                  // ignore: deprecated_member_use
                  groupValue: currentQuality,
                  // ignore: deprecated_member_use
                  onChanged: (value) async {
                    if (value != null) {
                      Navigator.pop(context); // Close dialog first
                      await mirroringProvider.updateQuality(value);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Quality set to ${_getQualityName(value)}',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                );
              }),
              const Divider(),
              SwitchListTile(
                title: const Text('Fullscreen'),
                subtitle: const Text('Start SamConnect in fullscreen mode'),
                value: mirroringProvider.config.fullscreen,
                onChanged: (value) {
                  final newConfig = mirroringProvider.config.copyWith(
                    fullscreen: value,
                  );
                  mirroringProvider.updateConfig(newConfig);
                  (context as Element).markNeedsBuild();
                },
              ),
              SwitchListTile(
                title: const Text('Always on Top'),
                subtitle: const Text('Keep window reachable'),
                value: mirroringProvider.config.alwaysOnTop,
                onChanged: (value) {
                  final newConfig = mirroringProvider.config.copyWith(
                    alwaysOnTop: value,
                  );
                  mirroringProvider.updateConfig(newConfig);
                  (context as Element).markNeedsBuild();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _showUnlockDialog(Device device) async {
    showDialog(
      context: context,
      builder: (_) => PatternUnlockDialog(device: device),
    );
  }

  Future<void> _connectToDevice(Device device) async {
    final provider = context.read<ConnectionProvider>();

    try {
      await provider.connectUsb(device);
      if (mounted) {
        setState(() {
          _selectedId = 'device_summary';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${device.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDroppedFiles(
    BuildContext context,
    DropDoneDetails details,
    Device? device,
  ) async {
    if (device == null || details.files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect a device first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final paths = details.files.map((file) => file.path).toList();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sending ${paths.length} files...'),
          duration: const Duration(seconds: 1),
        ),
      );

      final transferProvider = context.read<FileTransferProvider>();
      await transferProvider.pushFiles(
        device,
        paths,
        device.platform == MobilePlatform.android
            ? '/sdcard/Download'
            : '/Media/Downloads',
      );

      if (context.mounted) {
        if (transferProvider.status == TransferStatus.completed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Files sent successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (transferProvider.status == TransferStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: ${transferProvider.errorMessage}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // --- Views Helpers ---

  Widget _buildStatsBar(MirroringProvider provider) {
    final stats = provider.stats;
    if (provider.status != MirroringStatus.running) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed, size: 14),
            const SizedBox(width: 4),
            Text('${stats.fps.toStringAsFixed(1)} FPS'),
            if (stats.latency != null) ...[
              const SizedBox(width: 12),
              const Icon(Icons.timer, size: 14),
              const SizedBox(width: 4),
              Text('${stats.latency}ms'),
            ],
            const SizedBox(width: 12),
            const Icon(Icons.high_quality, size: 14),
            const SizedBox(width: 4),
            Text(_getQualityName(provider.config.quality)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferOverlay() {
    return Consumer<FileTransferProvider>(
      builder: (context, provider, child) {
        if (provider.status != TransferStatus.transferring) {
          return const SizedBox.shrink();
        }

        return Container(
          color: Colors.black54,
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(32),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text(
                      'Transferring files...',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: provider.progress),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phonelink_off,
            size: 80,
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.5),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                duration: 1000.ms,
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.1, 1.1),
              )
              .fadeIn(),
          const SizedBox(height: 24),
          Text(
            'No devices found',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
          const SizedBox(height: 12),
          Text(
            'Connect your Android device via USB\nor use WiFi pairing',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _refreshDevices,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Device List'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ).animate().fadeIn(delay: 600.ms).scale(),
        ],
      ),
    );
  }

  String _getQualityName(MirrorQuality quality) {
    switch (quality) {
      case MirrorQuality.low:
        return 'Low';
      case MirrorQuality.medium:
        return 'Medium';
      case MirrorQuality.high:
        return 'High';
      case MirrorQuality.original:
        return 'Original';
    }
  }

  String _getQualityDescription(MirrorQuality quality) {
    switch (quality) {
      case MirrorQuality.low:
        return '720p, 2 Mbps - Best for slow connections';
      case MirrorQuality.medium:
        return '1080p, 4 Mbps - Balanced';
      case MirrorQuality.high:
        return 'Native, 8 Mbps - High resolution';
      case MirrorQuality.original:
        return 'Original resolution, 16 Mbps - Highest quality';
    }
  }
}
