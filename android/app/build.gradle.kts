import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nightcode.luci"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nightcode.luci"
        // You can update the following values to match your application needs.
        // Explicitly set minSdk = 21 (Android 5.0 Lollipop & up) so Google Play Store reflects Android 5.0+ compatibility
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "default"

    productFlavors {
        create("community") {
            dimension = "default"
            resValue("string", "app_name", "Yet Another LuCI App")
        }
        create("playstore") {
            dimension = "default"
            resValue("string", "app_name", "Yet Another LuCI App")
        }
    }

    signingConfigs {
        val storeFilePath = (keystoreProperties["storeFile"] as? String) ?: System.getenv("KEYSTORE_PATH")
        val storePass = (keystoreProperties["storePassword"] as? String) ?: System.getenv("KEYSTORE_PASSWORD")
        val alias = (keystoreProperties["keyAlias"] as? String) ?: System.getenv("KEY_ALIAS")
        val keyPass = (keystoreProperties["keyPassword"] as? String) ?: System.getenv("KEY_PASSWORD")

        if (!storeFilePath.isNullOrEmpty() && !storePass.isNullOrEmpty() && !alias.isNullOrEmpty() && !keyPass.isNullOrEmpty()) {
            create("release") {
                storeFile = file(storeFilePath)
                storePassword = storePass
                keyAlias = alias
                keyPassword = keyPass
            }
        }
    }

    buildTypes {
        getByName("release") {
            val releaseSigning = signingConfigs.findByName("release")
            if (releaseSigning != null) {
                signingConfig = releaseSigning
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            // Debug builds use the default debug signing config
        }
    }

    dependenciesInfo {
        // Disables dependency metadata when building APKs (for IzzyOnDroid/F-Droid)
        includeInApk = false
        // Disables dependency metadata when building Android App Bundles (for Google Play)
        includeInBundle = false
    }

    bundle {
        language {
            enableSplit = true
        }
        density {
            enableSplit = true
        }
        abi {
            enableSplit = true
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/license.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/notice.txt",
                "META-INF/ASL2.0",
                "META-INF/*.kotlin_module"
            )
        }
    }
}

// Exclude unused ad SDK entirely from all builds.
// in_app_purchase_android MUST be present in the AAB so Google Play's SDK scanner
// sees BillingClient 8.0.0 and clears the policy violation.
// The Dart-side isMonetizationEnabled flag gates all IAP calls at runtime.
configurations.all {
    exclude(group = "io.flutter.plugins.googlemobileads")
    exclude(module = "google_mobile_ads")
}

// Ensure GeneratedPluginRegistrant does not reference excluded ad plugin when compiling
tasks.configureEach {
    if (name.contains("JavaWithJavac")) {
        doFirst {
            val registrantFile = file("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
            if (registrantFile.exists()) {
                val cleanedContent = registrantFile.readText()
                    .lines()
                    .filter { line ->
                        !line.contains("GoogleMobileAdsPlugin")
                    }
                    .joinToString("\n")
                registrantFile.writeText(cleanedContent)
            }
        }
    }
}

dependencies {
    implementation("androidx.core:core:1.12.0")
    implementation("androidx.activity:activity:1.8.2")
}

flutter {
    source = "../.."
}
