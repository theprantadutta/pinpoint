import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design_system/design_system.dart';
import '../../util/show_a_toast.dart';

/// About Pinpoint: brand sticker, version, tagline and the developer link.
Future<void> showSettingsAboutSheet(BuildContext context) async {
  String? version;
  String? build;
  try {
    final info = await PackageInfo.fromPlatform();
    version = info.version;
    build = info.buildNumber;
  } catch (_) {
    // The sheet still makes sense without a version.
  }
  if (!context.mounted) return;

  await showSketchSheet<void>(
    context: context,
    builder: (ctx) => _AboutSheet(version: version, buildNumber: build),
  );
}

class _AboutSheet extends StatelessWidget {
  const _AboutSheet({this.version, this.buildNumber});

  final String? version;
  final String? buildNumber;

  Future<void> _openPortfolio(BuildContext context) async {
    PinpointHaptics.light();
    final l10n = AppL10n.of(context);
    final uri = Uri.parse('https://pranta.dev');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context.mounted) {
        showErrorToast(
          context: context,
          title: l10n.setErrorTitle,
          description: l10n.setUnableToOpenPortfolio,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final s = context.sketch;
    final l10n = AppL10n.of(context);

    return SketchSheet(
      footer: PillButton(
        label: l10n.commonClose,
        onPressed: () => Navigator.of(context).pop(),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const BrandSticker(size: 72, shadow: true),
          const SizedBox(height: 18),
          Semantics(
            header: true,
            child: Text('Pinpoint', style: t.emptyTitle),
          ),
          if (version != null) ...[
            const SizedBox(height: 8),
            SketchTag(label: l10n.setAboutVersion(version!, buildNumber ?? '')),
          ],
          const SizedBox(height: 16),
          Text(
            l10n.setAboutTagline,
            textAlign: TextAlign.center,
            style: t.bodyRegular.copyWith(fontSize: 14, color: s.muted),
          ),
          const SizedBox(height: 22),
          Container(height: SketchStroke.outline, color: s.hairline),
          const SizedBox(height: 18),
          Text(l10n.setAboutDevelopedBy, style: t.caption),
          const SizedBox(height: 8),
          SketchChip(
            label: 'Pranta Dutta',
            trailing: Icon(Icons.open_in_new_rounded, size: 14, color: s.ink),
            onTap: () => _openPortfolio(context),
          ),
        ],
      ),
    );
  }
}
