import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/components/paywall/paywall_widgets.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/screens/terms_acceptance_screen.dart';
import 'package:pinpoint/services/purchases/purchase_mapping.dart';
import 'package:pinpoint/services/subscription_service.dart';
import 'package:pinpoint/services/subscription_manager.dart';
import 'package:pinpoint/util/show_a_toast.dart';
import 'package:pinpoint/util/localized_dates.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

/// The Pinpoint Pro paywall.
///
/// Every price and trial on this screen comes from the store: prices from the
/// product details, the "SAVE x%" badge computed from those prices, and the
/// trial from the live offer for THIS user (see [SubscriptionService
/// .resolveTrialDays]). Nothing about money is hardcoded here.
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

  /// The plan card the user has picked; the CTA buys this one.
  String? _chosenPlan;

  /// Trial length per product id, as the store reports it FOR THIS USER.
  /// Resolved once when products load — the StoreKit eligibility check is a
  /// platform call, so it cannot happen during build.
  final Map<String, int?> _trialDays = {};

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
      await _resolveTrials();

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

  /// Ask the store what trial, if any, each plan carries for this user.
  ///
  /// Never throws: a plan whose trial cannot be resolved simply shows its
  /// normal copy. Silence is always safe here; a wrong trial claim is not.
  Future<void> _resolveTrials() async {
    for (final product in _subscriptionService.products) {
      try {
        _trialDays[product.id] =
            await _subscriptionService.resolveTrialDays(product);
      } catch (_) {
        _trialDays[product.id] = null;
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
    final s = context.sketch;
    final t = context.type;
    final l10n = AppL10n.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
          SketchSpace.screenX, 6, SketchSpace.screenX - 2, 0),
      child: Row(
        children: [
          if (_isRestoring)
            SizedBox(
              width: SketchSpace.minTap,
              height: SketchSpace.minTap,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: s.ink),
                ),
              ),
            )
          else
            SketchTextAction(
              label: l10n.subRestore,
              onTap: _handleRestore,
              style: t.chip.copyWith(fontSize: 14),
            ),
          const Spacer(),
          CircleIconButton.close(
            context,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: s.bg,
      body: DoodleBackground(
        top: DoodleBackground.premiumTop,
        squiggle: true,
        child: SafeArea(
          bottom: false,
          child: SketchContentWidth(
            child: Column(
              children: [
                header,
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(bottom: 24 + bottom),
                    children: [
                      const SizedBox(height: 4),
                      const PaywallStickerCollage(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            SketchSpace.editorX, 6, SketchSpace.editorX, 0),
                        child: HighlightedText(
                          l10n.pwHeadline,
                          style: t.heroTitle,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            SketchSpace.editorX, 10, SketchSpace.editorX, 0),
                        child: Text(
                          l10n.pwSubtitle,
                          style: t.bodyRegular
                              .copyWith(fontSize: 14, color: s.muted),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            SketchSpace.screenX, 16, SketchSpace.screenX, 0),
                        child: PaywallLimitsTable(
                            rows: paywallLimitRows(l10n)),
                      ),

                      // Current plan card (for premium users)
                      Consumer<SubscriptionManager>(
                        builder: (context, subscriptionManager, child) {
                          if (!subscriptionManager.isPremium) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(
                                SketchSpace.screenX,
                                20,
                                SketchSpace.screenX,
                                0),
                            child:
                                _buildCurrentPlanCard(subscriptionManager),
                          );
                        },
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            SketchSpace.screenX, 24, SketchSpace.screenX, 0),
                        child: _buildSubscriptionPlans(),
                      ),

                      // Legal / auto-renewable subscription disclosure (App
                      // Store Guideline 3.1.2 requires this + Terms & Privacy
                      // links).
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            SketchSpace.editorX, 18, SketchSpace.editorX, 0),
                        child: _buildLegalFooter(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
  Widget _buildLegalFooter() {
    final t = context.type;
    final s = context.sketch;
    final small = t.caption.copyWith(fontSize: 11);

    return Column(
      children: [
        Text(
          AppL10n.of(context).subLegalAutoRenew(_storeName),
          style: small,
          textAlign: TextAlign.center,
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          children: [
            SketchTextAction(
              label: AppL10n.of(context).subTermsOfUse,
              onTap: _openLegal,
              muted: true,
              style: small.copyWith(fontWeight: FontWeight.w600),
            ),
            SketchTextAction(
              label: AppL10n.of(context).subPrivacyPolicy,
              onTap: _openLegal,
              muted: true,
              style: small.copyWith(
                  fontWeight: FontWeight.w600, color: s.muted),
            ),
          ],
        ),
      ],
    );
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
  Widget _buildCurrentPlanCard(SubscriptionManager manager) {
    final t = context.type;
    final l10n = AppL10n.of(context);
    final planName = _getPlanDisplayName(manager.subscriptionType);
    final expiryText = _getExpiryText(context, manager);
    final isGracePeriod = manager.isInGracePeriod;
    final isCancelledButActive = manager.isCancelledButActive;

    final pastel = isGracePeriod
        ? SketchPastels.yellow
        : isCancelledButActive
            ? SketchPastels.pink
            : SketchPastels.mint;
    final badgeLabel = isGracePeriod
        ? l10n.subPaymentPendingBadge
        : isCancelledButActive
            ? l10n.subCancelledBadge
            : l10n.subCurrentPlanBadge;

    return SketchCard(
      radius: SketchRadius.group,
      padding: const EdgeInsets.all(SketchSpace.cardPadLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const StickerTile(
                color: SketchPastels.lavender,
                size: 40,
                angle: -8,
                icon: Icons.workspace_premium_rounded,
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(planName, style: t.cardTitleLarge)),
              SketchTag(label: badgeLabel, pastel: pastel),
            ],
          ),
          if (expiryText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              expiryText,
              style: t.bodySmall.copyWith(
                color: (isGracePeriod || isCancelledButActive)
                    ? SketchFunctional.error
                    : null,
              ),
            ),
          ],
          if (isCancelledButActive) ...[
            const SizedBox(height: 6),
            Text(l10n.subResubscribePrompt(_storeName), style: t.caption),
          ],
          const SizedBox(height: 14),
          PillButton.secondary(
            height: 48,
            icon: Icons.open_in_new_rounded,
            label: isCancelledButActive
                ? l10n.subResubscribeIn(_storeName)
                : l10n.subManageIn(_storeName),
            onPressed: _openManageSubscriptions,
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPlans() {
    final t = context.type;
    final s = context.sketch;
    final l10n = AppL10n.of(context);

    // Show loading state
    if (_isLoadingProducts) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _PlanPlaceholder()),
              const SizedBox(width: 10),
              Expanded(child: _PlanPlaceholder()),
            ],
          ),
          const SizedBox(height: 12),
          Text(l10n.subLoadingPlans, style: t.caption),
        ],
      );
    }

    // Show error state
    if (_productLoadError != null) {
      return SketchCard(
        radius: SketchRadius.group,
        padding: const EdgeInsets.all(SketchSpace.cardPadLg),
        child: Column(
          children: [
            Text(_productLoadError!,
                textAlign: TextAlign.center, style: t.bodyRegular),
            const SizedBox(height: 14),
            PillButton.secondary(
              height: 48,
              icon: Icons.refresh_rounded,
              label: l10n.commonRetry,
              onPressed: _loadProducts,
            ),
          ],
        ),
      );
    }

    return Consumer<SubscriptionManager>(
      builder: (context, manager, child) {
        // Filter out the plan the user currently HAS. The server keeps
        // reporting the last subscription_type after a plan lapses, so
        // without the isPremium check an expired monthly subscriber could
        // never buy monthly again.
        final currentType = manager.isPremium ? manager.subscriptionType : null;

        // If lifetime user, show thank you message
        if (currentType == 'lifetime') {
          return SketchCard(
            pastel: SketchPastels.mint,
            radius: SketchRadius.group,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.favorite_rounded, size: 36),
                const SizedBox(height: 12),
                Text(l10n.subThankYou,
                    textAlign: TextAlign.center,
                    style: t.sectionTitle
                        .copyWith(color: SketchPastels.onPastel)),
                const SizedBox(height: 6),
                Text(l10n.subLifetimeAccess,
                    textAlign: TextAlign.center,
                    style: t.bodySmall.copyWith(color: SketchPastels.onPastel)),
              ],
            ),
          );
        }

        final monthly =
            _subscriptionService.getProduct(SubscriptionService.premiumMonthly);
        final yearly =
            _subscriptionService.getProduct(SubscriptionService.premiumYearly);
        final lifetime = _subscriptionService
            .getProduct(SubscriptionService.premiumLifetime);

        // Monthly - show if not already monthly/yearly/lifetime
        final showMonthly = monthly != null &&
            currentType != 'monthly' &&
            currentType != 'yearly';
        // Yearly - show if not already yearly (upgrade from monthly)
        final showYearly = yearly != null && currentType != 'yearly';
        final showLifetime = lifetime != null;

        final available = [
          if (showYearly) SubscriptionService.premiumYearly,
          if (showMonthly) SubscriptionService.premiumMonthly,
          if (showLifetime) SubscriptionService.premiumLifetime,
        ];
        if (available.isEmpty) return const SizedBox.shrink();
        final chosen =
            available.contains(_chosenPlan) ? _chosenPlan! : available.first;

        // Computed from the store's prices, never hardcoded.
        final savings = monthly != null && yearly != null
            ? yearlySavingsPercent(monthly, yearly)
            : null;

        Widget card(String productId, String title,
            {String? badge, String? caption}) {
          final product = _subscriptionService.getProduct(productId)!;
          return PaywallPlanCard(
            title: title,
            // getDisplayPrice (not product.price) so the real recurring price
            // shows, skipping any zero-priced intro phase Play reports first.
            price: _subscriptionService.getDisplayPrice(product),
            selected: chosen == productId,
            badge: badge,
            caption: caption,
            onTap: _isLoading
                ? null
                : () {
                    PinpointHaptics.selection();
                    setState(() => _chosenPlan = productId);
                  },
          );
        }

        final monthlyCard =
            showMonthly ? card(SubscriptionService.premiumMonthly, l10n.subPlanMonthly) : null;
        final yearlyCard = showYearly
            ? card(
                SubscriptionService.premiumYearly,
                l10n.subPlanYearly,
                badge: savings == null ? null : l10n.pwSave(savings),
              )
            : null;

        // The chosen plan decides the CTA. The lifetime plan is a one-time
        // non-consumable, not a subscription, so its CTA must not say
        // "Subscribe" (accurate purchase labeling — App Store 3.1.2), and it
        // can never carry a trial, whatever the store reports.
        // Nor is a trial offered to someone already on Premium: whatever the
        // store says about intro-offer eligibility (a grant, or a purchase
        // made on another platform, leaves it eligible), "Start free trial"
        // under a "Current plan" badge reads as a mistake.
        final isOneTime = chosen == SubscriptionService.premiumLifetime;
        final trialDays =
            isOneTime || manager.isPremium ? null : _trialDays[chosen];
        final hasTrial = trialDays != null && trialDays > 0;
        final chosenPrice = _subscriptionService
            .getDisplayPrice(_subscriptionService.getProduct(chosen)!);
        final ctaLabel = isOneTime
            ? l10n.subBuyLifetime
            : hasTrial
                ? l10n.subTrialCta(trialDays)
                : l10n.pwContinue;
        final isCurrentlyLoading = _isLoading && _selectedProductId == chosen;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (monthlyCard != null && yearlyCard != null)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: monthlyCard),
                    const SizedBox(width: 10),
                    Expanded(child: yearlyCard),
                  ],
                ),
              )
            else if (monthlyCard != null || yearlyCard != null)
              (monthlyCard ?? yearlyCard)!,
            if (showLifetime) ...[
              if (showMonthly || showYearly) const SizedBox(height: 14),
              card(
                SubscriptionService.premiumLifetime,
                l10n.subPlanLifetime,
                caption: l10n.subBadgePayOnce,
              ),
            ],
            const SizedBox(height: 14),
            PillButton(
              label: ctaLabel,
              loading: isCurrentlyLoading,
              onPressed:
                  _isLoading ? null : () => _purchaseSubscription(chosen),
            ),
            if (hasTrial) ...[
              const SizedBox(height: 10),
              Text(
                // The price is already formatted and localized by the
                // store; it is inserted, never rebuilt here.
                l10n.subTrialThenPrice(trialDays, chosenPrice),
                textAlign: TextAlign.center,
                style: t.chip.copyWith(fontSize: 12, color: s.ink),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              l10n.pwCancelAnytime,
              textAlign: TextAlign.center,
              style: t.caption.copyWith(fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}

/// A soft, outlined plan-card stand-in while the store answers.
class _PlanPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: s.soft,
        borderRadius: BorderRadius.circular(SketchRadius.card),
        border: Border.all(color: s.hairline, width: SketchStroke.outline),
      ),
    );
  }
}
