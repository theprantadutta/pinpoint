/// Pure, I/O-free helpers for the OpenIAP purchase flow.
///
/// Everything here is a function of its arguments: no plugin calls, no
/// platform channels, no singletons. That is deliberate — the decisions that
/// cost real money (which offer to buy, what to send the backend, whether a
/// purchase has already been delivered, what may appear in an analytics
/// parameter) live here where they can be tested exhaustively, and
/// `SubscriptionService` stays a thin shell around the plugin.
///
/// See `test/services/purchase_mapping_test.dart`.
library;

import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';

/// Coarse, closed-set reason codes for checkout/verification analytics.
///
/// Analytics parameters must never carry an exception string, a store debug
/// message, a purchase token or verification data — raw detail goes to the
/// device log only. Anything not in this list is reported as
/// [PurchaseReasonCodes.unknown].
abstract final class PurchaseReasonCodes {
  static const String storeUnavailable = 'store_unavailable';
  static const String productNotFound = 'product_not_found';
  static const String launchRejected = 'launch_rejected';
  static const String noPurchaseToken = 'no_purchase_token';
  static const String verificationRejected = 'verification_rejected';
  static const String noOfferToken = 'no_offer_token';
  static const String unknown = 'unknown';

  /// Firebase caps string parameter values at 100 chars; store error codes are
  /// short enums in practice, but clamp defensively.
  static const int maxLength = 100;
}

/// What the backend needs to verify one purchase.
///
/// The wire contract is unchanged from the `in_app_purchase` era, so the
/// backend needed no migration: `purchase_token` is the Play purchase token on
/// Android and the StoreKit 2 signed transaction (JWS) on iOS, which
/// `AppleStoreService` already verifies.
class BackendPurchasePayload {
  const BackendPurchasePayload({
    required this.productId,
    required this.purchaseToken,
    required this.platform,
  });

  final String productId;
  final String purchaseToken;

  /// `'android'` or `'ios'`, matching what the backend switches on.
  final String platform;
}

/// The stable identity of a purchase, used to dedup delivery across the
/// purchase stream and every `getAvailablePurchases()` sweep.
///
/// Android uses `id` (the Play order id, falling back to the purchase token) —
/// the same value the old plugin exposed as `PurchaseDetails.purchaseID`, so a
/// dedup set persisted by a pre-migration build stays meaningful after the
/// upgrade. iOS uses the StoreKit transaction id.
///
/// Returns null when nothing usable is present, which the caller must treat as
/// "cannot dedup" rather than as an identity of its own.
String? purchaseIdentity(Purchase purchase) {
  final id = switch (purchase) {
    PurchaseAndroid() => purchase.id,
    PurchaseIOS() => purchase.transactionId,
  };
  return id.trim().isEmpty ? null : id.trim();
}

/// The backend payload for [purchase], or null when it carries no token and
/// therefore cannot be verified at all.
BackendPurchasePayload? backendPayloadFor(Purchase purchase) {
  final token = purchase.purchaseToken;
  if (token == null || token.isEmpty) return null;

  return BackendPurchasePayload(
    productId: purchase.productId,
    purchaseToken: token,
    platform: switch (purchase) {
      PurchaseAndroid() => 'android',
      PurchaseIOS() => 'ios',
    },
  );
}

/// Whether [productId] is the one-time lifetime unlock rather than a
/// subscription.
///
/// Drives two separate things: which `fetchProducts` query the id belongs in,
/// and which `requestPurchase` shape to build.
bool isOneTimeProduct(String productId) =>
    productId.toLowerCase().contains('lifetime');

/// Nothing Pinpoint sells is consumable — subscriptions and the lifetime
/// unlock are both entitlements the user keeps. `finishTransaction` therefore
/// always acknowledges and never consumes; consuming the lifetime unlock would
/// let it be bought again.
bool isConsumableProduct(String productId) => false;

/// Picks the Google Play offer to purchase a subscription with.
///
/// Android rejects a subscription purchase that carries no offer token, so
/// this must find one. Preference order:
///
/// 1. an offer with a free-trial phase (a zero-priced, non-infinite phase) —
///    Play only returns offers the user is actually eligible for, so if one is
///    present this user gets the trial;
/// 2. the base plan (`id == basePlanIdAndroid`), i.e. the plain recurring price;
/// 3. whatever came first, so a purchase is still possible.
///
/// Returns null only when the product carries no offers at all, which is a
/// store-configuration problem the caller reports rather than crashes on.
SubscriptionOffer? selectAndroidOffer(List<SubscriptionOffer> offers) {
  final usable = offers.where((o) => (o.offerTokenAndroid ?? '').isNotEmpty);
  if (usable.isEmpty) return null;

  for (final offer in usable) {
    if (_freeTrialPhase(offer) != null) return offer;
  }
  for (final offer in usable) {
    if (offer.basePlanIdAndroid != null && offer.id == offer.basePlanIdAndroid) {
      return offer;
    }
  }
  return usable.first;
}

/// The recurring price to show for [product].
///
/// A subscription's own `displayPrice` can read as the *first* pricing phase,
/// which is "Free" whenever a trial leads — showing that as the plan's price
/// would be a straightforward lie about what the user is agreeing to pay. So
/// dig into the selected offer's phases and return the last PAID one, i.e. the
/// real recurring price. Falls back to `displayPrice` for one-time products
/// and for iOS, where no phase list exists.
String displayPriceFor(ProductCommon product) {
  if (product is ProductSubscriptionAndroid) {
    final offer = selectAndroidOffer(product.subscriptionOffers);
    final phases = offer?.pricingPhasesAndroid?.pricingPhaseList;
    if (phases != null) {
      final paid = phases.where((p) => _micros(p.priceAmountMicros) > 0);
      if (paid.isNotEmpty) return paid.last.formattedPrice;
    }
  }
  return product.displayPrice;
}

/// The free-trial length in days Google Play is offering on [product], or null
/// when this user gets no trial.
///
/// No eligibility call is needed on Android: Play omits an offer the user is
/// not entitled to, so an ineligible user simply has no free phase to find.
int? androidTrialDays(ProductSubscriptionAndroid product) {
  final offer = selectAndroidOffer(product.subscriptionOffers);
  if (offer == null) return null;
  final phase = _freeTrialPhase(offer);
  if (phase == null) return null;
  return daysInBillingPeriod(phase.billingPeriod);
}

/// The introductory free trial configured on an App Store subscription, or
/// null when there is none.
///
/// CONFIGURED, not granted: both stores grant a trial only to a user who has
/// not already used one in that subscription group, and StoreKit hands the
/// offer over regardless. The caller must confirm eligibility with
/// `isEligibleForIntroOfferIOS` before showing this to anyone — see
/// [iosTrialDaysIfEligible].
///
/// Filtering on both fields matters: `subscriptionOffers` carries promotional
/// and win-back offers too, and reading the list unfiltered would advertise a
/// merely discounted offer as a free trial.
int? iosConfiguredTrialDays(ProductSubscriptionIOS product) {
  final offers = product.subscriptionOffers;
  if (offers == null) return null;

  for (final offer in offers) {
    if (offer.type != DiscountOfferType.Introductory) continue;
    if (offer.paymentMode != PaymentMode.FreeTrial) continue;

    final period = offer.period;
    if (period == null) continue;

    final unitDays = switch (period.unit) {
      SubscriptionPeriodUnit.Day => 1,
      SubscriptionPeriodUnit.Week => 7,
      SubscriptionPeriodUnit.Month => 30,
      SubscriptionPeriodUnit.Year => 365,
      SubscriptionPeriodUnit.Unknown => 0,
    };

    final total = period.value * unitDays * (offer.periodCount ?? 1);
    if (total > 0) return total;
  }
  return null;
}

/// Combines [iosConfiguredTrialDays] with this user's actual entitlement.
///
/// Split out from the eligibility call itself so the arithmetic stays
/// testable: pass whether StoreKit says the user is eligible, get back what
/// the paywall may claim.
int? iosTrialDaysIfEligible(
  ProductSubscriptionIOS product, {
  required bool isEligible,
}) =>
    isEligible ? iosConfiguredTrialDays(product) : null;

/// Days in an ISO-8601 billing period as Play reports it (`P3D`, `P1W`, …).
///
/// Months and years are approximated; a trial is never expressed in them in
/// practice, and the value is only ever used for display.
int? daysInBillingPeriod(String? period) {
  if (period == null || period.isEmpty) return null;
  final match = RegExp(r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$')
      .firstMatch(period);
  if (match == null) return null;

  int part(int group) => int.tryParse(match.group(group) ?? '') ?? 0;
  final total = part(1) * 365 + part(2) * 30 + part(3) * 7 + part(4);
  return total > 0 ? total : null;
}

/// Normalises a store-supplied error into a lower-case, length-capped token
/// safe to put in an analytics parameter.
///
/// [PurchaseError.message] and `debugMessage` can carry Play's debug string or
/// an iOS `NSError.userInfo`, neither of which may leave the device, so only
/// the enum's own name is ever used.
String reasonCodeFor(ErrorCode? code) =>
    sanitizeReasonCode(code?.name);

/// Lower-cases and clamps an arbitrary store code. Never returns free text:
/// callers pass an enum name or a short code, and anything empty becomes
/// [PurchaseReasonCodes.unknown].
String sanitizeReasonCode(String? code) {
  if (code == null || code.trim().isEmpty) return PurchaseReasonCodes.unknown;
  final normalized = code.trim().toLowerCase();
  return normalized.length <= PurchaseReasonCodes.maxLength
      ? normalized
      : normalized.substring(0, PurchaseReasonCodes.maxLength);
}

/// Whether [code] means the user simply backed out of the billing sheet, which
/// is an ordinary outcome rather than a failure to report as an error.
bool isUserCancellation(ErrorCode? code) =>
    code == ErrorCode.UserCancelled;

/// The zero-priced, non-infinite pricing phase of [offer] — a free trial.
///
/// `recurrenceMode` 1 means the phase repeats forever; a free phase that never
/// ends is a free plan, not a trial, and must not be advertised as one.
PricingPhaseAndroid? _freeTrialPhase(SubscriptionOffer offer) {
  final phases = offer.pricingPhasesAndroid?.pricingPhaseList;
  if (phases == null) return null;

  for (final phase in phases) {
    if (_micros(phase.priceAmountMicros) != 0) continue;
    if (phase.recurrenceMode == 1) continue;
    final days = daysInBillingPeriod(phase.billingPeriod);
    if (days != null && days > 0) return phase;
  }
  return null;
}

/// `priceAmountMicros` is a String in the OpenIAP types, not a number.
int _micros(String raw) => int.tryParse(raw) ?? 0;
