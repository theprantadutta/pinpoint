import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:painter/painter.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../design_system/design_system.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';

class DrawingScreen extends StatefulWidget {
  static const String kRouteName = '/drawing';
  const DrawingScreen({super.key});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final PainterController _controller = PainterController();
  bool _configured = false;

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'Drawing');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configured) return;
    _configured = true;
    // The saved PNG is paper with pen-blue strokes in either theme, so the
    // drawing reads the same wherever it is shown later.
    _controller
      ..backgroundColor = SketchColors.light.surface
      ..drawColor = SketchColors.light.pen
      ..thickness = 3;
  }

  Future<void> _save() async {
    PinpointHaptics.medium();
    final PictureDetails picture = _controller.finish();
    final image = await picture.toImage();
    final data = await image.toByteData(format: ImageByteFormat.png);
    if (!mounted) return;
    if (data != null) {
      getIt<AnalyticsFacade>().trackDrawingSaved();
      PinpointHaptics.success();
      Navigator.of(context).pop(data.buffer.asUint8List());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;

    return SketchScaffold(
      title: l10n.fabDrawing,
      doodleTop: 0,
      actions: [
        CircleIconButton(
          icon: Icons.undo_rounded,
          semanticLabel: l10n.dgUndo,
          onPressed: () {
            PinpointHaptics.light();
            _controller.undo();
          },
        ),
        const SizedBox(width: 6),
        CircleIconButton(
          icon: Icons.check_rounded,
          fill: s.inverse,
          semanticLabel: l10n.commonSave,
          onPressed: _save,
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
            SketchSpace.screenX, 16, SketchSpace.screenX, 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SketchRadius.card),
            border: Border.all(color: s.outline, width: SketchStroke.outline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
                SketchRadius.card - SketchStroke.outline),
            child: Painter(_controller),
          ),
        ),
      ),
    );
  }
}
