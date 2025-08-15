import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinpoint/constants/shared_preference_keys.dart';
import 'package:pinpoint/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Theme'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Color Schemes',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...List.generate(FlexScheme.values.length, (index) {
            final scheme = FlexScheme.values[index];
            return ListTile(
              title: Text(scheme.name),
              onTap: () {
                final myAppState = MyApp.of(context);
                myAppState.changeFlexScheme(scheme);
                Navigator.of(context).pop();
              },
            );
          }),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Fonts', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
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
