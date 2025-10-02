package com.neomovies.torrentengine.database

import androidx.room.TypeConverter
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.neomovies.torrentengine.models.TorrentFile
import com.neomovies.torrentengine.models.TorrentState

/**
 * Type converters for Room database
 */
class Converters {
    private val gson = Gson()

    @TypeConverter
    fun fromTorrentState(value: TorrentState): String = value.name

    @TypeConverter
    fun toTorrentState(value: String): TorrentState = TorrentState.valueOf(value)

    @TypeConverter
    fun fromTorrentFileList(value: List<TorrentFile>): String = gson.toJson(value)

    @TypeConverter
    fun toTorrentFileList(value: String): List<TorrentFile> {
        val listType = object : TypeToken<List<TorrentFile>>() {}.type
        return gson.fromJson(value, listType)
    }

    @TypeConverter
    fun fromStringList(value: List<String>): String = gson.toJson(value)

    @TypeConverter
    fun toStringList(value: String): List<String> {
        val listType = object : TypeToken<List<String>>() {}.type
        return gson.fromJson(value, listType)
    }
}
