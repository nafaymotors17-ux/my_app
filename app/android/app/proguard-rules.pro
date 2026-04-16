# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }

# Keep app and plugin entry points
-keep class com.example.my_app.** { *; }

# Google Sign-In / Gmail (release R8)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-dontwarn com.google.android.gms.**
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
