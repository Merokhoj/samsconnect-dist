import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/connection_provider.dart';
import '../../../data/models/device.dart';
import '../../../data/models/device_info.dart';
import '../common/premium_card.dart';
import '../dialogs/device_info_dialog.dart';
import '../dialogs/pattern_unlock_dialog.dart';

class DeviceSummaryView extends StatefulWidget {
  final Device device;
  final DeviceInfo info;
  final VoidCallback? onMirroringTap;

  const DeviceSummaryView({
    super.key,
    required this.device,
    required this.info,
    this.onMirroringTap,
  });

  @override
  State<DeviceSummaryView> createState() => _DeviceSummaryViewState();
}

class _DeviceSummaryViewState extends State<DeviceSummaryView> {
  Uint8List? _screenshot;
  bool _isLoadingScreenshot = false;

  @override
  void initState() {
    super.initState();
    _fetchScreenshot();
  }

  Future<void> _fetchScreenshot() async {
    if (!mounted) return;
    setState(() => _isLoadingScreenshot = true);

    try {
      final provider = context.read<ConnectionProvider>();
      final service = provider.getService(widget.device.platform);
      final image = await service?.getScreenCapture(widget.device.id);
      if (mounted) {
        setState(() {
          _screenshot = image;
          _isLoadingScreenshot = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingScreenshot = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isNarrow ? 16.0 : 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(child: _buildDeviceImage(context)),
                    const SizedBox(height: 32),
                    _buildInfoColumn(context),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Device Image
                    _buildDeviceImage(context)
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .scale(
                          begin: const Offset(0.9, 0.9),
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(width: 64),
                    // Right: Device Info
                    Expanded(
                      child: _buildInfoColumn(context)
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 200.ms)
                          .slideX(begin: 0.1, curve: Curves.easeOutCubic),
                    ),
                  ],
                ),
              const SizedBox(height: 48),
              // Bottom: Storage Bars
              _buildStorageSection(context)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 400.ms)
                  .slideY(begin: 0.1, curve: Curves.easeOutCubic),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeviceImage(BuildContext context) {
    return GestureDetector(
      onTap: widget.onMirroringTap,
      child: Container(
        width: 260,
        height: 520,
        decoration: BoxDecoration(
          color: const Color(0xFF030712),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(32),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_screenshot != null)
                Image.memory(
                  _screenshot!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white24,
                          size: 48,
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF111827), Color(0xFF030712)],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      widget.device.platform == MobilePlatform.ios
                          ? Icons.apple
                          : Icons.android,
                      size: 80,
                      color: Colors.white10,
                    ),
                  ),
                ),

              if (_isLoadingScreenshot && _screenshot == null)
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),

              // Overlay hint
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app, color: Colors.white, size: 14),
                        SizedBox(width: 8),
                        Text(
                          'Tap to Mirror',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.info.deviceName,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      fontSize:
                          MediaQuery.of(context).size.width < 600 ? 28 : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.info.manufacturer} ${widget.info.model}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _fetchScreenshot,
              tooltip: 'Refresh Screenshot',
            ),
          ],
        ),
        const SizedBox(height: 48),
        _buildInfoGrid(context),
        const SizedBox(height: 40),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) =>
                      DeviceInfoDialog(deviceId: widget.device.id),
                );
              },
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: const Text('Full Details'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(width: 16),
            if (widget.device.platform == MobilePlatform.android)
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) =>
                        PatternUnlockDialog(device: widget.device),
                  );
                },
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text('Unlock Screen'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;

        if (isNarrow) {
          return Column(
            children: [
              _buildInfoItem(
                context,
                Icons.system_update_rounded,
                'OS Version',
                widget.info.osVersion,
              ),
              const SizedBox(height: 16),
              _buildInfoItem(
                context,
                Icons.speed_rounded,
                'CPU',
                widget.info.cpuInfo,
              ),
              const SizedBox(height: 16),
              _buildInfoItem(
                context,
                Icons.memory_rounded,
                'RAM',
                widget.info.ramInfo,
              ),
              const SizedBox(height: 16),
              _buildInfoItem(
                context,
                Icons.screenshot_monitor_rounded,
                'Display',
                widget.info.displayResolution,
              ),
              const SizedBox(height: 16),
              _buildInfoItem(
                context,
                Icons.battery_charging_full_rounded,
                'Battery',
                '${widget.info.batteryLevel}% ${widget.info.isCharging ? "(Charging)" : ""}',
              ),
              const SizedBox(height: 16),
              _buildInfoItem(
                context,
                Icons.fingerprint_rounded,
                'Serial',
                widget.info.serialNumber,
              ),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    context,
                    Icons.system_update_rounded,
                    'OS Version',
                    widget.info.osVersion,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildInfoItem(
                    context,
                    Icons.speed_rounded,
                    'CPU',
                    widget.info.cpuInfo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    context,
                    Icons.memory_rounded,
                    'RAM',
                    widget.info.ramInfo,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildInfoItem(
                    context,
                    Icons.screenshot_monitor_rounded,
                    'Display',
                    widget.info.displayResolution,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    context,
                    Icons.battery_charging_full_rounded,
                    'Battery',
                    '${widget.info.batteryLevel}% ${widget.info.isCharging ? "(Charging)" : ""}',
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildInfoItem(
                    context,
                    Icons.fingerprint_rounded,
                    'Serial',
                    widget.info.serialNumber,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStorageSection(BuildContext context) {
    // Parse helper
    double parseBytes(String s) {
      final input = s.trim().toUpperCase();
      final clean = input.replaceAll(RegExp(r'[^0-9.]'), '');
      final value = double.tryParse(clean) ?? 0;

      if (input.contains('MB') || input.endsWith('M')) {
        return value / 1024.0;
      } else if (input.contains('KB') || input.endsWith('K')) {
        return value / (1024.0 * 1024.0);
      } else if (input.contains('TB') || input.endsWith('T')) {
        return value * 1024.0;
      }
      // Default assumes GB or simply passes through if no unit or already GB
      return value;
    }

    final totalGB = parseBytes(widget.info.totalStorage);
    final availableGB = parseBytes(widget.info.availableStorage);
    final usedGB = totalGB > 0 ? (totalGB - availableGB) : 0.0;

    // Safety check
    final safeTotal = totalGB > 0 ? totalGB : 64.0; // Fallback
    final safeUsed = usedGB > 0 ? usedGB : 0.0;

    // For iOS/Android where we don't have categories, split used space into mock categories
    // For now, let's use the actual used percentage but keep the multi-color look
    final usedPercent = (safeUsed / safeTotal * 100).clamp(0.0, 100.0);
    final freePercent = (100.0 - usedPercent).clamp(0.0, 100.0);

    // Distribution of used space (Mocks)
    final systemFlex = (usedPercent * 0.3).toInt();
    final appsFlex = (usedPercent * 0.4).toInt();
    final mediaFlex = (usedPercent * 0.3).toInt();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Storage',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${safeUsed.toStringAsFixed(1)} GB used of ${safeTotal.toStringAsFixed(1)} GB',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Multi-colored progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 20,
              child: Row(
                children: [
                  if (systemFlex > 0)
                    Expanded(
                      flex: systemFlex,
                      child: Container(color: Colors.redAccent),
                    ),
                  if (appsFlex > 0)
                    Expanded(
                      flex: appsFlex,
                      child: Container(color: Colors.orangeAccent),
                    ),
                  if (mediaFlex > 0)
                    Expanded(
                      flex: mediaFlex,
                      child: Container(color: Colors.blueAccent),
                    ),
                  if (freePercent > 0)
                    Expanded(
                      flex: freePercent.toInt(),
                      child: Container(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegend('System', Colors.redAccent),
              _buildLegend('Apps', Colors.orangeAccent),
              _buildLegend('Media', Colors.blueAccent),
              _buildLegend('Free', Theme.of(context).dividerColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
