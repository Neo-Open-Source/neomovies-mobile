import Foundation
import AVFoundation

/// Manages asset loading for AVPlayer
final class CollapsAVAssetLoader {
    
    // MARK: - Dependencies
    private weak var player: AVPlayer?
    private weak var playlistManager: CollapsAVPlaylistManager?
    private weak var audioManager: CollapsAVAudioManager?
    private weak var allohaManager: CollapsAVAllohaManager?
    private weak var progressManager: CollapsAVProgressManager?
    
    // MARK: - State
    private var currentBridge: CollapsAVAssetBridge?
    private var playbackProxy: AllohaHLSProxyServer?
    private var kpId: Int?
    
    // MARK: - Callbacks
    var onProxyFailure: ((CollapsAVPlaylistItem) -> Void)?
    var onAssetLoaded: (() -> Void)?
    
    // MARK: - Initialization
    init(
        player: AVPlayer,
        playlistManager: CollapsAVPlaylistManager,
        audioManager: CollapsAVAudioManager,
        allohaManager: CollapsAVAllohaManager,
        progressManager: CollapsAVProgressManager
    ) {
        self.player = player
        self.playlistManager = playlistManager
        self.audioManager = audioManager
        self.allohaManager = allohaManager
        self.progressManager = progressManager
    }
    
    // MARK: - Public API
    
    func setKinopoiskId(_ id: Int) {
        kpId = id
    }
    
    func loadCurrentItem(
        autoplay: Bool,
        overrideStartSec: Double?,
        overrideUrlString: String? = nil
    ) async throws {
        guard let itemMeta = playlistManager?.currentItem else {
            throw NSError(domain: "NeomoviesCore", code: 1003, userInfo: [NSLocalizedDescriptionKey: "No current episode"])
        }
        
        let resolvedItem = try await allohaManager?.resolveAllohaItemIfNeeded(itemMeta) ?? itemMeta
        let selectedVariantIndex = audioManager?.selectedAudioVariantIndexByMediaId[resolvedItem.mediaId] ?? 0
        let resolvedUrlString: String
        if let overrideUrlString, !overrideUrlString.isEmpty {
            resolvedUrlString = overrideUrlString
        } else if !resolvedItem.audioVariants.isEmpty,
                  resolvedItem.audioVariants.indices.contains(selectedVariantIndex) {
            resolvedUrlString = resolvedItem.audioVariants[selectedVariantIndex].url
        } else {
            resolvedUrlString = resolvedItem.url
        }

        guard let url = URL(string: resolvedUrlString) else {
            throw URLError(.badURL)
        }

        stopProxy()
        
        let playerItem = try createPlayerItem(url: url, itemMeta: resolvedItem)
        player?.replaceCurrentItem(with: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true
        player?.isMuted = false

        restorePlaybackPosition(itemMeta: resolvedItem, overrideStartSec: overrideStartSec)
        
        if autoplay {
            player?.play()
        }

        if let kpId = kpId {
            CollapsPlaybackProgressStore.shared.saveLastPlayed(kpId: kpId, season: resolvedItem.season, episode: resolvedItem.episode)
        }
        
        onAssetLoaded?()
    }
    
    @MainActor
    func loadCurrentItemAsync(
        autoplay: Bool,
        overrideStartSec: Double?,
        overrideUrlString: String? = nil,
        expectedLoadToken: UUID? = nil
    ) async throws {
        guard let itemMeta = playlistManager?.currentItem else {
            throw NSError(domain: "NeomoviesCore", code: 1003, userInfo: [NSLocalizedDescriptionKey: "No current episode"])
        }
        
        let _ = playlistManager?.currentIndex ?? 0
        let resolvedItem = try await allohaManager?.resolveAllohaItemIfNeeded(itemMeta) ?? itemMeta
        
        if let expectedLoadToken,
           !(playlistManager?.isLoadTokenValid(expectedLoadToken) ?? false) {
            throw CancellationError()
        }
        
        let selectedVariantIndex = audioManager?.selectedAudioVariantIndexByMediaId[resolvedItem.mediaId] ?? 0
        let resolvedUrlString: String
        if let overrideUrlString, !overrideUrlString.isEmpty {
            resolvedUrlString = overrideUrlString
        } else if !resolvedItem.audioVariants.isEmpty,
                  resolvedItem.audioVariants.indices.contains(selectedVariantIndex) {
            resolvedUrlString = resolvedItem.audioVariants[selectedVariantIndex].url
        } else {
            resolvedUrlString = resolvedItem.url
        }

        guard let url = URL(string: resolvedUrlString) else {
            throw URLError(.badURL)
        }

        stopProxy()
        
        let playerItem = try createPlayerItem(url: url, itemMeta: resolvedItem)
        player?.replaceCurrentItem(with: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true
        player?.isMuted = false

        restorePlaybackPosition(itemMeta: resolvedItem, overrideStartSec: overrideStartSec)
        
        if autoplay {
            player?.play()
        }

        if let kpId = kpId {
            CollapsPlaybackProgressStore.shared.saveLastPlayed(kpId: kpId, season: resolvedItem.season, episode: resolvedItem.episode)
        }
        
        onAssetLoaded?()
    }
    
    func stopProxy() {
        playbackProxy?.stop()
        playbackProxy = nil
    }
    
    func cleanup() {
        stopProxy()
        currentBridge = nil
    }
    
    // MARK: - Private Helper Methods
    
    private func createPlayerItem(url: URL, itemMeta: CollapsAVPlaylistItem) throws -> AVPlayerItem {
        let playerItem: AVPlayerItem
        
        if CollapsAVHelper.shouldUseProxy(url: url, headers: itemMeta.headers) {
            do {
                let proxy = AllohaHLSProxyServer(
                    masterURL: url,
                    headers: itemMeta.headers,
                    routeBase: CollapsAVHelper.localProxyRouteBase(for: itemMeta)
                )
                if allohaManager?.isAllohaPlaylistItem(itemMeta) == true {
                    proxy.onRecoverableUpstreamFailure = { [weak self] in
                        self?.onProxyFailure?(itemMeta)
                    }
                }
                let localURL = try proxy.start()
                playbackProxy = proxy
                allohaManager?.startAllohaSessionRefreshIfNeeded(itemMeta: itemMeta)
                currentBridge = nil
                playerItem = AVPlayerItem(url: localURL)
            } catch {
                currentBridge = CollapsAVAssetBridge(sourceURL: url, headers: itemMeta.headers, rewrittenMaster: nil)
                playerItem = AVPlayerItem(asset: currentBridge!.asset)
            }
        } else {
            currentBridge = CollapsAVAssetBridge(sourceURL: url, headers: itemMeta.headers, rewrittenMaster: nil)
            playerItem = AVPlayerItem(asset: currentBridge!.asset)
        }
        
        return playerItem
    }
    
    private func restorePlaybackPosition(itemMeta: CollapsAVPlaylistItem, overrideStartSec: Double?) {
        let progressKey = progressManager?.progressKey(kpId: kpId, episode: itemMeta.episode) ?? ""
        let isWatched = CollapsPlaybackProgressStore.shared.loadWatched(mediaId: itemMeta.mediaId)
        let startAt: Double
        if isWatched {
            startAt = 0
        } else {
            startAt = overrideStartSec ?? CollapsPlaybackProgressStore.shared.load(mediaId: progressKey)
        }
        if startAt > 0 {
            player?.seek(
                to: CMTime(seconds: startAt, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
        }
    }
}
