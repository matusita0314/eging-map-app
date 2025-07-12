# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# 🔥 Google Maps最適化
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }
-keep class com.google.android.gms.location.** { *; }
-keep interface com.google.android.gms.location.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# 🔥 Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# 🔥 Firebase最適化
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# 🔥 Flutter最適化
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# 🔥 位置情報サービス
-keep class com.google.android.gms.location.** { *; }
-keep class com.google.android.gms.maps.model.** { *; }

# 🔥 フレーム関連クラス保持
-keep class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
    public void set*(...);
}

# 🔥 Texture/Surface関連最適化
-keep class android.graphics.** { *; }
-keep class android.opengl.** { *; }
-keep class android.view.Surface** { *; }
-keep class android.view.TextureView** { *; }

# 🔥 ログ最適化（リリース時はログを削除）
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# 🔥 アノテーション保持
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# 🔥 メモリ最適化
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# 🔥 パフォーマンス最適化
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-dontpreverify
-verbose
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*

# 🔥 R8最適化
-allowaccessmodification
-repackageclasses