import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/connection_provider.dart';
import '../common/premium_card.dart';

class DeviceInfoDialog extends StatefulWidget {
  final String deviceId;

  const DeviceInfoDialog({super.key, required this.deviceId});

  @override
  State<DeviceInfoDialog> createState() => _DeviceInfoDialogState();
}

class _DeviceInfoDialogState extends State<DeviceInfoDialog> {
  Map<String, String>? _properties;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProperties();
  }

  Future<void> _fetchProperties() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ConnectionProvider>();
      final device = provider.availableDevices.firstWhere(
        (d) => d.id == widget.deviceId,
      );
      final service = provider.getService(device.platform);
      final props = await service?.getFullSystemProperties(widget.deviceId);

      if (mounted) {
        setState(() {
          _properties = props;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _get(String key, [String defaultValue = 'Unknown']) {
    return _properties?[key] ?? defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: PremiumCard(
        padding: EdgeInsets.zero,
        glassmorphism: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 650,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const Divider(height: 32),
                if (_isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_properties == null || _properties!.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          const Text('Failed to fetch device details'),
                          TextButton(
                            onPressed: _fetchProperties,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSection('Device Information', [
                            _buildInfoRow(
                              'Manufacturer',
                              _get(
                                'manufacturer',
                                _get('ro.product.manufacturer'),
                              ),
                            ),
                            _buildInfoRow(
                              'Model',
                              _get('model', _get('ro.product.model')),
                            ),
                            _buildInfoRow(
                              'Brand',
                              _get('brand', _get('ro.product.brand')),
                            ),
                            _buildInfoRow(
                              'Device',
                              _get('deviceName', _get('ro.product.device')),
                            ),
                          ]),
                          const SizedBox(height: 20),
                          _buildSection('Software', [
                            _buildInfoRow(
                              'OS Version',
                              _get(
                                'osVersion',
                                _get('ro.build.version.release'),
                              ),
                            ),
                            if (_properties?.containsKey('sdkVersion') ?? false)
                              _buildInfoRow(
                                'SDK/API Level',
                                _get(
                                  'sdkVersion',
                                  _get('ro.build.version.sdk'),
                                ),
                              ),
                            if (_properties?.containsKey('BuildVersion') ??
                                false)
                              _buildInfoRow(
                                'Build Version',
                                _get('BuildVersion'),
                              ),
                            if (_properties?.containsKey('ro.build.id') ??
                                false)
                              _buildInfoRow('Build ID', _get('ro.build.id')),
                          ]),
                          const SizedBox(height: 20),
                          _buildSection('Hardware', [
                            _buildInfoRow(
                              'CPU',
                              _get(
                                'cpuInfo',
                                _get('CPUArchitecture', 'Unknown'),
                              ),
                            ),
                            _buildInfoRow('RAM', _get('ramInfo')),
                            if (_properties?.containsKey('displayResolution') ??
                                false)
                              _buildInfoRow(
                                'Display Resolution',
                                _get('displayResolution'),
                              ),
                            if (_properties?.containsKey('HardwareModel') ??
                                false)
                              _buildInfoRow(
                                'Hardware Model',
                                _get('HardwareModel'),
                              ),
                          ]),
                          const SizedBox(height: 20),
                          if (_properties?.containsKey('UniqueDeviceID') ??
                              false)
                            _buildSection('Identifiers', [
                              _buildInfoRow('UDID', _get('UniqueDeviceID')),
                              _buildInfoRow(
                                'Serial Number',
                                _get('SerialNumber'),
                              ),
                              _buildInfoRow(
                                'WiFi Address',
                                _get('WiFiAddress'),
                              ),
                              _buildInfoRow(
                                'IMEI',
                                _get('InternationalMobileEquipmentIdentity'),
                              ),
                            ])
                          else
                            _buildSection('Network & ID', [
                              _buildInfoRow(
                                'Serial Number',
                                _get('ro.serialno'),
                              ),
                              _buildInfoRow(
                                'WiFi MAC',
                                _get('ro.boot.wifimacaddr'),
                              ),
                              _buildInfoRow(
                                'Baseband',
                                _get('gsm.version.baseband'),
                              ),
                            ]),
                        ],
                      ),
                    ),
                  ),
                const Divider(height: 32),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.secondaryContainer,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            (_properties?.containsKey('UniqueDeviceID') ?? false)
                ? Icons.apple
                : Icons.phone_android,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'About Device',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                (_properties?.containsKey('brand') ?? false)
                    ? '${_get('brand')} ${_get('model')}'
                    : '${_get('ro.product.brand')} ${_get('ro.product.model')}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied: $label'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          label: const Text('Close'),
        ),
      ],
    );
  }
}
