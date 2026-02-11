import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../providers/file_transfer_provider.dart';
import '../../data/models/device.dart';

class FileBrowserScreen extends StatefulWidget {
  final Device device;

  const FileBrowserScreen({super.key, required this.device});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Browser'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final provider = context.read<FileTransferProvider>();
              provider.loadDirectory(widget.device, provider.currentPath);
            },
          ),
        ],
      ),
      body: Consumer<FileTransferProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // Breadcrumbs / Current Path
              Container(
                padding: const EdgeInsets.all(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: _goBack,
                      tooltip: 'Go to parent directory',
                    ),
                    Expanded(
                      child: Text(
                        provider.currentPath,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              if (provider.isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (provider.errorMessage != null)
                Expanded(child: Center(child: Text(provider.errorMessage!)))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.contents.length,
                    itemBuilder: (context, index) {
                      final item = provider.contents[index];
                      final isDir = item.endsWith('/');
                      final name = isDir
                          ? item.substring(0, item.length - 1)
                          : item;

                      return ListTile(
                        leading: Icon(
                          isDir ? Icons.folder : Icons.insert_drive_file,
                          color: isDir ? Colors.amber : Colors.blue,
                        ),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadHere,
        child: const Icon(Icons.upload),
      ),
    );
  }

  Future<void> _downloadFile(String fileName) async {
    final provider = context.read<FileTransferProvider>();
    final remotePath = p.join(provider.currentPath, fileName);

    // Let user choose where to save
    final result = await FilePicker.platform.getDirectoryPath();
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
}
