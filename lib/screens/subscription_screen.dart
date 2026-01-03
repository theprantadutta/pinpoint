import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/services/subscription_service.dart';
import 'package:pinpoint/services/subscription_manager.dart';
import 'package:pinpoint/util/show_a_toast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  static const String kRouteName = '/subscription';

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late SubscriptionService _subscriptionService;
  bool _isLoading = false;
  bool _isLoadingProducts = true;
  String? _selectedProductId;
  String? _productLoadError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscriptionService = SubscriptionService();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _productLoadError = null;
    });

    try {
      await _subscriptionService.loadProducts();

      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
          if (!_subscriptionService.hasProducts) {
            _productLoadError = 'No subscription plans available';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
          _productLoadError = 'Failed to load subscription plans';
        });
      }
    }
  }

  @override
  void dispose() {
    _subscriptionService.dispose();
    super.dispose();
  }

  Future<void> _purchaseSubscription(String productId) async {
    setState(() {
      _isLoading = true;
      _selectedProductId = productId;
    });

    try {
      final success = await _subscriptionService.purchase(productId);

      if (!mounted) return;

      if (success) {
        showSuccessToast(
          context: context,
          title: 'Purchase Initiated',
          description: 'Processing your purchase...',
        );
      } else {
        showErrorToast(
          context: context,
          title: 'Purchase Failed',
          description: 'Unable to complete purchase',
        );
      }
    } catch (e) {
      if (!mounted) return;

      showErrorToast(
        context: context,
        title: 'Error',
        description: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedProductId = null;
        });
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
          child: Column(
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
                    TextButton(
                      onPressed: () async {
                        await _subscriptionService.restorePurchases();
                        if (!mounted) return;
                        showSuccessToast(
                          context: context,
                          title: 'Restore Complete',
                          description: 'Purchases restored',
                        );
                      },
                      child: const Text('Restore'),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    // Logo and title
                    Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Image.asset(
                              'assets/images/pinpoint-logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                            .animate()
                            .scale(duration: 600.ms, curve: Curves.elasticOut)
                            .fadeIn(duration: 400.ms),
                        const SizedBox(height: 16),
                        Text(
                          'Pinpoint Premium',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ).animate(delay: 200.ms).fadeIn(),
                        const SizedBox(height: 8),
                        Text(
                          'Unlock all features and sync across devices',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isDark
                                ? PinpointColors.darkTextSecondary
                                : PinpointColors.lightTextSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ).animate(delay: 300.ms).fadeIn(),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Features list
                    _buildFeaturesList(isDark),

                    const SizedBox(height: 32),

                    // Current Plan Card (for premium users)
                    Consumer<SubscriptionManager>(
                      builder: (context, subscriptionManager, child) {
                        if (!subscriptionManager.isPremium) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          children: [
                            _buildCurrentPlanCard(
                              subscriptionManager,
                              colorScheme,
                              isDark,
                            ),
                            const SizedBox(height: 24),
                            // Divider with "Upgrade Options" text
                            if (_hasUpgradeOptions(subscriptionManager))
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: isDark
                                            ? PinpointColors.darkTextTertiary
                                            : PinpointColors.lightTextTertiary,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        'Upgrade Options',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? PinpointColors.darkTextSecondary
                                              : PinpointColors.lightTextSecondary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: isDark
                                            ? PinpointColors.darkTextTertiary
                                            : PinpointColors.lightTextTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),

                    // Subscription plans
                    _buildSubscriptionPlans(colorScheme, isDark),

                    const SizedBox(height: 24),

                    // Footer text
                    Text(
                      'Cancel anytime. Your privacy is always protected with end-to-end encryption.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? PinpointColors.darkTextTertiary
                            : PinpointColors.lightTextTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesList(bool isDark) {
    final features = [
      _Feature(Symbols.cloud_sync, 'Unlimited cloud sync'),
      _Feature(Symbols.devices, 'Multi-device access'),
      _Feature(Symbols.mic, 'Unlimited voice recording'),
      _Feature(Symbols.text_fields, 'Unlimited OCR'),
      _Feature(Symbols.palette, 'All premium themes'),
      _Feature(Symbols.file_download, 'Export to PDF/Markdown'),
      _Feature(Symbols.share, 'Encrypted sharing'),
      _Feature(Symbols.support_agent, 'Priority email support'),
    ];

    return Column(
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PinpointColors.mint.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  feature.icon,
                  size: 20,
                  color: PinpointColors.mint,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  feature.title,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark
                        ? PinpointColors.darkTextPrimary
                        : PinpointColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn().slideX(begin: -0.2, end: 0);
      }).toList(),
    );
  }

  /// Check if user has upgrade options available
  bool _hasUpgradeOptions(SubscriptionManager manager) {
    final currentType = manager.subscriptionType;
    // Lifetime users can't upgrade
    if (currentType == 'lifetime') return false;
    // Monthly/yearly users can upgrade
    return true;
  }

  /// Get plan display name
  String _getPlanDisplayName(String? subscriptionType) {
    switch (subscriptionType) {
      case 'monthly':
        return 'Monthly Plan';
      case 'yearly':
        return 'Yearly Plan';
      case 'lifetime':
        return 'Lifetime';
      default:
        return 'Premium';
    }
  }

  /// Get expiry text for current plan
  String _getExpiryText(SubscriptionManager manager) {
    if (manager.subscriptionType == 'lifetime') {
      return 'Never expires';
    }

    final expiryDate = manager.expirationDate;
    if (expiryDate == null) return '';

    final now = DateTime.now();
    final difference = expiryDate.difference(now);

    // Format the date
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final formattedDate = '${months[expiryDate.month - 1]} ${expiryDate.day}, ${expiryDate.year}';

    if (difference.isNegative) {
      return 'Expired on $formattedDate';
    } else if (manager.isInGracePeriod) {
      return 'Payment pending - Expires $formattedDate';
    } else {
      return 'Renews $formattedDate';
    }
  }

  /// Open Google Play subscriptions page
  Future<void> _openGooglePlaySubscriptions() async {
    try {
      final uri = Uri.parse('https://play.google.com/store/account/subscriptions');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Build the current plan card for premium users
  Widget _buildCurrentPlanCard(
    SubscriptionManager manager,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final planName = _getPlanDisplayName(manager.subscriptionType);
    final expiryText = _getExpiryText(manager);
    final isGracePeriod = manager.isInGracePeriod;

    return GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      border: Border.all(
        color: isGracePeriod ? PinpointColors.warning : PinpointColors.mint,
        width: 2,
      ),
      child: Stack(
        children: [
          // "Current Plan" badge
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isGracePeriod ? PinpointColors.warning : PinpointColors.mint,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isGracePeriod ? Icons.warning_amber_rounded : Icons.check_circle,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isGracePeriod ? 'PAYMENT PENDING' : 'CURRENT PLAN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      color: isGracePeriod ? PinpointColors.warning : PinpointColors.mint,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      planName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? PinpointColors.darkTextPrimary
                            : PinpointColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  expiryText,
                  style: TextStyle(
                    fontSize: 14,
                    color: isGracePeriod
                        ? PinpointColors.warning
                        : (isDark
                            ? PinpointColors.darkTextSecondary
                            : PinpointColors.lightTextSecondary),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _openGooglePlaySubscriptions,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Manage in Google Play'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isGracePeriod
                          ? PinpointColors.warning
                          : colorScheme.primary,
                      side: BorderSide(
                        color: isGracePeriod
                            ? PinpointColors.warning.withValues(alpha: 0.5)
                            : colorScheme.primary.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPlans(ColorScheme colorScheme, bool isDark) {
    // Show loading state
    if (_isLoadingProducts) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Loading subscription plans...',
              style: TextStyle(
                color: isDark
                    ? PinpointColors.darkTextSecondary
                    : PinpointColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Show error state
    if (_productLoadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: PinpointColors.rose,
            ),
            const SizedBox(height: 16),
            Text(
              _productLoadError!,
              style: TextStyle(
                color: isDark
                    ? PinpointColors.darkTextPrimary
                    : PinpointColors.lightTextPrimary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Get current subscription type to filter plans
    final subscriptionManager = SubscriptionManager();
    final currentType = subscriptionManager.subscriptionType;

    // Show subscription plans with dynamic pricing
    // Filter out plans based on current subscription
    return Consumer<SubscriptionManager>(
      builder: (context, manager, child) {
        final widgets = <Widget>[];

        // Monthly - show if not already monthly/yearly/lifetime
        if (currentType != 'monthly' && currentType != 'yearly' && currentType != 'lifetime') {
          widgets.add(_buildDynamicPlanCard(
            productId: SubscriptionService.premiumMonthly,
            title: 'Monthly',
            period: 'per month',
            badge: '7-day free trial',
            colorScheme: colorScheme,
            isDark: isDark,
          ));
        }

        // Yearly - show if not already yearly/lifetime (upgrade from monthly)
        if (currentType != 'yearly' && currentType != 'lifetime') {
          if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 16));
          widgets.add(_buildDynamicPlanCard(
            productId: SubscriptionService.premiumYearly,
            title: 'Yearly',
            period: 'per year',
            badge: currentType == 'monthly' ? 'UPGRADE - Save 33%' : 'BEST VALUE - Save 33%',
            isPopular: true,
            colorScheme: colorScheme,
            isDark: isDark,
          ));
        }

        // Lifetime - show if not already lifetime
        if (currentType != 'lifetime') {
          if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 16));
          widgets.add(_buildDynamicPlanCard(
            productId: SubscriptionService.premiumLifetime,
            title: 'Lifetime',
            period: 'one-time',
            badge: 'Pay once, own forever',
            colorScheme: colorScheme,
            isDark: isDark,
          ));
        }

        // If lifetime user, show thank you message
        if (currentType == 'lifetime') {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.favorite,
                    size: 48,
                    color: PinpointColors.mint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Thank you for your support!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? PinpointColors.darkTextPrimary
                          : PinpointColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have lifetime access to all premium features.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? PinpointColors.darkTextSecondary
                          : PinpointColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(children: widgets);
      },
    );
  }

  Widget _buildDynamicPlanCard({
    required String productId,
    required String title,
    required String period,
    String? badge,
    bool isPopular = false,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    // Get product details from Google Play
    final product = _subscriptionService.getProduct(productId);

    // Fallback if product not found
    if (product == null) {
      return const SizedBox.shrink();
    }

    // Use dynamic price from Google Play
    return _buildPlanCard(
      productId: productId,
      title: title,
      price: product.price, // DYNAMIC PRICE FROM GOOGLE PLAY!
      period: period,
      badge: badge,
      isPopular: isPopular,
      colorScheme: colorScheme,
      isDark: isDark,
    );
  }

  Widget _buildPlanCard({
    required String productId,
    required String title,
    required String price,
    required String period,
    String? badge,
    bool isPopular = false,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    final isSelected = _selectedProductId == productId;
    final isCurrentlyLoading = _isLoading && isSelected;

    return GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      border:
          isPopular ? Border.all(color: colorScheme.primary, width: 2) : null,
      child: Stack(
        children: [
          if (badge != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPopular ? colorScheme.primary : PinpointColors.amber,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? PinpointColors.darkTextPrimary
                        : PinpointColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        price,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        period,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? PinpointColors.darkTextSecondary
                              : PinpointColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isCurrentlyLoading
                        ? null
                        : () => _purchaseSubscription(productId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPopular
                          ? colorScheme.primary
                          : colorScheme.primaryContainer,
                      foregroundColor: isPopular
                          ? Colors.white
                          : colorScheme.onPrimaryContainer,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isCurrentlyLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Subscribe',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isPopular ? Colors.white : null,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;

  _Feature(this.icon, this.title);
}
