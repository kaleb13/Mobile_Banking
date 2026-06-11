# Flutter-specific ProGuard rules
# Add any rules here that are necessary for your app to function correctly after obfuscation.

# Keep essential Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Sqflite
-keep class com.tekartik.sqflite.** { *; }

# Shared Preferences
-keep class com.russhwolf.settings.** { *; }

# Google Play Core (often referenced by Flutter but not always present)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.common.**

