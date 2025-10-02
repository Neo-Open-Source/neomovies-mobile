# Add project specific ProGuard rules here.
# Keep LibTorrent4j classes
-keep class org.libtorrent4j.** { *; }
-keepclassmembers class org.libtorrent4j.** { *; }

# Keep TorrentEngine public API
-keep public class com.neomovies.torrentengine.TorrentEngine {
    public *;
}

# Keep models
-keep class com.neomovies.torrentengine.models.** { *; }

# Keep Room database classes
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class *
-dontwarn androidx.room.paging.**

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
