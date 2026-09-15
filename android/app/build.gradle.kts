import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.pranta.pinpoint"
    // Pinned rather than tracking flutter.compileSdkVersion, which still
    // resolves to 36. permission_handler_android 13.0.0 publishes AAR metadata
    // requiring compileSdk 37, so the build fails at :app:checkDebugAarMetadata
    // without this.
    //
    // compileSdk only controls which APIs are available at compile time — it is
    // independent of targetSdk (below), which opts into new runtime behaviour
    // and is deliberately left on Flutter's value.
    compileSdk = 37
    // ndkVersion = flutter.ndkVersion
    ndkVersion = "29.0.13113456"

    compileOptions {
        // Flag to enable support for the new language APIs
        isCoreLibraryDesugaringEnabled = true
        // Sets Java compatibility to Java 17 (required for flutter_local_notifications)
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.pranta.pinpoint"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true // Required for Firebase dependencies

        // flutter_inapp_purchase ships one Android module per store
        // (play / horizon / amazon) as a product flavor. Without a choice the
        // build fails to resolve the dependency; Pinpoint sells through Google
        // Play only.
        missingDimensionStrategy("platform", "play")
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")

            // R8 on. Play Console measures "DEX code optimization" and warns
            // when obfuscation falls under 25% — with shrinking disabled it
            // read 2%, which it flags as a risk to visibility and publishing.
            //
            // Everything R8 would otherwise break is kept explicitly in
            // proguard-rules.pro: the GSON models flutter_local_notifications
            // rehydrates after a reboot, the billing classes Play reflects
            // over, and the plugin registrants Flutter resolves by name.
            isMinifyEnabled = true

            // Resource shrinking stays OFF, deliberately. It is a separate
            // switch from DEX optimization and does nothing for the warning
            // above, while it CAN strip a resource whose only reference is a
            // runtime string — notification icons are named that way
            // (`AndroidInitializationSettings('@mipmap/ic_launcher')`), as are
            // the launch drawables. Not worth the risk for a few hundred KB.
            isShrinkResources = false

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    implementation("androidx.window:window:1.3.0")
    // For Java-friendly APIs to register and unregister callbacks
    implementation("androidx.window:window-java:1.3.0")
    // For edge-to-edge support on Android 15+
    implementation("androidx.activity:activity-ktx:1.9.0")

    // On-device OCR (Latin script). Used by the native OCR MethodChannel in
    // MainActivity — replaces the google_mlkit_text_recognition Flutter plugin.
    implementation("com.google.mlkit:text-recognition:16.0.1")
}

flutter {
    source = "../.."
}
