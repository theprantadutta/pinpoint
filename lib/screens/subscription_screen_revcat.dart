import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../services/revenue_cat_service.dart';
import '../services/premium_service.dart';
import '../services/subscription_manager.dart';
import '../services/notification_service.dart';
import '../util/show_a_toast.dart';

class SubscriptionScreenRevCat extends StatefulWidget {
  const SubscriptionScreenRevCat({super.key});

  static const String kRouteName = '/subscription';

  @override
  State<SubscriptionScreenRevCat> createState() =>
      _SubscriptionScreenRevCatState();
}

class _SubscriptionScreenRevCatState extends State<SubscriptionScreenRevCat> {
  bool _isLoading = true;
  bool _isPremium = false;
  // CustomerInfo? _customerInfo;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    setState(() => _isLoading = true);

    try {
      final isPremium = await RevenueCatService.isPremium();

      if (mounted) {
        setState(() {
          _isPremium = isPremium;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading subscription status: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showPaywall() async {
    try {
      debugPrint('🎨 [SubscriptionScreen] Presenting paywall...');

      // Get premium status before purchase
      final wasPremium = await RevenueCatService.isPremium();

      final paywallResult = await RevenueCatUI.presentPaywallIfNeeded(
        'PinPoint Pro',
      );

      debugPrint('🎨 [SubscriptionScreen] Paywall result: $paywallResult');

      // Refresh premium status after paywall dismissal
      await _loadSubscriptionStatus();
      await PremiumService().refreshPremiumStatus();

      if (mounted) {
        // Also refresh SubscriptionManager to update account section
        await context.read<SubscriptionManager>().checkSubscriptionStatus();

        final isPremium = await RevenueCatService.isPremium();

        // Only show success if user just became premium (not already premium)
        if (mounted && isPremium && !wasPremium) {
          // Show success toast
          showSuccessToast(
            context: context,
            title: 'Welcome to Premium!',
            description: 'You now have access to all premium features',
          );

          // Send local notification
          await NotificationService.showNotification(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: '🎉 Welcome to Premium!',
            body: 'Thank you for your support! You now have unlimited access to all features.',
          );

          PinpointHaptics.success();
        }
      }
    } on PlatformException catch (e) {
      debugPrint('❌ [SubscriptionScreen] Paywall error: ${e.message}');

      if (mounted) {
        showErrorToast(
          context: context,
          title: 'Error',
          description: e.message ?? 'Unable to load subscription options',
        );
      }
    }
  }

  Future<void> _restorePurchases() async {
    try {
      debugPrint('🔄 [SubscriptionScreen] Restoring purchases...');

      showSuccessToast(
        context: context,
        title: 'Restoring...',
        description: 'Checking for previous purchases',
      );

      final customerInfo = await RevenueCatService.restorePurchases();

      await _loadSubscriptionStatus();
      await PremiumService().refreshPremiumStatus();

      if (mounted) {
        // Also refresh SubscriptionManager to update account section
        await context.read<SubscriptionManager>().checkSubscriptionStatus();

        final hasActiveEntitlement =
            customerInfo.entitlements.active.containsKey('PinPoint Pro');

        if (hasActiveEntitlement) {
          showSuccessToast(
            context: context,
            title: 'Purchases Restored!',
            description: 'Your premium subscription has been restored',
          );
          PinpointHaptics.success();
        } else {
          showErrorToast(
            context: context,
            title: 'No Purchases Found',
            description: 'No active subscriptions to restore',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [SubscriptionScreen] Restore error: $e');

      if (mounted) {
        showErrorToast(
          context: context,
          title: 'Restore Failed',
          description: 'Unable to restore purchases',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? PinpointGradients.crescentInk
              : PinpointGradients.oceanQuartz,
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: colorScheme.primary,
                  ),
                )
              : _isPremium
                  ? _buildPremiumActiveScreen()
                  : _buildUpgradeScreen(),
        ),
      ),
    );
  }

  Widget _buildPremiumActiveScreen() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _restorePurchases,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Restore'),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Premium badge
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withValues(alpha: 0.6),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.stars_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                  )
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.elasticOut)
                      .shimmer(duration: 2000.ms),

                  const SizedBox(height: 32),

                  Text(
                    'You\'re Premium!',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? PinpointColors.darkTextPrimary
                          : PinpointColors.lightTextPrimary,
                    ),
                  ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.3, end: 0),

                  const SizedBox(height: 16),

                  Text(
                    'Enjoy unlimited access to all premium features',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark
                          ? PinpointColors.darkTextSecondary
                          : PinpointColors.lightTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.3, end: 0),

                  const SizedBox(height: 48),

                  // Features list
                  ..._buildPremiumFeatures(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradeScreen() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _restorePurchases,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Restore'),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.asset(
                      'assets/images/pinpoint-logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                )
                    .animate()
                    .scale(duration: 800.ms, curve: Curves.elasticOut)
                    .fadeIn(),

                const SizedBox(height: 24),

                Text(
                  'Unlock Premium',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? PinpointColors.darkTextPrimary
                        : PinpointColors.lightTextPrimary,
                  ),
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.3, end: 0),

                const SizedBox(height: 12),

                Text(
                  'Get unlimited access to all features',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isDark
                        ? PinpointColors.darkTextSecondary
                        : PinpointColors.lightTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.3, end: 0),

                const SizedBox(height: 48),

                // Features
                ..._buildPremiumFeatures(),

                const SizedBox(height: 48),

                // CTA Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _showPaywall,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stars_rounded, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'View Plans',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.3, end: 0),

                const SizedBox(height: 16),

                Text(
                  'Start with 14-day free trial',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? PinpointColors.darkTextSecondary
                        : PinpointColors.lightTextSecondary,
                  ),
                ).animate(delay: 700.ms).fadeIn(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPremiumFeatures() {
    final features = [
      {'icon': Icons.cloud_sync_rounded, 'title': 'Unlimited Cloud Sync'},
      {'icon': Icons.devices_rounded, 'title': 'Multi-Device Access'},
      {'icon': Icons.mic_rounded, 'title': 'Unlimited Voice Recording'},
      {'icon': Icons.document_scanner_rounded, 'title': 'Unlimited OCR Scans'},
      {'icon': Icons.palette_rounded, 'title': 'All Premium Themes'},
      {'icon': Icons.file_download_rounded, 'title': 'Export to PDF/Markdown'},
      {'icon': Icons.shield_rounded, 'title': 'Encrypted Sharing'},
      {'icon': Icons.support_agent_rounded, 'title': 'Priority Email Support'},
    ];

    return features.asMap().entries.map((entry) {
      final index = entry.key;
      final feature = entry.value;

      return _buildFeatureItem(
        icon: feature['icon'] as IconData,
        title: feature['title'] as String,
      )
          .animate(delay: Duration(milliseconds: 400 + (index * 50)))
          .fadeIn()
          .slideX(begin: -0.2, end: 0);
    }).toList();
  }

  Widget _buildFeatureItem({required IconData icon, required String title}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(
            Icons.check_circle_rounded,
            color: colorScheme.primary,
            size: 24,
          ),
        ],
      ),
    );
  }
}
