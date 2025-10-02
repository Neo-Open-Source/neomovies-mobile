package com.neomovies.torrentengine.database

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import com.neomovies.torrentengine.models.TorrentInfo

/**
 * Room database for torrent persistence
 */
@Database(
    entities = [TorrentInfo::class],
    version = 1,
    exportSchema = false
)
@TypeConverters(Converters::class)
abstract class TorrentDatabase : RoomDatabase() {
    abstract fun torrentDao(): TorrentDao

    companion object {
        @Volatile
        private var INSTANCE: TorrentDatabase? = null

        fun getDatabase(context: Context): TorrentDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    TorrentDatabase::class.java,
                    "torrent_database"
                )
                    .fallbackToDestructiveMigration()
                    .build()
                INSTANCE = instance
                instance
            }
        }
    }
}
