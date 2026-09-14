import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/services/purchases/purchase_mapping.dart';

import '../support/fake_iap_client.dart';

/// The decisions in the OpenIAP flow that cost real money, tested where they
/// are pure: which offer gets bought, what reaches the backend, what may
/// appear in an analytics parameter, and what the paywall is allowed to claim
/// about a free trial.
void main() {
  group('purchaseIdentity', () {
    test('Android uses the order id', () {
      final purchase = fakePurchase(productId: 'p', purchaseId: 'GPA.1234');
      expect(purchaseIdentity(purchase), 'GPA.1234');
    });

    test('iOS uses the StoreKit transaction id', () {
      final purchase =
          fakeIosPurchase(productId: 'p', transactionId: '2000000123');
      expect(purchaseIdentity(purchase), '2000000123');
    });

    test('an empty id is null, not an identity of its own', () {
      // Play leaves the order id blank while a purchase is pending. Treating
      // '' as an identity would make every tokenless purchase look like the
      // same already-delivered one.
      final purchase = fakePurchase(productId: 'p', purchaseId: '   ');
      expect(purchaseIdentity(purchase), isNull);
    });
  });

  group('backendPayloadFor', () {
    test('sends the Play purchase token as android', () {
      final payload = backendPayloadFor(
        fakePurchase(productId: 'monthly', purchaseToken: 'play-token'),
      );

      expect(payload, isNotNull);
      expect(payload!.platform, 'android');
      expect(payload.purchaseToken, 'play-token');
      expect(payload.productId, 'monthly');
    });

    test('sends the StoreKit JWS as ios', () {
      // The backend's AppleStoreService verifies a StoreKit 2 signed
      // transaction, so this field must carry the JWS and not a receipt.
      final payload = backendPayloadFor(
        fakeIosPurchase(productId: 'yearly', purchaseToken: 'header.body.sig'),
      );

      expect(payload!.platform, 'ios');
      expect(payload.purchaseToken, 'header.body.sig');
    });

    test('a purchase with no token yields nothing to verify', () {
      expect(
        backendPayloadFor(fakePurchase(productId: 'p', purchaseToken: null)),
        isNull,
      );
      expect(
        backendPayloadFor(fakePurchase(productId: 'p', purchaseToken: '')),
        isNull,
      );
    });
  });

  group('product classification', () {
    test('the lifetime unlock is one-time, the plans are not', () {
      expect(isOneTimeProduct('pinpoint_premium_lifetime'), isTrue);
      expect(isOneTimeProduct('pinpoint_premium_monthly'), isFalse);
      expect(isOneTimeProduct('pinpoint_premium_yearly'), isFalse);
    });

    test('nothing Pinpoint sells is consumable', () {
      // Consuming the lifetime unlock would put it back on sale; consuming a
      // subscription is meaningless. finishTransaction must only acknowledge.
      for (final id in [
        'pinpoint_premium_monthly',
        'pinpoint_premium_yearly',
        'pinpoint_premium_lifetime',
      ]) {
        expect(isConsumableProduct(id), isFalse);
      }
    });
  });

  group('selectAndroidOffer', () {
    test('prefers an offer carrying a free trial', () {
      final base = fakeOffer(
        id: 'base',
        basePlanId: 'base',
        offerToken: 'base-token',
        phases: [fakePricingPhase()],
      );
      final trial = fakeOffer(
        id: 'freetrial',
        basePlanId: 'base',
        offerToken: 'trial-token',
        phases: [fakeTrialPhase(), fakePricingPhase()],
      );

      // Play only returns offers this user is eligible for, so when a trial
      // offer is present it is the one they should get.
      expect(selectAndroidOffer([base, trial])?.offerTokenAndroid,
          'trial-token');
    });

    test('falls back to the base plan when there is no trial', () {
      final promo = fakeOffer(
        id: 'winback',
        basePlanId: 'base',
        offerToken: 'promo-token',
        phases: [fakePricingPhase()],
      );
      final base = fakeOffer(
        id: 'base',
        basePlanId: 'base',
        offerToken: 'base-token',
        phases: [fakePricingPhase()],
      );

      expect(selectAndroidOffer([promo, base])?.offerTokenAndroid,
          'base-token');
    });

    test('falls back to the first offer rather than giving up', () {
      final first = fakeOffer(id: 'a', offerToken: 'a-token');
      final second = fakeOffer(id: 'b', offerToken: 'b-token');

      expect(selectAndroidOffer([first, second])?.offerTokenAndroid, 'a-token');
    });

    test('an offer with no token is unusable', () {
      // Android rejects a subscription purchase submitted without an offer
      // token, so a tokenless offer is worse than no offer at all.
      expect(selectAndroidOffer([fakeOffer(id: 'a', offerToken: null)]), isNull);
      expect(selectAndroidOffer([fakeOffer(id: 'a', offerToken: '')]), isNull);
      expect(selectAndroidOffer(const []), isNull);
    });
  });

  group('displayPriceFor', () {
    test('shows the recurring price, not the leading free phase', () {
      // THE trap: a subscription's own displayPrice reads as the first pricing
      // phase, which is "Free" whenever a trial leads. Showing that as the
      // plan's price misstates what the user is agreeing to pay.
      final product = fakeSubscriptionProduct(
        'monthly',
        displayPrice: 'Free',
        offers: [
          fakeOffer(
            id: 'trial',
            basePlanId: 'base',
            phases: [
              fakeTrialPhase(),
              fakePricingPhase(formattedPrice: r'$4.99'),
            ],
          ),
        ],
      );

      expect(displayPriceFor(product), r'$4.99');
    });

    test('uses the last paid phase when an intro price precedes the full one',
        () {
      final product = fakeSubscriptionProduct(
        'yearly',
        offers: [
          fakeOffer(
            id: 'intro',
            basePlanId: 'base',
            phases: [
              fakePricingPhase(
                  formattedPrice: r'$19.99', priceAmountMicros: '19990000'),
              fakePricingPhase(
                  formattedPrice: r'$39.99', priceAmountMicros: '39990000'),
            ],
          ),
        ],
      );

      expect(displayPriceFor(product), r'$39.99');
    });

    test('falls back to displayPrice with no phase information', () {
      expect(displayPriceFor(fakeOneTimeProduct('lifetime')), r'$29.99');
      expect(
        displayPriceFor(fakeSubscriptionProduct(
          'monthly',
          displayPrice: r'$9.99',
          offers: [fakeOffer(id: 'base')],
        )),
        r'$9.99',
      );
    });
  });

  group('androidTrialDays', () {
    test('reads the length of the zero-priced phase', () {
      final product = fakeSubscriptionProduct(
        'monthly',
        offers: [
          fakeOffer(
            id: 'trial',
            basePlanId: 'base',
            phases: [fakeTrialPhase(billingPeriod: 'P7D'), fakePricingPhase()],
          ),
        ],
      );

      expect(androidTrialDays(product), 7);
    });

    test('no free phase means no trial for this user', () {
      // Play omits an offer the user is not entitled to, so an ineligible
      // user simply has no free phase to find — no eligibility call needed.
      final product = fakeSubscriptionProduct(
        'monthly',
        offers: [
          fakeOffer(id: 'base', basePlanId: 'base', phases: [fakePricingPhase()])
        ],
      );

      expect(androidTrialDays(product), isNull);
    });

    test('a free phase that never ends is a free plan, not a trial', () {
      // recurrenceMode 1 is "repeats forever". Advertising it as an N-day
      // trial would be wrong in both directions.
      final product = fakeSubscriptionProduct(
        'monthly',
        offers: [
          fakeOffer(
            id: 'free-forever',
            phases: [
              fakePricingPhase(
                billingPeriod: 'P1M',
                priceAmountMicros: '0',
                recurrenceMode: 1,
              ),
            ],
          ),
        ],
      );

      expect(androidTrialDays(product), isNull);
    });
  });

  group('iOS trial resolution', () {
    ProductSubscriptionIOS iosProduct({
      required List<SubscriptionOffer> offers,
    }) =>
        ProductSubscriptionIOS(
          currency: 'USD',
          description: 'Premium',
          displayNameIOS: 'Premium',
          displayPrice: r'$4.99',
          id: 'pinpoint_premium_monthly',
          introductoryPricePaymentModeIOS: PaymentModeIOS.FreeTrial,
          isFamilyShareableIOS: false,
          jsonRepresentationIOS: '{}',
          title: 'Premium',
          typeIOS: ProductTypeIOS.AutoRenewableSubscription,
          subscriptionGroupIdIOS: 'group-1',
          subscriptionOffers: offers,
        );

    SubscriptionOffer introTrial({
      SubscriptionPeriodUnit unit = SubscriptionPeriodUnit.Week,
      int value = 1,
      int periodCount = 1,
    }) =>
        fakeOffer(
          id: 'intro',
          type: DiscountOfferType.Introductory,
          paymentMode: PaymentMode.FreeTrial,
          period: SubscriptionPeriod(unit: unit, value: value),
          periodCount: periodCount,
        );

    test('converts the offer period into days', () {
      expect(iosConfiguredTrialDays(iosProduct(offers: [introTrial()])), 7);
      expect(
        iosConfiguredTrialDays(iosProduct(
            offers: [introTrial(unit: SubscriptionPeriodUnit.Day, value: 3)])),
        3,
      );
      expect(
        iosConfiguredTrialDays(iosProduct(offers: [
          introTrial(unit: SubscriptionPeriodUnit.Month, value: 1)
        ])),
        30,
      );
    });

    test('multiplies by periodCount', () {
      expect(
        iosConfiguredTrialDays(iosProduct(
            offers: [introTrial(periodCount: 2)])),
        14,
      );
    });

    test('ignores a promotional offer', () {
      // subscriptionOffers carries promotional and win-back offers too.
      // Reading it unfiltered would advertise a merely discounted offer as a
      // free trial.
      final promo = fakeOffer(
        id: 'promo',
        type: DiscountOfferType.Promotional,
        paymentMode: PaymentMode.FreeTrial,
        period: const SubscriptionPeriod(
            unit: SubscriptionPeriodUnit.Month, value: 1),
        periodCount: 1,
      );

      expect(iosConfiguredTrialDays(iosProduct(offers: [promo])), isNull);
    });

    test('ignores an introductory offer that is a discount, not a trial', () {
      final payUpFront = fakeOffer(
        id: 'intro',
        type: DiscountOfferType.Introductory,
        paymentMode: PaymentMode.PayUpFront,
        period: const SubscriptionPeriod(
            unit: SubscriptionPeriodUnit.Month, value: 1),
        periodCount: 1,
      );

      expect(iosConfiguredTrialDays(iosProduct(offers: [payUpFront])), isNull);
    });

    test('an ineligible user is promised nothing', () {
      // The decisive one. StoreKit returns the offer whether or not this user
      // can have it, so a configured trial must be gated on eligibility —
      // otherwise a returning subscriber is shown "7 days free" and charged
      // immediately.
      final product = iosProduct(offers: [introTrial()]);

      expect(iosTrialDaysIfEligible(product, isEligible: true), 7);
      expect(iosTrialDaysIfEligible(product, isEligible: false), isNull);
    });
  });

  group('daysInBillingPeriod', () {
    test('parses the ISO-8601 periods Play emits', () {
      expect(daysInBillingPeriod('P3D'), 3);
      expect(daysInBillingPeriod('P1W'), 7);
      expect(daysInBillingPeriod('P1M'), 30);
      expect(daysInBillingPeriod('P1Y'), 365);
      expect(daysInBillingPeriod('P1M15D'), 45);
    });

    test('rejects nonsense rather than guessing', () {
      expect(daysInBillingPeriod(null), isNull);
      expect(daysInBillingPeriod(''), isNull);
      expect(daysInBillingPeriod('3 days'), isNull);
      expect(daysInBillingPeriod('P0D'), isNull);
    });
  });

  group('analytics reason codes', () {
    test('reduce a store error to its enum name', () {
      expect(reasonCodeFor(ErrorCode.UserCancelled), 'usercancelled');
      expect(reasonCodeFor(ErrorCode.NetworkError), 'networkerror');
    });

    test('a null code becomes unknown', () {
      // PurchaseError.code is nullable in the shipped plugin.
      expect(reasonCodeFor(null), PurchaseReasonCodes.unknown);
      expect(sanitizeReasonCode(null), PurchaseReasonCodes.unknown);
      expect(sanitizeReasonCode('   '), PurchaseReasonCodes.unknown);
    });

    test('an absurdly long code is lower-cased and clamped', () {
      final code = sanitizeReasonCode('X' * 500);
      expect(code, hasLength(PurchaseReasonCodes.maxLength));
      expect(code, equals('x' * PurchaseReasonCodes.maxLength));
    });

    test('cancellation is recognised, and nothing else is', () {
      expect(isUserCancellation(ErrorCode.UserCancelled), isTrue);
      expect(isUserCancellation(ErrorCode.NetworkError), isFalse);
      expect(isUserCancellation(null), isFalse);
    });
  });
}
