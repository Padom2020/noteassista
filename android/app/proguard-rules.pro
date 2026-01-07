# ML Kit Text Recognition - Keep language-specific recognizer options
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }

# Keep all ML Kit classes
-keep class com.google.mlkit.** { *; }

# Keep Firebase ML Kit
-keep class com.google.firebase.ml.** { *; }

# Keep Google Play Services
-keep class com.google.android.gms.** { *; }

# Keep Flutter plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Supabase
-keep class io.supabase.** { *; }

# Keep Dart/Flutter generated code
-keep class com.google_mlkit_text_recognition.** { *; }

# Preserve line numbers for debugging
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
