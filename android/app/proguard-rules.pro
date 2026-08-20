# Flutter ProGuard & R8 rules for production release builds
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**
-dontwarn io.flutter.plugins.**

# App Main Activity & Generated Registrant (Narrowed for R8 obfuscation)
-keep class com.nightcode.luci.MainActivity { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Flutter Plugins (Future-proofed wildcard rules for any newly added pubspec plugins)
-keep class com.it_ne.flutter_secure_storage.** { *; }
-keep class androidx.security.crypto.** { *; }
-keep class dev.flutter.plugins.** { *; }
-keep class io.flutter.plugins.** { *; }

# Anti-Decompilation, Obfuscation & APK Parser Protection
-repackageclasses ''
-allowaccessmodification
-renamesourcefileattribute SourceFile
-keepattributes !SourceFile,!LineNumberTable,!LocalVariableTable,!LocalVariableTypeTable
-useuniqueclassmembernames

# Strip Debug Logging in Release Bytecode
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}