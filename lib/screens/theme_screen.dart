import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinpoint/constants/shared_preference_keys.dart';
import 'package:pinpoint/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../design_system/design_system.dart';

class ThemeScreen extends StatefulWidget {
  static const String kRouteName = '/theme';
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  String _selectedFont = 'Inter';
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadFontPreference();
  }

  Future<void> _loadFontPreference() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedFont = _prefs?.getString(kSelectedFontKey) ?? 'Inter';
    });
  }

  Future<void> _saveFontPreference(String font) async {
    await _prefs?.setString(kSelectedFontKey, font);
    setState(() {
      _selectedFont = font;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final accentColors = [
      {'name': 'Neon Mint', 'color': PinpointColors.mint},
      {'name': 'Purple Dream', 'color': PinpointColors.purple},
      {'name': 'Pink Bliss', 'color': PinpointColors.pink},
      {'name': 'Orange Sunset', 'color': PinpointColors.orange},
      {'name': 'Blue Ocean', 'color': PinpointColors.blue},
    ];

    return GradientScaffold(
      appBar: GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.palette_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            const Text('Theme'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Accent Colors Section
          Text(
            'Accent Colors',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 12),
          ...accentColors.map((accent) {
            final isSelected = cs.primary == accent['color'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? cs.surface.withValues(alpha: 0.7)
                      : cs.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? (accent['color'] as Color).withValues(alpha: 0.5)
                        : cs.outline.withValues(alpha: 0.1),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                          alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      PinpointHaptics.medium();
                      final myAppState = MyApp.of(context);
                      myAppState.changeAccentColor(accent['color'] as Color);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: accent['color'] as Color,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (accent['color'] as Color).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              accent['name'] as String,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded,
                                color: accent['color'] as Color),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 32),

          // Fonts Section
          Text(
            'Fonts',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 12),
          _buildFontOption('Inter', GoogleFonts.inter().fontFamily),
          _buildFontOption('Roboto', GoogleFonts.roboto().fontFamily),
          _buildFontOption('Open Sans', GoogleFonts.openSans().fontFamily),
          _buildFontOption('Lato', GoogleFonts.lato().fontFamily),
          _buildFontOption('Montserrat', GoogleFonts.montserrat().fontFamily),
          _buildFontOption('Poppins', GoogleFonts.poppins().fontFamily),
          _buildFontOption(
              'Source Sans Pro', GoogleFonts.sourceSans3().fontFamily),
          _buildFontOption('Noto Sans', GoogleFonts.notoSans().fontFamily),
        ],
      ),
    );
  }

  Widget _buildFontOption(String fontName, String? fontFamily) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isSelected = _selectedFont == fontName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? cs.surface.withValues(alpha: 0.7)
              : cs.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.5)
                : cs.outline.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              PinpointHaptics.medium();
              _saveFontPreference(fontName);
              // Font preference is saved to SharedPreferences
              // TODO: Implement font changing in theme if needed
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      fontName,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded, color: cs.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
