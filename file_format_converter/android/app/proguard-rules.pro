# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Hive
-keep class io.hivedb.** { *; }
-keep @io.hivedb.annotations.** class * { *; }

# Keep all HiveObject subclasses (ConversionRecord etc.)
-keep class ** extends io.hivedb.HiveObject { *; }
-keepclassmembers class ** extends io.hivedb.HiveObject { *; }
# Also keep TypeAdapters registered via Hive.registerAdapter
-keep class ** implements com.hivedb.HiveObjectMixin { *; }

# pdfx / pdf rendering native bridge
-keep class com.pdfx.** { *; }
-dontwarn com.pdfx.**

# file_picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# share_plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# open_filex
-keep class com.crazecoder.openfile.** { *; }

# Google ML Kit OCR
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_vision_text_common.**

# General
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
