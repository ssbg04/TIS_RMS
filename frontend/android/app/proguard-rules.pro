# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Prevent obfuscation warnings for Flutter embedding
-dontwarn io.flutter.embedding.**

# Firebase
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }

# Google ML Kit Document Scanner & Vision
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.tasks.** { *; }

# Preserve Annotations & Reflection Metadata
-keepattributes *Annotation*,EnclosingMethod,Signature,InnerClasses

# Preserve JNI Native Methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve Flutter Services and Receivers
-keep class * implements io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback { *; }
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
