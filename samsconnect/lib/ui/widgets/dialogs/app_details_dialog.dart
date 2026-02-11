import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/app_info.dart';
import '../../../providers/connection_provider.dart';
import '../common/premium_card.dart';

class AppDetailsDialog extends StatefulWidget {
  final AppInfo app;

  const AppDetailsDialog({super.key, required this.app});

  @override
  State<AppDetailsDialog> createState() => _AppDetailsDialogState();
}

class _AppDetailsDialogState extends State<AppDetailsDialog> {
  Map<String, dynamic>? _detailedInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final provider = context.read<ConnectionProvider>();
    if (provider.connectedDevice == null) return;

    try {
      final details = await provider.adbService.getAppDetails(
        provider.connectedDevice!.id,
        widget.app.packageName,
      );
      if (mounted) {
        setState(() {
          _detailedInfo = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: PremiumCard(
        glassmorphism: false,
        padding: EdgeInsets.zero,
        child: Container(
          width: 600,
          height: 700,
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
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSection('Basic Information', [
                          _buildInfoRow('Package', widget.app.packageName),
                          _buildInfoRow('Version', widget.app.version),
                          if (_detailedInfo != null &&
                              _detailedInfo!['versionCode'] != null)
                            _buildInfoRow(
                              'Version Code',
                              _detailedInfo!['versionCode'],
                            ),
                          _buildInfoRow('Size', widget.app.size),
                          if (widget.app.installDate != null)
                            _buildInfoRow(
                              'Install Date',
                              _formatDate(widget.app.installDate!),
                            ),
                          if (_detailedInfo != null &&
                              _detailedInfo!['firstInstallTime'] != null)
                            _buildInfoRow(
                              'First Install',
                              _detailedInfo!['firstInstallTime'],
                            ),
                        ]),
                        const SizedBox(height: 16),
                        if (_detailedInfo != null &&
                            (_detailedInfo!['minSdk'] != null ||
                                _detailedInfo!['targetSdk'] != null)) ...[
                          _buildSection('SDK Information', [
                            if (_detailedInfo!['minSdk'] != null)
                              _buildInfoRow(
                                'Minimum SDK',
                                _detailedInfo!['minSdk'],
                              ),
                            if (_detailedInfo!['targetSdk'] != null)
                              _buildInfoRow(
                                'Target SDK',
                                _detailedInfo!['targetSdk'],
                              ),
                          ]),
                          const SizedBox(height: 16),
                        ],
                        if (_detailedInfo != null) ...[
                          if (_detailedInfo!['installer'] != null)
                            _buildSection('Installation', [
                              _buildInfoRow(
                                'Installer',
                                _detailedInfo!['installer'] ?? 'Unknown',
                              ),
                              if (_detailedInfo!['lastUpdateTime'] != null)
                                _buildInfoRow(
                                  'Last Update',
                                  _detailedInfo!['lastUpdateTime'],
                                ),
                            ]),
                          const SizedBox(height: 16),
                          if (_detailedInfo!['apkPath'] != null)
                            _buildSection('Paths', [
                              _buildInfoRow('APK', _detailedInfo!['apkPath']),
                              if (_detailedInfo!['dataDir'] != null)
                                _buildInfoRow(
                                  'Data',
                                  _detailedInfo!['dataDir'],
                                ),
                            ]),
                          const SizedBox(height: 16),
                          if (_detailedInfo!['permissions'] != null &&
                              _detailedInfo!['permissions'].isNotEmpty)
                            _buildSection('Permissions', [
                              ..._detailedInfo!['permissions']
                                  .map<Widget>(
                                    (p) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '• $p',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.color,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ]),
                        ],
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
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: widget.app.iconPath != null
              ? Image.file(
                  File(widget.app.iconPath!),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.android,
                      size: 56,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : Container(
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.android,
                    size: 56,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.app.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Application Details',
                style: Theme.of(context).textTheme.bodySmall,
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
