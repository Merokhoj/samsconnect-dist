import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../../providers/file_transfer_provider.dart';
import '../../../data/models/device.dart';

class FileBrowserView extends StatefulWidget {
  final Device device;

  const FileBrowserView({super.key, required this.device});

  @override
  State<FileBrowserView> createState() => _FileBrowserViewState();
}

class _FileBrowserViewState extends State<FileBrowserView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FileTransferProvider>().loadDirectory(
        widget.device,
        widget.device.platform == MobilePlatform.android ? '/sdcard' : '/Media',
      );
    });
  }

  void _onItemTap(String item) {
    final provider = context.read<FileTransferProvider>();
    if (item.endsWith('/')) {
      final newPath = p.join(
        provider.currentPath,
        item.substring(0, item.length - 1),
      );
      provider.loadDirectory(widget.device, newPath);
    } else {
      // It's a file, open on PC
      final fullPath = p.join(provider.currentPath, item);
      provider.openRemoteFile(widget.device, fullPath);
    }
  }

  void _goBack() {
    final provider = context.read<FileTransferProvider>();
    if (provider.currentPath == '/' || provider.currentPath == '/sdcard') {
      return;
    }

    final parent = p.dirname(provider.currentPath);
    provider.loadDirectory(widget.device, parent);
  }

  Future<void> _downloadFile(String fileName) async {
    final provider = context.read<FileTransferProvider>();
    final remotePath = p.join(provider.currentPath, fileName);

    // Let user choose where to save
    final String? result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;

    final localPath = p.join(result, fileName);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Downloading $fileName...')));

      await provider.pullFile(widget.device, remotePath, localPath);

      if (mounted) {
        if (provider.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${provider.errorMessage}'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download complete'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _uploadHere() async {
    final provider = context.read<FileTransferProvider>();

    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    final paths = result.paths.whereType<String>().toList();
    if (paths.isEmpty) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploading ${paths.length} file(s)...')),
      );

      await provider.pushFiles(widget.device, paths, provider.currentPath);

      if (mounted) {
        if (provider.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${provider.errorMessage}'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload complete'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Widget _getFileIcon(String item, {double size = 24}) {
    final isDir = item.endsWith('/');
    if (isDir) return Icon(Icons.folder, size: size, color: Colors.amber);

    final ext = p.extension(item).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.webp':
      case '.bmp':
        return Icon(Icons.image, size: size, color: Colors.pinkAccent);
      case '.mp4':
      case '.mkv':
      case '.mov':
      case '.avi':
      case '.webm':
        return Icon(Icons.movie, size: size, color: Colors.indigoAccent);
      case '.mp3':
      case '.wav':
      case '.ogg':
      case '.m4a':
      case '.flac':
        return Icon(Icons.audiotrack, size: size, color: Colors.tealAccent);
      case '.pdf':
        return Icon(Icons.picture_as_pdf, size: size, color: Colors.redAccent);
      case '.txt':
      case '.log':
      case '.md':
      case '.json':
      case '.xml':
        return Icon(Icons.description, size: size, color: Colors.blueAccent);
      case '.apk':
        return Icon(Icons.android, size: size, color: Colors.green);
      case '.zip':
      case '.rar':
      case '.7z':
      case '.tar':
      case '.gz':
        return Icon(Icons.folder_zip, size: size, color: Colors.orangeAccent);
      default:
        return Icon(Icons.insert_drive_file, size: size, color: Colors.blue);
    }
  }

  bool _isGridView = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<FileTransferProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: _goBack,
                    tooltip: 'Go to parent directory',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      provider.loadDirectory(
                        widget.device,
                        provider.currentPath,
                      );
                    },
                    tooltip: 'Refresh',
                  ),
                  const SizedBox(width: 8),
                  // View Toggle
                  IconButton(
                    icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                    onPressed: () {
                      setState(() {
                        _isGridView = !_isGridView;
                      });
                    },
                    tooltip: _isGridView
                        ? 'Switch to List View'
                        : 'Switch to Grid View',
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _uploadHere,
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload'),
                  ),
                ],
              ),
            ),

            // Breadcrumbs / Current Path
            Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              width: double.infinity,
              child: Text(
                provider.currentPath,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            if (provider.isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (provider.errorMessage != null)
              Expanded(child: Center(child: Text(provider.errorMessage!)))
            else
              Expanded(
                child: _isGridView
                    ? GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 120,
                              childAspectRatio: 0.8,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: provider.contents.length,
                        itemBuilder: (context, index) {
                          final item = provider.contents[index];
                          final isDir = item.endsWith('/');
                          final name = isDir
                              ? item.substring(0, item.length - 1)
                              : item;

                          return InkWell(
                            onTap: () => _onItemTap(item),
                            borderRadius: BorderRadius.circular(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _getFileIcon(item, size: 48),
                                const SizedBox(height: 8),
                                Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : ListView.builder(
                        itemCount: provider.contents.length,
                        itemBuilder: (context, index) {
                          final item = provider.contents[index];
                          final isDir = item.endsWith('/');
                          final name = isDir
                              ? item.substring(0, item.length - 1)
                              : item;

                          return ListTile(
                            leading: _getFileIcon(item, size: 28),
                            title: Text(name),
                            onTap: () => _onItemTap(item),
                            trailing: !isDir
                                ? IconButton(
                                    icon: const Icon(Icons.download),
                                    onPressed: () => _downloadFile(item),
                                  )
                                : null,
                          );
                        },
                      ),
              ),

            if (provider.status == TransferStatus.transferring)
              LinearProgressIndicator(value: provider.progress),
          ],
        );
      },
    );
  }
}
