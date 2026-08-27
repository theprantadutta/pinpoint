import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/screens/terms_acceptance_screen.dart';
import 'package:pinpoint/services/subscription_service.dart';
import 'package:pinpoint/services/subscription_manager.dart';
import 'package:pinpoint/util/show_a_toast.dart';
import 'package:pinpoint/util/localized_dates.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
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
  bool _isRestoring = false;
  String? _selectedProductId;
  String? _productLoadError;

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'Subscription');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscriptionService = SubscriptionService();
    _loadProducts();
    getIt<AnalyticsFacade>().trackSubscriptionScreenViewed();
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
            _productLoadError = AppL10n.of(context).subNoPlansAvailable;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
          _productLoadError = AppL10n.of(context).subLoadPlansFailed;
        });
      }
    }
  }

  // NOTE: no dispose() override on purpose. SubscriptionService is a
  // process-wide singleton and owns the app-lifetime purchase listener; this
  // screen only reads it. Tearing it down here used to kill every subsequent
  // purchase, restore and deferred payment for the rest of the session.

  Future<void> _handleRestore() async {
    getIt<AnalyticsFacade>().trackRestorePurchaseInitiated();
    setState(() {
      _isRestoring = true;
    });

    await _subscriptionService.restorePurchases(
      onComplete: (restoredCount, hasError) {
        if (!mounted) return;

        setState(() {
          _isRestoring = false;
        });

        if (hasError) {
          showErrorToast(
            context: context,
            title: AppL10n.of(context).subRestoreFailed,
            description: AppL10n.of(context).subRestoreFailedBody,
          );
        } else if (restoredCount > 0) {
          showSuccessToast(
            context: context,
            title: AppL10n.of(context).subRestoreComplete,
            description:
                AppL10n.of(context).subRestoredCount(restoredCount),
          );
        } else {
          showInfoToast(
            context: context,
            title: AppL10n.of(context).subNoPurchasesFound,
            description: AppL10n.of(context).subNoPurchasesFoundBody,
          );
        }
      },
    );
  }

  Future<void> _purchaseSubscription(String productId) async {
    setState(() {
      _isLoading = true;
      _selectedProductId = productId;
    });

    // Only the user's intent is tracked here. Everything downstream — whether
    // the billing sheet launched, whether the user cancelled, whether the sale
    // was verified — is emitted by SubscriptionService, which keeps listening
    // after this route is gone.
    getIt<AnalyticsFacade>().trackCheckoutStarted(productId: productId);

    try {
      final success = await _subscriptionService.purchase(productId);

      if (!mounted) return;

      if (success) {
        showSuccessToast(
          context: context,
          title: AppL10n.of(context).subPurchaseInitiated,
          description: AppL10n.of(context).subProcessingPurchase,
        );
      } else {
        showErrorToast(
          context: context,
          title: AppL10n.of(context).subPurchaseFailed,
          description: AppL10n.of(context).subPurchaseFailedBody,
        );
      }
    } catch (e) {
      // purchase() swallows store errors and returns false after emitting
      // checkout_launch_failed itself, so nothing is tracked here.
      if (!mounted) return;

      showErrorToast(
        context: context,
        title: AppL10n.of(context).setErrorTitle,
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
                    _isRestoring
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: _handleRestore,
                            child: Text(AppL10n.of(context).subRestore),
                          ),
                  ],
                ),
              ),

              Expanded(
                child: ResponsiveCenter(
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
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.3),
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
                            AppL10n.of(context).subHeroTitle,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ).animate(delay: 200.ms).fadeIn(),
                          const SizedBox(height: 8),
                          Text(
                            AppL10n.of(context).subHeroSubtitle,
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: isDark
                                              ? PinpointColors.darkTextTertiary
                                              : PinpointColors
                                                  .lightTextTertiary,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text(
                                          AppL10n.of(context).subUpgradeOptions,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? PinpointColors
                                                    .darkTextSecondary
                                                : PinpointColors
                                                    .lightTextSecondary,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: isDark
                                              ? PinpointColors.darkTextTertiary
                                              : PinpointColors
                                                  .lightTextTertiary,
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

                      // Legal / auto-renewable subscription disclosure (App Store
                      // Guideline 3.1.2 requires this + Terms & Privacy links).
                      _buildLegalFooter(theme, isDark),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the bundled Terms of Service & Privacy Policy in read-only mode.
  void _openLegal() {
    context.push(TermsAcceptanceScreen.kRouteName, extra: true);
  }

  /// Auto-renewable subscription disclosure + Terms/Privacy links.
  ///
  /// Required by App Store Review Guideline 3.1.2: the paywall must state the
  /// subscription length/price context, that it auto-renews, how to cancel, and
  /// provide functional links to the Terms of Use (EULA) and Privacy Policy.
  Widget _buildLegalFooter(ThemeData theme, bool isDark) {
    final tertiary = isDark
        ? PinpointColors.darkTextTertiary
        : PinpointColors.lightTextTertiary;
    final linkColor = theme.colorScheme.primary;

    return Column(
      children: [
        Text(
          AppL10n.of(context).subLegalAutoRenew(_storeName),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: tertiary, fontSize: 11),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GestureDetector(
              onTap: _openLegal,
              child: Text(
                AppL10n.of(context).subTermsOfUse,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: linkColor,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text('   •   ',
                style: theme.textTheme.bodySmall?.copyWith(color: tertiary)),
            GestureDetector(
              onTap: _openLegal,
              child: Text(
                AppL10n.of(context).subPrivacyPolicy,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: linkColor,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturesList(bool isDark) {
    // Every bullet here must describe a limit that PremiumService actually
    // enforces today, so the paywall never sells something the app cannot do.
    // The removed bullets (images/attachments, drawing, encrypted sharing,
    // priority support) had no shipped free/premium delta; do not add a bullet
    // back until its gate has a live call site. Voice length was removed for
    // the same reason and then restored once the cap became real — the free
    // recorder now stops at PremiumLimits.maxVoiceRecordingDurationForFree in
    // create_note_screen_v2.dart.
    final features = [
      _Feature(Symbols.cloud_sync, AppL10n.of(context).subFeatureSync),
      _Feature(Symbols.folder, AppL10n.of(context).subFeatureFolders),
      _Feature(Symbols.mic, AppL10n.of(context).subFeatureVoice),
      _Feature(Symbols.text_fields, AppL10n.of(context).subFeatureOcr),
      _Feature(Symbols.file_download, AppL10n.of(context).subFeatureExport),
      _Feature(Symbols.palette, AppL10n.of(context).subFeatureThemes),
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
        return AppL10n.of(context).setPlanMonthly;
      case 'yearly':
        return AppL10n.of(context).setPlanYearly;
      case 'lifetime':
        return AppL10n.of(context).setPlanLifetime;
      default:
        return AppL10n.of(context).setPlanPremium;
    }
  }

  /// Get expiry text for current plan
  String _getExpiryText(BuildContext context, SubscriptionManager manager) {
    final l10n = AppL10n.of(context);
    if (manager.subscriptionType == 'lifetime') {
      return l10n.subscriptionNeverExpires;
    }

    final expiryDate = manager.expirationDate;
    if (expiryDate == null) return '';

    final now = DateTime.now();
    final difference = expiryDate.difference(now);

    final formattedDate = LocalizedDates.mediumDate(context, expiryDate);

    if (difference.isNegative) {
      return l10n.subscriptionExpiredOn(formattedDate);
    } else if (manager.isInGracePeriod) {
      return l10n.subscriptionPaymentPending(formattedDate);
    } else if (manager.isCancelledButActive) {
      return l10n.subscriptionCancelledAccessUntil(formattedDate);
    } else {
      return l10n.subscriptionRenews(formattedDate);
    }
  }

  /// Name of the current platform's store, for UI labels.
  String get _storeName => Platform.isIOS ? 'App Store' : 'Google Play';

  /// Open the platform's subscription-management page — App Store on iOS,
  /// Google Play on Android. (Store policy requires linking to the correct one.)
  Future<void> _openManageSubscriptions() async {
    try {
      final uri = Uri.parse(
        Platform.isIOS
            ? 'https://apps.apple.com/account/subscriptions'
            : 'https://play.google.com/store/account/subscriptions',
      );
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
    final expiryText = _getExpiryText(context, manager);
    final isGracePeriod = manager.isInGracePeriod;
    final isCancelledButActive = manager.isCancelledButActive;

    final accent = isGracePeriod
        ? PinpointColors.warning
        : isCancelledButActive
            ? PinpointColors.amber
            : PinpointColors.mint;
    final badgeLabel = isGracePeriod
        ? AppL10n.of(context).subPaymentPendingBadge
        : isCancelledButActive
            ? AppL10n.of(context).subCancelledBadge
            : AppL10n.of(context).subCurrentPlanBadge;
    final badgeIcon = isGracePeriod
        ? Icons.warning_amber_rounded
        : isCancelledButActive
            ? Icons.cancel_schedule_send
            : Icons.check_circle;

    return GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      border: Border.all(
        color: accent,
        width: 2,
      ),
      child: Stack(
        children: [
          // Status badge
          PositionedDirectional(
            top: 0,
            end: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadiusDirectional.only(
                  topEnd: Radius.circular(20),
                  bottomStart: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    badgeIcon,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    badgeLabel,
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
                      color: accent,
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
                    color: (isGracePeriod || isCancelledButActive)
                        ? accent
                        : (isDark
                            ? PinpointColors.darkTextSecondary
                            : PinpointColors.lightTextSecondary),
                  ),
                ),
                if (isCancelledButActive) ...[
                  const SizedBox(height: 8),
                  Text(
                    AppL10n.of(context).subResubscribePrompt(_storeName),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? PinpointColors.darkTextSecondary
                          : PinpointColors.lightTextSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _openManageSubscriptions,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: Text(isCancelledButActive
                        ? AppL10n.of(context).subResubscribeIn(_storeName)
                        : AppL10n.of(context).subManageIn(_storeName)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: (isGracePeriod || isCancelledButActive)
                          ? accent
                          : colorScheme.primary,
                      side: BorderSide(
                        color: ((isGracePeriod || isCancelledButActive)
                                ? accent
                                : colorScheme.primary)
                            .withValues(alpha: 0.5),
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
              AppL10n.of(context).subLoadingPlans,
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
        if (currentType != 'monthly' &&
            currentType != 'yearly' &&
            currentType != 'lifetime') {
          widgets.add(_buildDynamicPlanCard(
            productId: SubscriptionService.premiumMonthly,
            title: AppL10n.of(context).subPlanMonthly,
            period: 'per month',
            colorScheme: colorScheme,
            isDark: isDark,
          ));
        }

        // Yearly - show if not already yearly/lifetime (upgrade from monthly)
        if (currentType != 'yearly' && currentType != 'lifetime') {
          if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 16));
          widgets.add(_buildDynamicPlanCard(
            productId: SubscriptionService.premiumYearly,
            title: AppL10n.of(context).subPlanYearly,
            period: 'per year',
            badge: currentType == 'monthly'
                ? AppL10n.of(context).subBadgeUpgradeSave
                : AppL10n.of(context).subBadgeBestValue,
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
            title: AppL10n.of(context).subPlanLifetime,
            period: 'one-time',
            badge: AppL10n.of(context).subBadgePayOnce,
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
                    AppL10n.of(context).subThankYou,
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
                    AppL10n.of(context).subLifetimeAccess,
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

    // Use dynamic price from Google Play. Use getDisplayPrice (not
    // product.price) so the real recurring price shows, skipping any
    // zero-priced intro pricing phase Google Play may report first.
    return _buildPlanCard(
      productId: productId,
      title: title,
      price: _subscriptionService.getDisplayPrice(product),
      period: period,
      // Read from the live Play offer, so the card stops advertising a trial
      // the moment the offer is withdrawn in the Console.
      trialDays: _subscriptionService.getTrialDays(product),
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
    int? trialDays,
    String? badge,
    bool isPopular = false,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    final isSelected = _selectedProductId == productId;
    final isCurrentlyLoading = _isLoading && isSelected;
    // The lifetime plan is a one-time non-consumable, not a subscription, so its
    // CTA must not say "Subscribe" (accurate purchase labeling — App Store 3.1.2).
    final isOneTime = productId == SubscriptionService.premiumLifetime;
    // A one-time purchase can never carry a trial, whatever the store reports.
    final hasTrial = !isOneTime && trialDays != null && trialDays > 0;
    final ctaLabel = isOneTime
        ? AppL10n.of(context).subBuyLifetime
        : hasTrial
            ? AppL10n.of(context).subTrialCta(trialDays)
            : AppL10n.of(context).subSubscribe;

    return GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      border:
          isPopular ? Border.all(color: colorScheme.primary, width: 2) : null,
      child: Stack(
        children: [
          if (badge != null)
            PositionedDirectional(
              top: 0,
              end: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPopular ? colorScheme.primary : PinpointColors.amber,
                  borderRadius: const BorderRadiusDirectional.only(
                    topEnd: Radius.circular(20),
                    bottomStart: Radius.circular(12),
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
                  alignment: AlignmentDirectional.centerStart,
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
                if (hasTrial) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Symbols.card_giftcard,
                          size: 16, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          // The price is already formatted and localized by the
                          // store; it is inserted, never rebuilt here.
                          AppL10n.of(context)
                              .subTrialThenPrice(trialDays, price),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
                            ctaLabel,
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
