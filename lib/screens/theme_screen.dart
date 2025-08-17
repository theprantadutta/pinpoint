import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinpoint/constants/shared_preference_keys.dart';
import 'package:pinpoint/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pinpoint/design/app_theme.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Theme'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient background
          Glass(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme & Fonts',
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
          
          // Content
          Expanded(
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Color Schemes',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...List.generate(FlexScheme.values.length, (index) {
                  final scheme = FlexScheme.values[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      title: Text(scheme.name),
                      onTap: () {
                        final myAppState = MyApp.of(context);
                        myAppState.changeFlexScheme(scheme);
                        Navigator.of(context).pop();
                      },
                    ),
                  );
                }),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Fonts', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _buildFontOption('Inter', GoogleFonts.inter().fontFamily),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _buildFontOption('Roboto', GoogleFonts.roboto().fontFamily),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _buildFontOption('Open Sans', GoogleFonts.openSans().fontFamily),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _buildFontOption('Lato', GoogleFonts.lato().fontFamily),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _buildFontOption('Montserrat', GoogleFonts.montserrat().fontFamily),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _buildFontOption('Poppins', GoogleFonts.poppins().fontFamily),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _buildFontOption(
                      'Source Sans Pro', GoogleFonts.sourceSans3().fontFamily),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _buildFontOption('Noto Sans', GoogleFonts.notoSans().fontFamily),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontOption(String fontName, String? fontFamily) {
    return ListTile(
      title: Text(
        fontName,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
        ),
      ),
      trailing: _selectedFont == fontName
          ? const Icon(Icons.check, color: Colors.green)
          : null,
      onTap: () {
        _saveFontPreference(fontName);
        // Update the app theme with the new font
        final myAppState = MyApp.of(context);
        myAppState.changeFont(fontName);
        Navigator.of(context).pop();
      },
    );
  }
}