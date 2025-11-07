import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:painter/painter.dart';
import '../design_system/design_system.dart';

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

    return GradientScaffold(
      appBar: GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.brush_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            const Text('Drawing'),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () {
              PinpointHaptics.light();
              _controller.undo();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              child: GlassContainer(
                padding: const EdgeInsets.all(10),
                borderRadius: 12,
                child: Icon(Icons.undo_rounded, color: cs.primary, size: 20),
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              PinpointHaptics.medium();
              final PictureDetails picture = _controller.finish();
              final image = await picture.toImage();
              final data = await image.toByteData(format: ImageByteFormat.png);
              if (!context.mounted) return;
              if (data != null) {
                PinpointHaptics.success();
                Navigator.of(context).pop(data.buffer.asUint8List());
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              child: GlassContainer(
                padding: const EdgeInsets.all(10),
                borderRadius: 12,
                child: Icon(Icons.save_rounded, color: cs.primary, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: Painter(_controller),
    );
  }
}
