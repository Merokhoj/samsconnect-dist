import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/connection_provider.dart';
import '../../providers/network_provider.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  int _selectedTab = 0;
  final _ipController = TextEditingController();
  final _pairIpController = TextEditingController();
  final _pairCodeController = TextEditingController();

  @override
  void dispose() {
    _ipController.dispose();
    _pairIpController.dispose();
    _pairCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect Device')),
      body: Column(
        children: [
          // Tab selector
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.usb),
                    label: Text('USB'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.wifi),
                    label: Text('WiFi'),
                  ),
                  ButtonSegment(
                    value: 3,
                    icon: Icon(Icons.pin),
                    label: Text('Pair Code'),
                  ),
                  ButtonSegment(
                    value: 2,
                    icon: Icon(Icons.qr_code),
                    label: Text('QR Code'),
                  ),
                ],
                selected: {_selectedTab},
                onSelectionChanged: (Set<int> newSelection) {
                  setState(() {
                    _selectedTab = newSelection.first;
                  });
                },
              ),
            ),
          ),

          const Divider(),

          // Tab content
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildUsbTab();
      case 1:
        return _buildWifiTab();
      case 2:
        return _buildQrTab();
      case 3:
        return _buildPairTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildUsbTab() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.usb, size: 80, color: Colors.blue),
            SizedBox(height: 24),
            Text(
              'USB Connection',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Steps:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              '1. Enable USB Debugging on your Android device\n'
              '2. Connect your device via USB cable\n'
              '3. Allow USB debugging when prompted\n'
              '4. Device will appear in the main screen',
              textAlign: TextAlign.left,
            ),
            SizedBox(height: 24),
            Text(
              'Go back to the main screen and click Refresh',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWifiTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.wifi, size: 80, color: Colors.blue),
          const SizedBox(height: 24),
          const Text(
            'WiFi Connection',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          const Text(
            'Enter Device IP Address & Port:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(
              hintText: '192.168.1.100:5555',
              helperText: 'e.g. 192.168.1.100:34567',
              prefixIcon: Icon(Icons.router),
            ),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _connectWifi(),
            icon: const Icon(Icons.link),
            label: const Text('Connect'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 32),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Guide:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Open Wireless Debugging in Developer Options\n'
                    '• Note the IP & Port under "IP address & Port"\n'
                    '• Ensure both devices are on the same network',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.pin, size: 80, color: Colors.blue),
          const SizedBox(height: 24),
          const Text(
            'Pairing Code',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          const Text(
            'Enter Pairing IP & Port:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pairIpController,
            decoration: const InputDecoration(
              hintText: '192.168.1.100:12345',
              prefixIcon: Icon(Icons.router),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Enter 6-digit Pairing Code:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pairCodeController,
            decoration: const InputDecoration(
              hintText: '123456',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _pairDevice(),
            icon: const Icon(Icons.vpn_key),
            label: const Text('Pair & Connect'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 32),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Go to Wireless Debugging Settings\n'
                    '2. Tap "Pair device with pairing code"\n'
                    '3. Enter the IP, Port, and Code shown on device',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrTab() {
    return Consumer<NetworkProvider>(
      builder: (context, provider, child) {
        final ip = provider.localIp;
        // Standard ADB Wireless Debugging QR Format
        // WIFI:S:<name>;T:ADB;P:<code>;;
        // Note: Real system QR pairing requires mDNS/DNS-SD publishing
        const pairingData = 'WIFI:S:SamConnect;T:ADB;P:123456;;';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (ip != null) ...[
                const Text(
                  'QR Code Pairing',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                QrImageView(
                  data: pairingData,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Scan with Android Device',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Open "Wireless Debugging" > "Pair device with QR code" and scan this.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                const Icon(Icons.wifi_off, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No Network Detected'),
                const Text('Please connect to WiFi to use QR pairing'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => provider.refreshNetworkInfo(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Other Info:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'Scanning requires mDNS setup. If it fails, use the "Pair Code" tab for more reliable pairing.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _connectWifi() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      _showSnackBar('Please enter an IP address & Port');
      return;
    }

    final provider = context.read<ConnectionProvider>();
    try {
      await provider.connectWifi(ip);
      if (mounted) {
        _showSnackBar('Connecting...');
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showSnackBar('Failed to connect: $e', isError: true);
    }
  }

  Future<void> _pairDevice() async {
    final ipPort = _pairIpController.text.trim();
    final code = _pairCodeController.text.trim();

    if (ipPort.isEmpty || code.isEmpty) {
      _showSnackBar('Please enter both IP:Port and Pairing Code');
      return;
    }

    if (code.length != 6) {
      _showSnackBar('Pairing code must be 6 digits');
      return;
    }

    final provider = context.read<ConnectionProvider>();
    try {
      _showSnackBar('Pairing with $ipPort...');
      await provider.pairAndConnect(ipPort, code);
      if (mounted) {
        _showSnackBar(provider.errorMessage ?? 'Pairing attempt completed');
      }
    } catch (e) {
      _showSnackBar('Pairing failed: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }
}
