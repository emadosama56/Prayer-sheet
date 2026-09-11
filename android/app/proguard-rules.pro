# flutter_local_notifications stores its pending schedule as JSON through Gson.
# Gson reads generic types at runtime via TypeToken, and R8 strips the generic
# signatures it needs, so the plugin could neither save nor read a schedule:
#
#   IllegalStateException: TypeToken must be created with a type argument
#     at FlutterLocalNotificationsPlugin.loadScheduledNotifications
#
# That is why no reminder ever arrived — nothing was ever stored to fire.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses, EnclosingMethod

-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Gson's own reflection machinery.
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
