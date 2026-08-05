# Flutter ProGuard rules for production
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**
-dontwarn io.flutter.plugins.**

# Flutter Secure Storage & Crypto
-keep class com.it_ne.flutter_secure_storage.** { *; }
-keep class androidx.security.crypto.** { *; }

# Dio & HTTP
-keep class com.flutter_channel.** { *; }
-dontwarn dio.**

# Path Provider & Package Info
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class io.flutter.plugins.packageinfo.** { *; } 