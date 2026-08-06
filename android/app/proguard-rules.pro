# Flutter ProGuard & R8 rules for production release builds
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**
-dontwarn io.flutter.plugins.**

# App Main Activity & Generated Registrant
-keep class com.nightcode.luci.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Flutter Plugins
-keep class com.it_ne.flutter_secure_storage.** { *; }
-keep class androidx.security.crypto.** { *; }
-keep class dev.flutter.plugins.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class io.flutter.plugins.packageinfo.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class io.flutter.plugins.googlemobileads.** { *; }
-keep class io.flutter.plugins.inapppurchase.** { *; }

# Riverpod & State Management
-keep class flutter_riverpod.** { *; }

# Dio & HTTP Networking
-dontwarn dio.**
-dontwarn okhttp3.**
-dontwarn okio.**