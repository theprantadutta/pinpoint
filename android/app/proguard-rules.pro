# Google Play Billing, via flutter_inapp_purchase (OpenIAP).
#
# The billing client and the OpenIAP modules are reached reflectively from the
# Play Services side, so R8 cannot see the references and would strip them.
# Only consulted when isMinifyEnabled is true (see build.gradle.kts).
-keep class dev.hyo.** { *; }
-keep class io.github.hyochan.** { *; }
-keep class com.android.vending.billing.**
-keep class com.android.billingclient.** { *; }
-dontwarn dev.hyo.**
-dontwarn io.github.hyochan.**
