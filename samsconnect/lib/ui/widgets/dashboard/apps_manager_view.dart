import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../data/models/app_info.dart';
import '../../../data/models/device.dart';
import '../../../providers/connection_provider.dart';
import '../common/premium_card.dart';
import '../dialogs/app_details_dialog.dart';

class AppsManagerView extends StatefulWidget {
  final Device device;

  const AppsManagerView({super.key, required this.device});

  @override
  State<AppsManagerView> createState() => _AppsManagerViewState();
}

enum AppSortType { nameAsc, nameDesc, packageAsc, sizeDesc, dateDesc }

class _AppsManagerViewState extends State<AppsManagerView> {
  List<AppInfo>? _allApps;
  List<AppInfo>? _filteredApps;
  bool _isLoading = true;
  AppSortType _sortType = AppSortType.nameAsc;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchController.addListener(_filterAndSortApps);
  }

  void _filterAndSortApps() {
    if (_allApps == null) return;
    final query = _searchController.text.toLowerCase();

    List<AppInfo> filtered = _allApps!.where((app) {
      return app.name.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);
    }).toList();

    // Apply Sorting
    switch (_sortType) {
      case AppSortType.nameAsc:
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case AppSortType.nameDesc:
        filtered.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
      case AppSortType.packageAsc:
        filtered.sort((a, b) => a.packageName.compareTo(b.packageName));
        break;
      case AppSortType.sizeDesc:
        filtered.sort((a, b) => _compareSizes(b.size, a.size));
        break;
      case AppSortType.dateDesc:
        filtered.sort(
          (a, b) => (b.installDate ?? DateTime(0)).compareTo(
            a.installDate ?? DateTime(0),
          ),
        );
        break;
    }

    setState(() {
      _filteredApps = filtered;
    });
  }

  int _compareSizes(String sizeA, String sizeB) {
    // Basic human readable size comparison (rough estimate)
    double parseSize(String s) {
      final parts = s.split(' ');
      if (parts.length < 2) return 0;
      double val = double.tryParse(parts[0]) ?? 0;
      final unit = parts[1].toUpperCase();
      if (unit.contains('G')) return val * 1024 * 1024;
      if (unit.contains('M')) return val * 1024;
      if (unit.contains('K')) return val;
      return val / 1024;
    }

    return parseSize(sizeA).compareTo(parseSize(sizeB));
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ConnectionProvider>();
      final apps = await provider.getInstalledApps(widget.device.id);

      if (mounted) {
        setState(() {
          _allApps = apps;
          _isLoading = false;
        });
        _filterAndSortApps();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _installApp() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );

    if (result == null || result.files.single.path == null) return;

    final apkPath = result.files.single.path!;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Installing APK... please wait')),
      );

      final provider = context.read<ConnectionProvider>();
      final success = await provider.installApp(widget.device.id, apkPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'App installed successfully' : 'Failed to install app',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) _loadApps();
      }
    }
  }

  Future<void> _backupApp(AppInfo app) async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backing up ${app.name}...')));

      final provider = context.read<ConnectionProvider>();
      final savedPath = await provider.pullApp(
        widget.device.id,
        app.packageName,
        dir,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedPath != null
                  ? 'Backup saved to $savedPath'
                  : 'Failed to backup app',
            ),
            backgroundColor: savedPath != null ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uninstallApp(AppInfo app) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Uninstall ${app.name}?'),
        content: Text('Are you sure you want to uninstall ${app.packageName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final provider = context.read<ConnectionProvider>();
      final success = await provider.uninstallApp(
        widget.device.id,
        app.packageName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Uninstalled ${app.name}'
                  : 'Failed to uninstall ${app.name}',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) {
          _loadApps();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allApps == null || _allApps!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.apps_outage, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No user apps found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadApps,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _installApp,
                  icon: const Icon(Icons.add),
                  label: const Text('Install APK'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with Search and Actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;

              if (isNarrow) {
                return Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search apps...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        PopupMenuButton<AppSortType>(
                          icon: const Icon(Icons.sort),
                          tooltip: 'Sort apps',
                          onSelected: (type) {
                            setState(() {
                              _sortType = type;
                              _filterAndSortApps();
                            });
                          },
                          itemBuilder: (context) => [
                            _sortItem(
                              AppSortType.nameAsc,
                              'Name (A-Z)',
                              Icons.sort_by_alpha,
                            ),
                            _sortItem(
                              AppSortType.nameDesc,
                              'Name (Z-A)',
                              Icons.sort_by_alpha,
                            ),
                            _sortItem(
                              AppSortType.packageAsc,
                              'Package Name',
                              Icons.link,
                            ),
                            _sortItem(
                              AppSortType.sizeDesc,
                              'Size (Largest First)',
                              Icons.storage,
                            ),
                            _sortItem(
                              AppSortType.dateDesc,
                              'Install Date (Newest)',
                              Icons.calendar_today,
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: _loadApps,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh',
                        ),
                        const Spacer(),
                        Tooltip(
                          message: 'Install APK file from computer',
                          child: FilledButton.icon(
                            onPressed: _installApp,
                            icon: const Icon(Icons.add),
                            label: const Text('Install'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search apps...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<AppSortType>(
                    icon: const Icon(Icons.sort),
                    tooltip: 'Sort apps',
                    onSelected: (type) {
                      setState(() {
                        _sortType = type;
                        _filterAndSortApps();
                      });
                    },
                    itemBuilder: (context) => [
                      _sortItem(
                        AppSortType.nameAsc,
                        'Name (A-Z)',
                        Icons.sort_by_alpha,
                      ),
                      _sortItem(
                        AppSortType.nameDesc,
                        'Name (Z-A)',
                        Icons.sort_by_alpha,
                      ),
                      _sortItem(
                        AppSortType.packageAsc,
                        'Package Name',
                        Icons.link,
                      ),
                      _sortItem(
                        AppSortType.sizeDesc,
                        'Size (Largest First)',
                        Icons.storage,
                      ),
                      _sortItem(
                        AppSortType.dateDesc,
                        'Install Date (Newest)',
                        Icons.calendar_today,
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _loadApps,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                  Tooltip(
                    message: 'Install APK file from computer',
                    child: FilledButton.icon(
                      onPressed: _installApp,
                      icon: const Icon(Icons.add),
                      label: const Text('Install'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // App List
        Expanded(
          child: _filteredApps == null || _filteredApps!.isEmpty
              ? Center(child: Text('No apps match "${_searchController.text}"'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredApps!.length,
                  itemBuilder: (context, index) {
                    final app = _filteredApps![index];
                    return PremiumCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        leading: SizedBox(
                          width: 60,
                          height: 60,
                          child: app.iconPath != null
                              ? Image.file(
                                  File(app.iconPath!),
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildFallbackIcon(app.name);
                                  },
                                )
                              : _buildFallbackIcon(app.name),
                        ),
                        title: Text(
                          app.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    app.packageName,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color
                                          ?.withValues(alpha: 0.7),
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (app.size.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      app.size,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Remaining info badges
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (app.version.isNotEmpty)
                                  _buildInfoBadge(
                                    context,
                                    'v${app.version}',
                                    Icons.code,
                                  ),
                                if (app.installDate != null)
                                  _buildInfoBadge(
                                    context,
                                    _formatDate(app.installDate!),
                                    Icons.calendar_today,
                                  ),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'info') {
                              showDialog(
                                context: context,
                                builder: (context) =>
                                    AppDetailsDialog(app: app),
                              );
                            }
                            if (value == 'backup') _backupApp(app);
                            if (value == 'uninstall') _uninstallApp(app);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'info',
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 20),
                                  SizedBox(width: 8),
                                  Text('View Details'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'backup',
                              child: Row(
                                children: [
                                  Icon(Icons.download, size: 20),
                                  SizedBox(width: 8),
                                  Text('Backup APK'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'uninstall',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Uninstall',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInfoBadge(BuildContext context, String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  PopupMenuItem<AppSortType> _sortItem(
    AppSortType type,
    String label,
    IconData icon,
  ) {
    return PopupMenuItem(
      value: type,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: _sortType == type
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: _sortType == type ? FontWeight.bold : null,
              color: _sortType == type
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackIcon(String name) {
    return Container(
      alignment: Alignment.center,
      child: Icon(
        Icons.android,
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        size: 35,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
