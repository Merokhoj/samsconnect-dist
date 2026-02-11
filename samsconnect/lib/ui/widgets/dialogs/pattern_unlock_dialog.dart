import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/device.dart';
import '../../../providers/connection_provider.dart';

class PatternUnlockDialog extends StatefulWidget {
  final Device device;

  const PatternUnlockDialog({super.key, required this.device});

  @override
  State<PatternUnlockDialog> createState() => _PatternUnlockDialogState();
}

class _PatternUnlockDialogState extends State<PatternUnlockDialog> {
  final List<int> _selectedNodes = [];
  Offset? _currentDragPos;
  final int _gridSize = 3;

  // Pattern Unlock Logic
  // We assume the pattern area is in the bottom half of the screen.
  // Standard Android pattern is usually centered horizontally.
  // We will map the 3x3 grid to the device coordinates.

  void _onPanStart(DragStartDetails details, Size size) {
    _handleTouch(details.localPosition, size);
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    setState(() {
      _currentDragPos = details.localPosition;
    });
    _handleTouch(details.localPosition, size);
  }

  void _onPanEnd(DragEndDetails details, Size size) {
    setState(() {
      _currentDragPos = null;
    });
    _attemptUnlock(size);
  }

  void _handleTouch(Offset localPos, Size size) {
    final nodeIndex = _getNodeAt(localPos, size);
    if (nodeIndex != -1) {
      if (!_selectedNodes.contains(nodeIndex)) {
        setState(() {
          _selectedNodes.add(nodeIndex);
        });

        // Haptic feedback could be added here
      }
    }
  }

  int _getNodeAt(Offset pos, Size size) {
    // Grid dimensions
    final cellWidth = size.width / _gridSize;
    final cellHeight = size.height / _gridSize;

    final col = (pos.dx / cellWidth).floor();
    final row = (pos.dy / cellHeight).floor();

    if (col >= 0 && col < _gridSize && row >= 0 && row < _gridSize) {
      // Check if within a radius of the center of the cell
      final center = Offset((col + 0.5) * cellWidth, (row + 0.5) * cellHeight);

      if ((pos - center).distance < cellWidth * 0.4) {
        return row * _gridSize + col;
      }
    }
    return -1;
  }

  Future<void> _attemptUnlock(Size size) async {
    if (_selectedNodes.length < 2) {
      setState(() {
        _selectedNodes.clear();
      });
      return;
    }

    final points = _mapNodesToDeviceCoordinates();

    Navigator.pop(context); // Close dialog

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attempting to unlock...')),
        );
      }

      await context.read<ConnectionProvider>().swipe(widget.device.id, points);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Point<int>> _mapNodesToDeviceCoordinates() {
    // Heuristic for pattern area on device
    // Use device resolution if available, otherwise assume 1080x1920 (most common aspect ratio) scale

    int devWidth = 1080;
    int devHeight = 1920;

    try {
      final res = widget.device.info?.displayResolution ?? '1080x1920';
      if (res.contains('Physical size:')) {
        // Example: Physical size: 1080x2400
        final parts = res.split(':').last.trim().split('x');
        devWidth = int.parse(parts[0]);
        devHeight = int.parse(parts[1]);
      } else {
        // Generic "1080x2400"
        final parts = res.trim().split('x');
        if (parts.length == 2) {
          devWidth = int.parse(parts[0]);
          devHeight = int.parse(parts[1]);
        }
      }
    } catch (_) {}

    // Pattern area assumptions for modern tall screens (e.g., 1080x2280, 1440x3040)
    // Width: 75% of screen width (more precise for most phones)
    // Height: same as width (square)
    // Center X: devWidth / 2
    // Center Y: Lowered to ~67% of height for modern taller devices

    final patternWidth = devWidth * 0.75;
    final patternHeight = patternWidth;

    final startX = (devWidth - patternWidth) / 2;
    final startY = (devHeight * 0.72) - (patternHeight / 2);

    final cellW = patternWidth / (_gridSize - 1);
    final cellH = patternHeight / (_gridSize - 1);

    return _selectedNodes.map((node) {
      final row = node ~/ _gridSize;
      final col = node % _gridSize;

      final x = startX + col * cellW;
      final y = startY + row * cellH;

      return Point(x.toInt(), y.toInt());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Draw Pattern'),
      content: SizedBox(
        width: 300,
        height: 300,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onPanStart: (d) => _onPanStart(d, constraints.biggest),
              onPanUpdate: (d) => _onPanUpdate(d, constraints.biggest),
              onPanEnd: (d) => _onPanEnd(d, constraints.biggest),
              child: CustomPaint(
                size: constraints.biggest,
                painter: PatternPainter(
                  selectedNodes: _selectedNodes,
                  currentDragPos: _currentDragPos,
                  gridSize: _gridSize,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class PatternPainter extends CustomPainter {
  final List<int> selectedNodes;
  final Offset? currentDragPos;
  final int gridSize;
  final Color color;

  PatternPainter({
    required this.selectedNodes,
    required this.currentDragPos,
    required this.gridSize,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final selectedDotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw Dots
    for (int i = 0; i < gridSize * gridSize; i++) {
      final row = i ~/ gridSize;
      final col = i % gridSize;
      final center = Offset((col + 0.5) * cellWidth, (row + 0.5) * cellHeight);

      canvas.drawCircle(
        center,
        8.0,
        selectedNodes.contains(i) ? selectedDotPaint : dotPaint,
      );
    }

    // Draw Lines
    if (selectedNodes.isNotEmpty) {
      final path = Path();
      final startNode = selectedNodes.first;
      path.moveTo(
        ((startNode % gridSize) + 0.5) * cellWidth,
        ((startNode ~/ gridSize) + 0.5) * cellHeight,
      );

      for (int i = 1; i < selectedNodes.length; i++) {
        final node = selectedNodes[i];
        path.lineTo(
          ((node % gridSize) + 0.5) * cellWidth,
          ((node ~/ gridSize) + 0.5) * cellHeight,
        );
      }

      if (currentDragPos != null) {
        path.lineTo(currentDragPos!.dx, currentDragPos!.dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PatternPainter oldDelegate) {
    return oldDelegate.selectedNodes != selectedNodes ||
        oldDelegate.currentDragPos != currentDragPos;
  }
}
