import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:painter/painter.dart';
import 'package:pinpoint/design/app_theme.dart';

class DrawingScreen extends StatefulWidget {
  static const String kRouteName = '/drawing';
  const DrawingScreen({super.key});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final PainterController _controller = PainterController();

  @override
  void initState() {
    super.initState();
    _controller.backgroundColor = Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawing'),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            child: Glass(
              padding: const EdgeInsets.all(8),
              borderRadius: AppTheme.radiusM,
              child: IconButton(
                icon: const Icon(Icons.undo),
                onPressed: () {
                  _controller.undo();
                },
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(8),
            child: Glass(
              padding: const EdgeInsets.all(8),
              borderRadius: AppTheme.radiusM,
              child: IconButton(
                icon: const Icon(Icons.save),
                onPressed: () async {
                  final PictureDetails picture = _controller.finish();
                  final image = await picture.toImage();
                  final data = await image.toByteData(format: ImageByteFormat.png);
                  if (!context.mounted) return;
                  if (data != null) {
                    Navigator.of(context).pop(data.buffer.asUint8List());
                  }
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with gradient background
          Glass(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Drawing',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.primary.withValues(alpha: 0.22),
                        cs.primary.withValues(alpha: 0.0),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Drawing canvas
          Expanded(
            child: Painter(_controller),
          ),
        ],
      ),
    );
  }
}