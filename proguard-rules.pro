# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Google Play Core classes
-keep class com.google.android.play.core.** { *; }

# Keep your model classes
-keep class com.gc9798.sleepApp.models.** { *; }

# Keep your service classes
-keep class com.gc9798.sleepApp.services.** { *; }

# Keep your database classes
-keep class com.gc9798.sleepApp.database.** { *; }

# Keep your audio related classes
-keep class com.gc9798.sleepApp.audio.** { *; }
-keep class com.gc9798.sleepApp.recorder.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelables
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# Keep Serializable classes
-keepnames class * implements java.io.Serializable

# Keep R classes
-keep class **.R$* {
    *;
}

# Keep custom application class
-keep class com.gc9798.sleepApp.SleepApp { *; }

# Keep crash reporting
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep background service
-keep class com.gc9798.sleepApp.services.RecordingService { *; }
-keep class com.gc9798.sleepApp.services.BackgroundService { *; }

# Keep breath analysis
-keep class com.gc9798.sleepApp.analysis.BreathAnalyzer { *; }
-keep class com.gc9798.sleepApp.analysis.BreathPattern { *; }

# Keep audio processing
-keep class com.gc9798.sleepApp.audio.AudioProcessor { *; }
-keep class com.gc9798.sleepApp.audio.AudioBuffer { *; }

# Keep database helpers
-keep class com.gc9798.sleepApp.database.DatabaseHelper { *; }
-keep class com.gc9798.sleepApp.database.SleepRecord { *; } 