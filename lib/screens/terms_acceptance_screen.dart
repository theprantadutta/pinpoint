import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/shared_preference_keys.dart';
import '../design_system/design_system.dart';
import 'auth_screen.dart';

/// Terms and Privacy acceptance screen
/// Shows terms of service and privacy policy with acceptance requirement
class TermsAcceptanceScreen extends StatefulWidget {
  const TermsAcceptanceScreen({super.key, this.isViewOnly = false});

  static const String kRouteName = '/terms-acceptance';

  /// If true, shows in view-only mode (no acceptance required, for settings)
  final bool isViewOnly;

  @override
  State<TermsAcceptanceScreen> createState() => _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends State<TermsAcceptanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasAccepted = false;
  String _termsContent = '';
  String _privacyContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLegalDocuments();
  }

  Future<void> _loadLegalDocuments() async {
    try {
      final termsData =
          await rootBundle.loadString('assets/legal/terms_of_service.md');
      final privacyData =
          await rootBundle.loadString('assets/legal/privacy_policy.md');

      setState(() {
        _termsContent = termsData;
        _privacyContent = privacyData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading legal documents: $e');
      setState(() {
        _termsContent = '# Error\n\nFailed to load terms of service.';
        _privacyContent = '# Error\n\nFailed to load privacy policy.';
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptTerms() async {
    if (!_hasAccepted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kHasAcceptedTermsKey, true);
      await prefs.setString(
        kTermsAcceptedDateKey,
        DateTime.now().toIso8601String(),
      );

      if (!mounted) return;

      // Navigate to auth screen
      context.go(AuthScreen.kRouteName);
    } catch (e) {
      debugPrint('Error saving terms acceptance: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save your acceptance. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.isViewOnly ? 'Terms & Privacy' : 'Review & Accept'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isViewOnly
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Terms of Service'),
            Tab(text: 'Privacy Policy'),
          ],
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? PinpointGradients.crescentInk
              : PinpointGradients.oceanQuartz,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Tab view
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildMarkdownView(_termsContent, isDark),
                          _buildMarkdownView(_privacyContent, isDark),
                        ],
                      ),
                    ),

                    // Acceptance section (only if not view-only mode)
                    if (!widget.isViewOnly)
                      _buildAcceptanceSection(colorScheme, isDark),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildMarkdownView(String content, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Markdown(
          data: content,
          padding: const EdgeInsets.all(20),
          styleSheet: MarkdownStyleSheet(
            h1: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? PinpointColors.darkTextPrimary
                  : PinpointColors.lightTextPrimary,
            ),
            h2: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? PinpointColors.darkTextPrimary
                  : PinpointColors.lightTextPrimary,
            ),
            h3: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? PinpointColors.darkTextPrimary
                  : PinpointColors.lightTextPrimary,
            ),
            p: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark
                  ? PinpointColors.darkTextSecondary
                  : PinpointColors.lightTextSecondary,
            ),
            listBullet: TextStyle(
              color: isDark
                  ? PinpointColors.darkTextSecondary
                  : PinpointColors.lightTextSecondary,
            ),
            strong: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark
                  ? PinpointColors.darkTextPrimary
                  : PinpointColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptanceSection(ColorScheme colorScheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Acceptance checkbox
          CheckboxListTile(
            value: _hasAccepted,
            onChanged: (value) {
              setState(() {
                _hasAccepted = value ?? false;
              });
            },
            title: Text(
              'I have read and agree to the Terms of Service and Privacy Policy',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? PinpointColors.darkTextPrimary
                    : PinpointColors.lightTextPrimary,
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 12),

          // Accept button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _hasAccepted ? _acceptTerms : null,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Accept and Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
