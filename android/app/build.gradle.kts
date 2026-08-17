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
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nightcode.luci"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
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
}

// Exclude monetization/ad dependencies entirely from the community flavor builds
configurations.matching { it.name.startsWith("community") }.configureEach {
    exclude(group = "io.flutter.plugins.googlemobileads")
    exclude(group = "io.flutter.plugins.inapppurchase")
    exclude(module = "google_mobile_ads")
    exclude(module = "in_app_purchase_android")
}

// Ensure GeneratedPluginRegistrant does not reference excluded ad/purchase plugins when compiling community flavor
tasks.configureEach {
    if (name.contains("Community", ignoreCase = true) && name.contains("JavaWithJavac")) {
        doFirst {
            val registrantFile = file("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
            if (registrantFile.exists()) {
                val cleanedContent = registrantFile.readText()
                    .lines()
                    .filter { line ->
                        !line.contains("GoogleMobileAdsPlugin") && !line.contains("InAppPurchasePlugin")
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
