# SriEdu R8 rules (release builds only).
#
# Everything here exists because a plugin reflects over a class that R8 would
# otherwise strip. Each block names the plugin that needs it, so removing a
# dependency lets you delete the matching rule.

# ---------------------------------------------------------------- pdfrx / PDFium
# pdfrx binds to native code by name; obfuscating these breaks the reader at
# runtime (a blank grey page).
-keep class io.legado.** { *; }
-keep class com.pdfrx.** { *; }
-keepclassmembers class * {
    native <methods>;
}
# Some builds ship a WebView-based fallback renderer.
-keep class android.webkit.** { *; }

# ------------------------------------------------------------- google_mobile_ads
# The SDK reflects over its own callback interfaces and has its own consumer rules,
# but the mediation adapters need this.
-keep class com.google.android.gms.ads.** { *; }
-keep interface com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# ------------------------------------------------------------------- Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# --------------------------------------------- flutter_local_notifications / tz
# The timezone database is loaded by reflection from a compressed resource.
-keep class org.threeten.bp.** { *; }
-keep class net.dmulloy2.** { *; }
-keep class com.google.gson.** { *; }
-dontwarn org.threeten.**
-keepclassmembers class * extends com.google.gson.TypeAdapter { *; }
-keep class * implements com.google.gson.TypeAdapterFactory

# --------------------------------------------------------------- plugins / misc
# Flutter embedding + plugin registration.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
# url_launcher / package_info_plus / path_provider are pure platform channels.
-keep class dev.fluttercommunity.** { *; }
-keep class com.fluttercandies.** { *; }

# ------------------------------------------------- annotation / kotlin metadata
# R8 in "optimize" mode can strip annotations the plugins read at runtime.
-keepattributes *Annotation*, Signature, Exception, InnerClasses, EnclosingMethod
-keepclassmembers class kotlin.Metadata { public <methods>; }

# --------------------------------------------------------------------- logging
# Strip debug logs from release builds (also a small privacy win).
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Keep line numbers so Crashlytics stack traces stay readable. Pair this with
# uploading the mapping file (firebaseCrashlytics { mappingFileUploadEnabled true }
# is on by default when the Crashlytics Gradle plugin is applied).
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
