package com.neomovies.torrentengine.service

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.neomovies.torrentengine.TorrentEngine
import com.neomovies.torrentengine.models.TorrentState
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.collect

/**
 * Foreground service for torrent downloads
 * This service shows a persistent notification that cannot be dismissed while torrents are active
 */
class TorrentService : Service() {
    private val TAG = "TorrentService"
    
    private lateinit var torrentEngine: TorrentEngine
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "torrent_service_channel"
    private val CHANNEL_NAME = "Torrent Downloads"
    
    override fun onCreate() {
        super.onCreate()
        
        torrentEngine = TorrentEngine.getInstance(applicationContext)
        torrentEngine.startStatsUpdater()
        
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        
        // Start observing torrents for notification updates
        observeTorrents()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Service will restart if killed by system
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        // This service doesn't support binding
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }

    /**
     * Create notification channel for Android 8.0+
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows download progress for torrents"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * Observe torrents and update notification
     */
    private fun observeTorrents() {
        scope.launch {
            torrentEngine.getAllTorrentsFlow().collect { torrents ->
                val activeTorrents = torrents.filter { it.isActive() }
                
                if (activeTorrents.isEmpty()) {
                    // Stop service if no active torrents
                    stopSelf()
                } else {
                    // Update notification
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.notify(NOTIFICATION_ID, createNotification(activeTorrents.size, torrents))
                }
            }
        }
    }

    /**
     * Create or update notification
     */
    private fun createNotification(activeTorrentsCount: Int = 0, allTorrents: List<com.neomovies.torrentengine.models.TorrentInfo> = emptyList()): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true) // Cannot be dismissed
            .setContentIntent(pendingIntent)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        if (activeTorrentsCount == 0) {
            // Initial notification
            builder.setContentTitle("Torrent Service")
                .setContentText("Ready to download")
        } else {
            // Calculate total stats
            val downloadingTorrents = allTorrents.filter { it.state == TorrentState.DOWNLOADING }
            val totalDownloadSpeed = allTorrents.sumOf { it.downloadSpeed.toLong() }
            val totalUploadSpeed = allTorrents.sumOf { it.uploadSpeed.toLong() }
            
            val speedText = buildString {
                if (totalDownloadSpeed > 0) {
                    append("↓ ${formatSpeed(totalDownloadSpeed)}")
                }
                if (totalUploadSpeed > 0) {
                    if (isNotEmpty()) append(" ")
                    append("↑ ${formatSpeed(totalUploadSpeed)}")
                }
            }
            
            builder.setContentTitle("$activeTorrentsCount active torrent(s)")
                .setContentText(speedText)
            
            // Add big text style with details
            val bigText = buildString {
                if (downloadingTorrents.isNotEmpty()) {
                    appendLine("Downloading:")
                    downloadingTorrents.take(3).forEach { torrent ->
                        appendLine("• ${torrent.name}")
                        appendLine("  ${String.format("%.1f%%", torrent.progress * 100)} - ↓ ${formatSpeed(torrent.downloadSpeed.toLong())}")
                    }
                    if (downloadingTorrents.size > 3) {
                        appendLine("... and ${downloadingTorrents.size - 3} more")
                    }
                }
            }
            
            builder.setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            
            // Add action buttons
            addNotificationActions(builder)
        }

        return builder.build()
    }

    /**
     * Add action buttons to notification
     */
    private fun addNotificationActions(builder: NotificationCompat.Builder) {
        // Pause all button
        val pauseAllIntent = Intent(this, TorrentService::class.java).apply {
            action = ACTION_PAUSE_ALL
        }
        val pauseAllPendingIntent = PendingIntent.getService(
            this,
            1,
            pauseAllIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        builder.addAction(
            android.R.drawable.ic_media_pause,
            "Pause All",
            pauseAllPendingIntent
        )
    }

    /**
     * Format speed for display
     */
    private fun formatSpeed(bytesPerSecond: Long): String {
        return when {
            bytesPerSecond >= 1024 * 1024 -> String.format("%.1f MB/s", bytesPerSecond / (1024.0 * 1024.0))
            bytesPerSecond >= 1024 -> String.format("%.1f KB/s", bytesPerSecond / 1024.0)
            else -> "$bytesPerSecond B/s"
        }
    }

    companion object {
        const val ACTION_PAUSE_ALL = "com.neomovies.torrentengine.PAUSE_ALL"
        const val ACTION_RESUME_ALL = "com.neomovies.torrentengine.RESUME_ALL"
        const val ACTION_STOP_SERVICE = "com.neomovies.torrentengine.STOP_SERVICE"
    }
}
