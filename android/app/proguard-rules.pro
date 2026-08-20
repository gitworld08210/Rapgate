# =============================================================================
# R8 / ProGuard keep rules for HealthPush
#
# R8 is enabled in release builds to cut APK size. These rules protect the
# things R8 cannot see statically: reflection-based libraries (ML Kit, Firebase)
# and classes referenced only from AndroidManifest.xml or a Platform Channel.
#
# Symptom of a missing rule here is a release-only crash (ClassNotFoundException
# / NoSuchMethodError) that does not reproduce in debug.
# =============================================================================

# ---------------------------- Flutter ----------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ---------------------------- Our own code ----------------------------
# Referenced from AndroidManifest.xml and via MethodChannel/EventChannel,
# so there is no static call path for R8 to follow.
-keep class com.healthpush.app.MainActivity { *; }
-keep class com.healthpush.app.services.** { *; }
-keep class com.healthpush.app.receivers.** { *; }

# Accessibility services are instantiated by the framework by name.
-keep class * extends android.accessibilityservice.AccessibilityService { *; }
-keep class * extends android.content.BroadcastReceiver { *; }
-keep class * extends android.app.Service { *; }

# ---------------------------- ML Kit (pose detection) ----------------------------
# ML Kit loads model/pipeline classes reflectively; stripping them breaks
# push-up verification at runtime only in release builds.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep interface com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ML Kit declares optional deps that may not be present.
-dontwarn com.google.android.gms.internal.**

# ---------------------------- Firebase / Play Services ----------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore serialises model classes via reflection.
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.PropertyName <methods>;
}

# Firebase Auth / Messaging entry points.
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.messaging.** { *; }

# ---------------------------- Kotlin ----------------------------
-keep class kotlin.Metadata { *; }
-keepclassmembers class **$WhenMappings { <fields>; }
-keepclassmembers class kotlin.Metadata { public <methods>; }
-dontwarn kotlin.**

# Coroutines (used for the background app-list query).
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**

# ---------------------------- Camera / image ----------------------------
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# ---------------------------- Misc ----------------------------
# Keep annotations (used by several of the above).
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep native method bindings.
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enum internals — R8 can otherwise break valueOf()/values().
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Parcelables.
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Desugaring support library.
-dontwarn java.lang.invoke.**
-dontwarn **$$Lambda$*

# Silence warnings for optional/absent classes referenced by dependencies.
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
