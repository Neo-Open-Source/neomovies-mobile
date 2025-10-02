package com.neomovies.torrentengine.database

import androidx.room.*
import com.neomovies.torrentengine.models.TorrentInfo
import com.neomovies.torrentengine.models.TorrentState
import kotlinx.coroutines.flow.Flow

/**
 * Data Access Object for torrent operations
 */
@Dao
interface TorrentDao {
    /**
     * Get all torrents as Flow (reactive updates)
     */
    @Query("SELECT * FROM torrents ORDER BY addedDate DESC")
    fun getAllTorrentsFlow(): Flow<List<TorrentInfo>>

    /**
     * Get all torrents (one-time fetch)
     */
    @Query("SELECT * FROM torrents ORDER BY addedDate DESC")
    suspend fun getAllTorrents(): List<TorrentInfo>

    /**
     * Get torrent by info hash
     */
    @Query("SELECT * FROM torrents WHERE infoHash = :infoHash")
    suspend fun getTorrent(infoHash: String): TorrentInfo?

    /**
     * Get torrent by info hash as Flow
     */
    @Query("SELECT * FROM torrents WHERE infoHash = :infoHash")
    fun getTorrentFlow(infoHash: String): Flow<TorrentInfo?>

    /**
     * Get torrents by state
     */
    @Query("SELECT * FROM torrents WHERE state = :state ORDER BY addedDate DESC")
    suspend fun getTorrentsByState(state: TorrentState): List<TorrentInfo>

    /**
     * Get active torrents (downloading or seeding)
     */
    @Query("SELECT * FROM torrents WHERE state IN ('DOWNLOADING', 'SEEDING', 'METADATA_DOWNLOADING') ORDER BY addedDate DESC")
    suspend fun getActiveTorrents(): List<TorrentInfo>

    /**
     * Get active torrents as Flow
     */
    @Query("SELECT * FROM torrents WHERE state IN ('DOWNLOADING', 'SEEDING', 'METADATA_DOWNLOADING') ORDER BY addedDate DESC")
    fun getActiveTorrentsFlow(): Flow<List<TorrentInfo>>

    /**
     * Insert or update torrent
     */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTorrent(torrent: TorrentInfo)

    /**
     * Insert or update multiple torrents
     */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTorrents(torrents: List<TorrentInfo>)

    /**
     * Update torrent
     */
    @Update
    suspend fun updateTorrent(torrent: TorrentInfo)

    /**
     * Delete torrent
     */
    @Delete
    suspend fun deleteTorrent(torrent: TorrentInfo)

    /**
     * Delete torrent by info hash
     */
    @Query("DELETE FROM torrents WHERE infoHash = :infoHash")
    suspend fun deleteTorrentByHash(infoHash: String)

    /**
     * Delete all torrents
     */
    @Query("DELETE FROM torrents")
    suspend fun deleteAllTorrents()

    /**
     * Get total torrents count
     */
    @Query("SELECT COUNT(*) FROM torrents")
    suspend fun getTorrentsCount(): Int

    /**
     * Update torrent state
     */
    @Query("UPDATE torrents SET state = :state WHERE infoHash = :infoHash")
    suspend fun updateTorrentState(infoHash: String, state: TorrentState)

    /**
     * Update torrent progress
     */
    @Query("UPDATE torrents SET progress = :progress, downloadedSize = :downloadedSize WHERE infoHash = :infoHash")
    suspend fun updateTorrentProgress(infoHash: String, progress: Float, downloadedSize: Long)

    /**
     * Update torrent speeds
     */
    @Query("UPDATE torrents SET downloadSpeed = :downloadSpeed, uploadSpeed = :uploadSpeed WHERE infoHash = :infoHash")
    suspend fun updateTorrentSpeeds(infoHash: String, downloadSpeed: Int, uploadSpeed: Int)

    /**
     * Update torrent peers/seeds
     */
    @Query("UPDATE torrents SET numPeers = :numPeers, numSeeds = :numSeeds WHERE infoHash = :infoHash")
    suspend fun updateTorrentPeers(infoHash: String, numPeers: Int, numSeeds: Int)

    /**
     * Set torrent error
     */
    @Query("UPDATE torrents SET error = :error, state = 'ERROR' WHERE infoHash = :infoHash")
    suspend fun setTorrentError(infoHash: String, error: String)

    /**
     * Clear torrent error
     */
    @Query("UPDATE torrents SET error = NULL WHERE infoHash = :infoHash")
    suspend fun clearTorrentError(infoHash: String)
}
