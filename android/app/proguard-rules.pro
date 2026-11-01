# R8 / ProGuard rules for release builds.
#
# Minification is ON (see build.gradle.kts). Play Console measures "DEX code
# optimization" and flags an app whose obfuscation is under 25%; with R8 off it
# read 2%, which is a publishing-visibility risk, so the rules below exist to
# make shrinking safe rather than to work around it afterwards.
#
# Everything kept here is kept for ONE reason: something reaches it by name at
# runtime — reflection, JNI, or GSON — so R8 cannot see the reference and would
# rename or delete it. Anything that is only ever called from Kotlin/Java is
# deliberately NOT listed; keeping it would just put the percentage back down.

# ---- Crashlytics --------------------------------------------------------
# Without these a release stack trace loses the file and line, which is most of
# what makes a report actionable. The Crashlytics Gradle plugin uploads the R8
# mapping automatically, so names still deobfuscate in the console.
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Library-wide keeps (`-keep class com.google.firebase.** { *; }` and the like)
# used to sit here and left half the DEX unoptimized (r8.json: ~50% not
# optimized, obfuscated or shrunk), which Play flags under "R8 optimization".
# Firebase, Play Billing, GSON and androidx.window ship their own consumer
# rules inside their AARs; manifest components are kept by AAPT; plugin
# classes are referenced directly by GeneratedPluginRegistrant. Only what is
# reached purely by name is listed below.

# ---- Google Play Billing, via flutter_inapp_purchase (OpenIAP) ----------
# OpenIAP maps purchase objects reflectively (JSON into its own models).
-keep class dev.hyo.** { *; }
-keep class io.github.hyochan.** { *; }
-dontwarn dev.hyo.**
-dontwarn io.github.hyochan.**

# ---- flutter_local_notifications ---------------------------------------
# THE classic R8 breakage in a Flutter app. Scheduled notifications are
# persisted as GSON JSON and rehydrated after a reboot by reflecting over the
# plugin's model classes; obfuscate their field names and every already-
# scheduled reminder silently fails to come back. The models are all it needs.
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# GSON's generic type capture (TypeToken subclasses) and adapters.
-keep class * extends com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-dontwarn com.google.gson.**
-dontwarn sun.misc.**

# ---- Google Play Core (in_app_update, deferred components) --------------
# Flutter's embedding references split-install classes that are not on the
# classpath of an app that does not use deferred components. Warnings only —
# no keep is needed, but an unsuppressed warning fails the build.
-dontwarn com.google.android.play.core.**

# ---- Firebase ------------------------------------------------------------
# Kept by Firebase's own consumer rules and by the manifest entries AAPT keeps.
-dontwarn com.google.firebase.**

# ---- Kotlin --------------------------------------------------------------
# Coroutine internals are looked up reflectively by the debug agent and by
# kotlin.Metadata consumers.
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
-dontwarn kotlinx.coroutines.**
-keep class kotlin.Metadata { *; }

# ---- Plugins reached over the platform channel --------------------------
# GeneratedPluginRegistrant constructs every plugin directly, so R8 sees them;
# only the registrant itself is looked up by name.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# ---- Native / JNI --------------------------------------------------------
# sqlite3mc is loaded through FFI. R8 does not touch the .so, but the loader
# shim resolves its class by name.
-keep class com.tekartik.sqflite.** { *; }
-dontwarn org.sqlite.**

# ---- androidx.window -----------------------------------------------------
# Ships its own consumer rules (its sidecar/extension shims).
-dontwarn androidx.window.**

# ---- Enums ---------------------------------------------------------------
# values() / valueOf() are called reflectively by several of the above.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ---- Parcelables ---------------------------------------------------------
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
