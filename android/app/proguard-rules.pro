# Flutter-specific ProGuard rules
# Add any rules here that are necessary for your app to function correctly after obfuscation.

# Keep essential Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }

# Sqflite
-keep class com.tekartik.sqflite.** { *; }

# Shared Preferences
-keep class com.russhwolf.settings.** { *; }

# Google Play Core (often referenced by Flutter but not always present)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.common.**

# Native Kotlin components (BroadcastReceivers, QuickEditActivity, Parsers, Registries)
-keep class com.example.mobile_banking_app.** { *; }
-keepclassmembers class com.example.mobile_banking_app.** { *; }
-keep class com.shibre.app.** { *; }
-keepclassmembers class com.shibre.app.** { *; }

# Google Sign-In & Android Credential Manager
-keep class androidx.credentials.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
-dontwarn androidx.credentials.**

