import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:painter/painter.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: () {
              _controller.undo();
            },
          ),
          IconButton(
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
        ],
      ),
      body: Painter(_controller),
    );
  }
}
