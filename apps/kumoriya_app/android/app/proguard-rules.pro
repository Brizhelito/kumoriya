# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep media_kit classes
-keep class com.alexmercerind.** { *; }

# Keep workmanager
-keep class androidx.work.** { *; }

# Keep notification classes
-keep class com.dexterous.** { *; }

# Google Play Core (deferred components) - ignore missing classes
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
