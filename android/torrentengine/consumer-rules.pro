# Consumer ProGuard rules for torrentengine library

# Keep LibTorrent4j
-keep class org.libtorrent4j.** { *; }

# Keep public API
-keep public class com.neomovies.torrentengine.TorrentEngine {
    public *;
}

-keep class com.neomovies.torrentengine.models.** { *; }
-keep class com.neomovies.torrentengine.service.TorrentService { *; }
