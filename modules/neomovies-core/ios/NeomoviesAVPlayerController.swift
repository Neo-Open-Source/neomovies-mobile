import AVFoundation
import AVKit
import Foundation
import UIKit

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

public final class CollapsAVPlayerController: NSObject {
    public static let shared = CollapsAVPlayerController()

    public var onStateChanged: ((CollapsAVPlayerState) -> Void)?
    public var onProgress: ((CollapsAVPlayerState) -> Void)?
    public var onEpisodeChanged: ((CollapsAVPlayerState) -> Void)?

    private let player = AVPlayer()
    private var playerVC: CollapsNativePlayerViewController?
    private var timeObserver: Any?
    private var currentBridge: CollapsAVAssetBridge?
    private var playbackProxy: AllohaHLSProxyServer?
    private var playlist: [CollapsAVPlaylistItem] = []
    private var currentIndex: Int = 0
    private var selectedQualityIndex: Int = 0
    private var currentQualityOptions: [CollapsAVQualityOption] = [
        CollapsAVQualityOption(index: 0, bitrate: 0, height: nil, label: "Auto", isAuto: true, url: nil)
    ]
    private var selectedAudioVariantIndexByMediaId: [String: Int] = [:]
    private var kpId: Int?
    private var allohaSessionRefreshTask: Task<Void, Never>?
    private var allohaRecoveryTask: Task<Void, Never>?
    private var pendingRelativeSeekProgress: Double?
    private var qualityRecoveryCursorByMediaId: [String: Int] = [:]
    private var episodeLoadToken = UUID()

    public func setKinopoiskId(_ id: Int) {
        kpId = id
    }

    private override init() {
        super.init()
        observeItemEnd()
        observeAppLifecycle()
    }

    deinit {
        allohaSessionRefreshTask?.cancel()
        allohaRecoveryTask?.cancel()
        playbackProxy?.stop()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        NotificationCenter.default.removeObserver(self)
    }

    public func configurePlaylist(items: [CollapsAVPlaylistItem], startIndex: Int, autoplay: Bool) throws -> CollapsAVPlayerState {
        guard !items.isEmpty else {
            throw NSError(domain: "NeomoviesCore", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Playlist is empty"])
        }
        playlist = items
        currentIndex = min(max(0, startIndex), items.count - 1)
        selectedQualityIndex = 0
        pendingRelativeSeekProgress = nil
        qualityRecoveryCursorByMediaId = [:]
        episodeLoadToken = UUID()
        try loadCurrentItem(autoplay: autoplay, overrideStartSec: nil)
        let state = snapshot()
        onEpisodeChanged?(state)
        return state
    }

    @MainActor
    public func presentNativePlayer() {
        forceLandscapeOrientation()

        if playerVC == nil {
            let vc = CollapsNativePlayerViewController()
            vc.player = player
            vc.showsPlaybackControls = false
            vc.allowsPictureInPicturePlayback = true
            vc.canStartPictureInPictureAutomaticallyFromInline = true
            vc.entersFullScreenWhenPlaybackBegins = true
            vc.exitsFullScreenWhenPlaybackEnds = false
            vc.onCloseTapped = { [weak self] in
                Task { @MainActor in
                    self?.dismissNativePlayer()
                }
            }
            vc.onPlayPauseTapped = { [weak self] in
                guard let self else { return }
                if self.player.rate > 0 {
                    _ = self.pause()
                } else {
                    _ = self.play()
                }
            }
            vc.onSeekRelative = { [weak self] delta in
                guard let self else { return }
                let now = self.player.currentTime().seconds
                let target = max(0, now + delta)
                _ = self.seek(to: target)
            }
            vc.onSliderSeek = { [weak self] value in
                guard let self else { return }
                _ = self.seek(to: value)
            }
            vc.onAudioTapped = { [weak self, weak vc] source in
                guard let self, let vc else { return }
                self.showAudioSheet(from: vc, sourceView: source)
            }
            vc.onQualityTapped = { [weak self, weak vc] source in
                guard let self, let vc else { return }
                self.showQualitySheet(from: vc, sourceView: source)
            }
            vc.onPreviousEpisodeTapped = { [weak self] in
                guard let self, self.currentIndex > 0 else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    do {
                        _ = try await self.previousEpisodeAsync(autoplay: true)
                    } catch {}
                }
            }
            vc.onNextEpisodeTapped = { [weak self] in
                guard let self, self.currentIndex < self.playlist.count - 1 else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    do {
                        _ = try await self.nextEpisodeAsync(autoplay: true)
                    } catch {}
                }
            }
            vc.onWillDisappearCallback = { [weak self] in
                self?.persistCurrentProgress()
            }
            playerVC = vc
        }

        guard let presenter = topViewController(), let playerVC else { return }
        if presenter.presentedViewController === playerVC { return }
        presenter.present(playerVC, animated: true)
        refreshOverlayUI()
    }

    @MainActor
    public func dismissNativePlayer() {
        persistCurrentProgress()
        playerVC?.dismiss(animated: true)
        forcePortraitOrientation()
    }

    public func play() -> CollapsAVPlayerState {
        player.play()
        let state = snapshot()
        onStateChanged?(state)
        refreshOverlayUI()
        return state
    }

    public func pause() -> CollapsAVPlayerState {
        player.pause()
        persistCurrentProgress()
        let state = snapshot()
        onStateChanged?(state)
        refreshOverlayUI()
        return state
    }

    public func stop() {
        persistCurrentProgress()
        player.pause()
        player.replaceCurrentItem(with: nil)
        playbackProxy?.stop()
        playbackProxy = nil
        allohaSessionRefreshTask?.cancel()
        allohaSessionRefreshTask = nil
        allohaRecoveryTask?.cancel()
        allohaRecoveryTask = nil
        currentBridge = nil
        playlist = []
        currentIndex = 0
        selectedAudioVariantIndexByMediaId = [:]
        episodeLoadToken = UUID()
        emitState()
    }

    public func seek(to seconds: Double) -> CollapsAVPlayerState {
        player.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 600))
        let state = snapshot()
        onStateChanged?(state)
        refreshOverlayUI()
        return state
    }

    public func setRate(_ rate: Float) -> CollapsAVPlayerState {
        player.rate = max(0.25, min(rate, 3.0))
        let state = snapshot()
        onStateChanged?(state)
        refreshOverlayUI()
        return state
    }

    public func setPreferredPeakBitRate(_ bitrate: Double) {
        player.currentItem?.preferredPeakBitRate = max(0, bitrate)
        refreshOverlayUI()
    }

    public func listQualityOptions() -> [[String: Any]] {
        currentQualityOptions.map { $0.asDictionary() }
    }

    public func selectQuality(index: Int?) {
        guard let index,
              let option = currentQualityOptions.first(where: { $0.index == index }) else {
            player.currentItem?.preferredPeakBitRate = 0
            selectedQualityIndex = 0
            if let mediaId = playlist[safe: currentIndex]?.mediaId {
                qualityRecoveryCursorByMediaId[mediaId] = 0
            }
            emitState()
            return
        }
        if let mediaId = playlist[safe: currentIndex]?.mediaId {
            qualityRecoveryCursorByMediaId[mediaId] = 0
        }
        if let forcedUrl = option.url, !forcedUrl.isEmpty, !option.isAuto {
            let currentState = snapshot()
            let resumeAt = currentState.currentTimeSec
            pendingRelativeSeekProgress = normalizedRelativeProgress(
                currentTime: currentState.currentTimeSec,
                duration: currentState.durationSec
            )
            do {
                try loadCurrentItem(
                    autoplay: player.rate > 0,
                    overrideStartSec: resumeAt.isFinite ? max(0, resumeAt) : nil,
                    overrideUrlString: forcedUrl
                )
            } catch {
                player.currentItem?.preferredPeakBitRate = option.isAuto ? 0 : option.bitrate
            }
        } else {
            player.currentItem?.preferredPeakBitRate = option.isAuto ? 0 : option.bitrate
        }
        selectedQualityIndex = option.index
        emitState()
    }

    public func refreshQualityOptions() async -> [[String: Any]] {
        guard playlist.indices.contains(currentIndex) else {
            currentQualityOptions = [CollapsAVQualityOption(index: 0, bitrate: 0, height: nil, label: "Auto", isAuto: true, url: nil)]
            return listQualityOptions()
        }
        let current = playlist[currentIndex]
        if isAllohaPlaylistItem(current) {
            currentQualityOptions = makeAllohaQualityOptions(for: current)
            if !currentQualityOptions.contains(where: { $0.index == selectedQualityIndex }) {
                selectedQualityIndex = 0
            }
            refreshOverlayUI()
            return listQualityOptions()
        }
        let selectedVariantIndex = selectedAudioVariantIndexByMediaId[current.mediaId] ?? 0
        let activeUrlString: String
        if !current.audioVariants.isEmpty,
           current.audioVariants.indices.contains(selectedVariantIndex) {
            activeUrlString = current.audioVariants[selectedVariantIndex].url
        } else {
            activeUrlString = current.url
        }
        currentQualityOptions = await Self.parseHlsQualityOptions(urlString: activeUrlString, headers: current.headers)
        if !currentQualityOptions.contains(where: { $0.index == selectedQualityIndex }) {
            selectedQualityIndex = 0
        }
        refreshOverlayUI()
        return listQualityOptions()
    }

    public func selectEpisode(index: Int, autoplay: Bool) throws -> CollapsAVPlayerState {
        guard index >= 0, index < playlist.count else {
            throw NSError(domain: "NeomoviesCore", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Episode index out of range"])
        }
        persistCurrentProgress()
        let previousIndex = currentIndex
        currentIndex = index
        selectedQualityIndex = 0
        pendingRelativeSeekProgress = nil
        if let mediaId = playlist[safe: index]?.mediaId {
            qualityRecoveryCursorByMediaId[mediaId] = 0
        }
        do {
            try loadCurrentItem(autoplay: autoplay, overrideStartSec: nil)
        } catch {
            currentIndex = previousIndex
            throw error
        }
        let state = snapshot()
        onEpisodeChanged?(state)
        return state
    }

    public func nextEpisode(autoplay: Bool) throws -> CollapsAVPlayerState {
        try selectEpisode(index: min(currentIndex + 1, max(playlist.count - 1, 0)), autoplay: autoplay)
    }

    public func previousEpisode(autoplay: Bool) throws -> CollapsAVPlayerState {
        try selectEpisode(index: max(currentIndex - 1, 0), autoplay: autoplay)
    }

    @MainActor
    public func selectEpisodeAsync(index: Int, autoplay: Bool) async throws -> CollapsAVPlayerState {
        guard index >= 0, index < playlist.count else {
            throw NSError(domain: "NeomoviesCore", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Episode index out of range"])
        }
        let loadToken = UUID()
        episodeLoadToken = loadToken
        persistCurrentProgress()
        let previousIndex = currentIndex
        currentIndex = index
        selectedQualityIndex = 0
        pendingRelativeSeekProgress = nil
        if let mediaId = playlist[safe: index]?.mediaId {
            qualityRecoveryCursorByMediaId[mediaId] = 0
        }
        do {
            try await loadCurrentItemAsync(autoplay: autoplay, overrideStartSec: nil, expectedLoadToken: loadToken)
        } catch {
            currentIndex = previousIndex
            throw error
        }
        guard episodeLoadToken == loadToken, currentIndex == index else {
            return snapshot()
        }
        let state = snapshot()
        onEpisodeChanged?(state)
        return state
    }

    @MainActor
    public func nextEpisodeAsync(autoplay: Bool) async throws -> CollapsAVPlayerState {
        try await selectEpisodeAsync(index: min(currentIndex + 1, max(playlist.count - 1, 0)), autoplay: autoplay)
    }

    @MainActor
    public func previousEpisodeAsync(autoplay: Bool) async throws -> CollapsAVPlayerState {
        try await selectEpisodeAsync(index: max(currentIndex - 1, 0), autoplay: autoplay)
    }

    public func snapshot() -> CollapsAVPlayerState {
        let item = player.currentItem
        let duration = item?.duration.seconds
        let current = item != nil ? player.currentTime().seconds : 0
        let currentMeta = playlist.indices.contains(currentIndex) ? playlist[currentIndex] : nil

        return CollapsAVPlayerState(
            isLoaded: item != nil,
            isPlaying: player.rate > 0,
            rate: player.rate,
            currentTimeSec: current.isFinite ? max(0, current) : 0,
            durationSec: (duration?.isFinite == true) ? max(0, duration ?? 0) : 0,
            currentIndex: currentIndex,
            totalItems: playlist.count,
            season: currentMeta?.season,
            episode: currentMeta?.episode,
            mediaId: currentMeta?.mediaId
        )
    }

    public func listAudioTracks() -> [[String: Any]] {
        if let current = playlist[safe: currentIndex], !current.audioVariants.isEmpty {
            return current.audioVariants.enumerated().map { index, variant in
                CollapsAVTrack(
                    index: index,
                    id: "alloha-\(index)",
                    label: normalizedOverlayLabel(variant.title, fallback: "Unknown"),
                    language: ""
                ).asDictionary()
            }
        }

        if isCustomAllohaVoiceoverPlaylist {
            var used: [String: Int] = [:]
            return playlist.enumerated().map { index, item in
                let raw = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let baseLabel = raw.isEmpty ? "Unknown" : raw
                used[baseLabel, default: 0] += 1
                let suffix = used[baseLabel] ?? 1
                let label = suffix > 1 ? "\(baseLabel) \(suffix)" : baseLabel
                return CollapsAVTrack(
                    index: index,
                    id: "alloha-\(index)",
                    label: label,
                    language: ""
                ).asDictionary()
            }
        }

        guard let group = player.currentItem?.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
            return []
        }
        return group.options.enumerated().map { index, option in
            CollapsAVTrack(
                index: index,
                id: option.extendedLanguageTag ?? option.locale?.identifier ?? "",
                label: option.displayName,
                language: option.locale?.identifier ?? ""
            ).asDictionary()
        }
    }

    public func selectAudioTrack(index: Int?) {
        if let current = playlist[safe: currentIndex], !current.audioVariants.isEmpty {
            guard let index, index >= 0, index < current.audioVariants.count else { return }
            let state = snapshot()
            let currentTime = state.currentTimeSec
            let currentDuration = state.durationSec
            let relativeProgress = normalizedRelativeProgress(currentTime: currentTime, duration: currentDuration)
            let targetVariant = current.audioVariants[index]
            let targetDurationHint = CollapsPlaybackProgressStore.shared.loadDuration(
                mediaId: scopedPlaybackMediaId(baseMediaId: current.mediaId, urlString: targetVariant.url)
            )
            let estimatedStartSec: Double
            if let relativeProgress, targetDurationHint > 0 {
                estimatedStartSec = relativeProgress * targetDurationHint
            } else {
                estimatedStartSec = currentTime
            }

            selectedAudioVariantIndexByMediaId[current.mediaId] = index
            pendingRelativeSeekProgress = relativeProgress
            do {
                try loadCurrentItem(autoplay: true, overrideStartSec: estimatedStartSec)
                emitState()
            } catch {}
            return
        }

        if isCustomAllohaVoiceoverPlaylist {
            guard let index, index >= 0, index < playlist.count else { return }
            if index == currentIndex { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    _ = try await self.selectEpisodeAsync(index: index, autoplay: true)
                } catch {}
            }
            return
        }

        guard let item = player.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
            return
        }
        if let index, index >= 0, index < group.options.count {
            item.select(group.options[index], in: group)
        } else {
            item.select(nil, in: group)
        }
        emitState()
    }

    private var isCustomAllohaVoiceoverPlaylist: Bool {
        guard playlist.count > 1 else { return false }
        guard let first = playlist.first,
              let season = first.season,
              let episode = first.episode else {
            return false
        }

        let allSameEpisode = playlist.allSatisfy { $0.season == season && $0.episode == episode }
        if !allSameEpisode { return false }

        let uniqueUrls = Set(playlist.map { $0.url })
        return uniqueUrls.count > 1
    }

    public func listSubtitleTracks() -> [[String: Any]] {
        guard let group = player.currentItem?.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            return []
        }
        return group.options.enumerated().map { index, option in
            CollapsAVTrack(
                index: index,
                id: option.extendedLanguageTag ?? option.locale?.identifier ?? "",
                label: option.displayName,
                language: option.locale?.identifier ?? ""
            ).asDictionary()
        }
    }

    public func selectSubtitleTrack(index: Int?) {
        guard let item = player.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            return
        }
        if let index, index >= 0, index < group.options.count {
            item.select(group.options[index], in: group)
        } else {
            item.select(nil, in: group)
        }
        emitState()
    }

    private func loadCurrentItem(autoplay: Bool, overrideStartSec: Double?, overrideUrlString: String? = nil) throws {
        guard playlist.indices.contains(currentIndex) else {
            throw NSError(domain: "NeomoviesCore", code: 1003, userInfo: [NSLocalizedDescriptionKey: "No current episode"])
        }
        let itemMeta = try resolveAllohaItemIfNeeded(playlist[currentIndex], index: currentIndex)
        let selectedVariantIndex = selectedAudioVariantIndexByMediaId[itemMeta.mediaId] ?? 0
        let resolvedUrlString: String
        if let overrideUrlString, !overrideUrlString.isEmpty {
            resolvedUrlString = overrideUrlString
        } else if !itemMeta.audioVariants.isEmpty,
           itemMeta.audioVariants.indices.contains(selectedVariantIndex) {
            resolvedUrlString = itemMeta.audioVariants[selectedVariantIndex].url
        } else {
            resolvedUrlString = itemMeta.url
        }

        guard let url = URL(string: resolvedUrlString) else {
            throw URLError(.badURL)
        }

        playbackProxy?.stop()
        playbackProxy = nil

        let playerItem: AVPlayerItem
        if shouldUseProxy(url: url, headers: itemMeta.headers) {
            do {
                let proxy = AllohaHLSProxyServer(
                    masterURL: url,
                    headers: itemMeta.headers,
                    routeBase: localProxyRouteBase(for: itemMeta)
                )
                if isAllohaPlaylistItem(itemMeta) {
                    proxy.onRecoverableUpstreamFailure = { [weak self] in
                        self?.scheduleImmediateAllohaRecovery(for: itemMeta)
                    }
                }
                let localURL = try proxy.start()
                playbackProxy = proxy
                startAllohaSessionRefreshIfNeeded(itemMeta: itemMeta)
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
        player.replaceCurrentItem(with: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        player.isMuted = false

        let startAt = overrideStartSec ?? CollapsPlaybackProgressStore.shared.load(mediaId: itemMeta.mediaId)
        if overrideStartSec == nil, pendingRelativeSeekProgress == nil {
            pendingRelativeSeekProgress = CollapsPlaybackProgressStore.shared.normalizedProgress(mediaId: itemMeta.mediaId)
        }
        if startAt > 0 {
            player.seek(
                to: CMTime(seconds: startAt, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
        }

        installProgressObserver()

        if autoplay {
            player.play()
        }

        if let kpId = kpId {
            CollapsPlaybackProgressStore.shared.saveLastPlayed(kpId: kpId, season: itemMeta.season, episode: itemMeta.episode)
        }

        Task {
            _ = await refreshQualityOptions()
        }
        scheduleDeferredRelativeSeekIfNeeded(for: playerItem)
        emitState()
    }

    @MainActor
    private func loadCurrentItemAsync(
        autoplay: Bool,
        overrideStartSec: Double?,
        overrideUrlString: String? = nil,
        expectedLoadToken: UUID? = nil
    ) async throws {
        guard playlist.indices.contains(currentIndex) else {
            throw NSError(domain: "NeomoviesCore", code: 1003, userInfo: [NSLocalizedDescriptionKey: "No current episode"])
        }
        let targetIndex = currentIndex
        let itemMeta = try await resolveAllohaItemIfNeededAsync(playlist[currentIndex], index: targetIndex)
        if let expectedLoadToken,
           (episodeLoadToken != expectedLoadToken || currentIndex != targetIndex) {
            throw CancellationError()
        }
        let selectedVariantIndex = selectedAudioVariantIndexByMediaId[itemMeta.mediaId] ?? 0
        let resolvedUrlString: String
        if let overrideUrlString, !overrideUrlString.isEmpty {
            resolvedUrlString = overrideUrlString
        } else if !itemMeta.audioVariants.isEmpty,
                  itemMeta.audioVariants.indices.contains(selectedVariantIndex) {
            resolvedUrlString = itemMeta.audioVariants[selectedVariantIndex].url
        } else {
            resolvedUrlString = itemMeta.url
        }

        guard let url = URL(string: resolvedUrlString) else {
            throw URLError(.badURL)
        }

        playbackProxy?.stop()
        playbackProxy = nil

        let playerItem: AVPlayerItem
        if shouldUseProxy(url: url, headers: itemMeta.headers) {
            do {
                let proxy = AllohaHLSProxyServer(
                    masterURL: url,
                    headers: itemMeta.headers,
                    routeBase: localProxyRouteBase(for: itemMeta)
                )
                if isAllohaPlaylistItem(itemMeta) {
                    proxy.onRecoverableUpstreamFailure = { [weak self] in
                        self?.scheduleImmediateAllohaRecovery(for: itemMeta)
                    }
                }
                let localURL = try proxy.start()
                playbackProxy = proxy
                startAllohaSessionRefreshIfNeeded(itemMeta: itemMeta)
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
        player.replaceCurrentItem(with: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        player.isMuted = false

        let startAt = overrideStartSec ?? CollapsPlaybackProgressStore.shared.load(mediaId: itemMeta.mediaId)
        if overrideStartSec == nil, pendingRelativeSeekProgress == nil {
            pendingRelativeSeekProgress = CollapsPlaybackProgressStore.shared.normalizedProgress(mediaId: itemMeta.mediaId)
        }
        if startAt > 0 {
            await player.seek(to: CMTime(seconds: startAt, preferredTimescale: 600))
        }

        installProgressObserver()

        if autoplay {
            player.play()
        }

        if let kpId = kpId {
            CollapsPlaybackProgressStore.shared.saveLastPlayed(kpId: kpId, season: itemMeta.season, episode: itemMeta.episode)
        }

        Task {
            if expectedLoadToken == nil || self.episodeLoadToken == expectedLoadToken {
                _ = await refreshQualityOptions()
            }
        }
        scheduleDeferredRelativeSeekIfNeeded(for: playerItem)
        emitState()
    }

    private func resolveAllohaItemIfNeeded(_ item: CollapsAVPlaylistItem, index: Int) throws -> CollapsAVPlaylistItem {
        guard isAllohaPlaylistItem(item),
              let iframeUrl = item.headers["X-Neo-Alloha-Iframe"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !iframeUrl.isEmpty else {
            return item
        }

        let looksResolved = item.url.lowercased().contains(".m3u8") || item.url.lowercased().contains(".mp4") || item.url.lowercased().contains(".mpd")
        let hasSessionHeaders = !(item.headers["accepts-controls"] ?? item.headers["authorizations"] ?? "").isEmpty
        if looksResolved && hasSessionHeaders {
            return item
        }

        let resolved = try awaitResolveAllohaStream(iframeUrl: iframeUrl)
        guard let resolvedUrl = resolved["url"] as? String, !resolvedUrl.isEmpty else {
            return item
        }

        let mergedHeaders = item.headers.merging((resolved["headers"] as? [String: String]) ?? [:]) { _, new in new }
        let subtitles = ((resolved["subtitles"] as? [[String: Any]]) ?? []).compactMap { subtitle -> CollapsSubtitle? in
            guard let url = subtitle["url"] as? String, !url.isEmpty else { return nil }
            let label = (subtitle["label"] as? String) ?? (subtitle["name"] as? String) ?? ""
            let language = (subtitle["language"] as? String) ?? ""
            return CollapsSubtitle(url: url, label: label, language: language)
        }
        let audioVariants = ((resolved["audioVariants"] as? [[String: Any]]) ?? []).compactMap { variant -> CollapsAVAudioVariant? in
            guard let url = variant["url"] as? String, !url.isEmpty else { return nil }
            let title = (variant["title"] as? String) ?? ""
            let qualityVariants = ((variant["qualityVariants"] as? [[String: Any]]) ?? []).compactMap { qualityFromDictionary($0) }
            return CollapsAVAudioVariant(title: title, url: url, qualityVariants: qualityVariants)
        }
        let qualityVariants = ((resolved["qualityVariants"] as? [[String: Any]]) ?? []).compactMap { qualityFromDictionary($0) }

        let resolvedItem = CollapsAVPlaylistItem(
            mediaId: item.mediaId,
            title: item.title,
            url: resolvedUrl,
            headers: mergedHeaders,
            season: item.season,
            episode: item.episode,
            voiceovers: item.voiceovers,
            subtitles: subtitles.isEmpty ? item.subtitles : subtitles,
            audioVariants: audioVariants.isEmpty ? item.audioVariants : audioVariants,
            qualityVariants: qualityVariants.isEmpty ? item.qualityVariants : qualityVariants
        )
        if playlist.indices.contains(index) {
            playlist[index] = resolvedItem
        }
        return resolvedItem
    }

    @MainActor
    private func resolveAllohaItemIfNeededAsync(_ item: CollapsAVPlaylistItem, index: Int) async throws -> CollapsAVPlaylistItem {
        guard isAllohaPlaylistItem(item),
              let iframeUrl = item.headers["X-Neo-Alloha-Iframe"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !iframeUrl.isEmpty else {
            return item
        }

        let looksResolved = item.url.lowercased().contains(".m3u8") || item.url.lowercased().contains(".mp4") || item.url.lowercased().contains(".mpd")
        let hasSessionHeaders = !(item.headers["accepts-controls"] ?? item.headers["authorizations"] ?? "").isEmpty
        if looksResolved && hasSessionHeaders {
            return item
        }

        let resolver = AllohaRuntimeResolver()
        let resolved = try await resolver.resolve(iframeUrl: iframeUrl)
        guard let resolvedUrl = resolved["url"] as? String, !resolvedUrl.isEmpty else {
            return item
        }

        let mergedHeaders = item.headers.merging((resolved["headers"] as? [String: String]) ?? [:]) { _, new in new }
        let subtitles = ((resolved["subtitles"] as? [[String: Any]]) ?? []).compactMap { subtitle -> CollapsSubtitle? in
            guard let url = subtitle["url"] as? String, !url.isEmpty else { return nil }
            let label = (subtitle["label"] as? String) ?? (subtitle["name"] as? String) ?? ""
            let language = (subtitle["language"] as? String) ?? ""
            return CollapsSubtitle(url: url, label: label, language: language)
        }
        let audioVariants = ((resolved["audioVariants"] as? [[String: Any]]) ?? []).compactMap { variant -> CollapsAVAudioVariant? in
            guard let url = variant["url"] as? String, !url.isEmpty else { return nil }
            let title = (variant["title"] as? String) ?? ""
            let qualityVariants = ((variant["qualityVariants"] as? [[String: Any]]) ?? []).compactMap { qualityFromDictionary($0) }
            return CollapsAVAudioVariant(title: title, url: url, qualityVariants: qualityVariants)
        }
        let qualityVariants = ((resolved["qualityVariants"] as? [[String: Any]]) ?? []).compactMap { qualityFromDictionary($0) }

        let resolvedItem = CollapsAVPlaylistItem(
            mediaId: item.mediaId,
            title: item.title,
            url: resolvedUrl,
            headers: mergedHeaders,
            season: item.season,
            episode: item.episode,
            voiceovers: item.voiceovers,
            subtitles: subtitles.isEmpty ? item.subtitles : subtitles,
            audioVariants: audioVariants.isEmpty ? item.audioVariants : audioVariants,
            qualityVariants: qualityVariants.isEmpty ? item.qualityVariants : qualityVariants
        )
        if playlist.indices.contains(index) {
            playlist[index] = resolvedItem
        }
        return resolvedItem
    }

    private func awaitResolveAllohaStream(iframeUrl: String) throws -> [String: Any] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<[String: Any], Error> = .failure(URLError(.cannotLoadFromNetwork))
        Task {
            do {
                let resolved = try await MainActor.run { AllohaRuntimeResolver() }.resolve(iframeUrl: iframeUrl)
                result = .success(resolved)
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()
        return try result.get()
    }

    private func qualityFromDictionary(_ quality: [String: Any]) -> CollapsAVQualityOption? {
        guard let qurl = quality["url"] as? String, !qurl.isEmpty else { return nil }
        let label = (quality["label"] as? String) ?? "Stream"
        let bitrate = quality["bitrate"] as? Double ?? quality["bandwidth"] as? Double ?? 0
        let height = quality["height"] as? Int ?? Self.heightFromQualityLabel(label)
        return CollapsAVQualityOption(index: 0, bitrate: bitrate, height: height, label: label, isAuto: false, url: qurl)
    }

    private func startAllohaSessionRefreshIfNeeded(itemMeta: CollapsAVPlaylistItem) {
        allohaSessionRefreshTask?.cancel()
        allohaSessionRefreshTask = nil

        guard let proxy = playbackProxy,
              let iframeUrl = itemMeta.headers["X-Neo-Alloha-Iframe"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !iframeUrl.isEmpty else {
            return
        }

        let ttlRaw = itemMeta.headers["x-neo-config-ttl"] ?? itemMeta.headers["X-Neo-Config-Ttl"] ?? ""
        let ttlSec = Int(ttlRaw) ?? 120
        let refreshDelaySec = max(30, ttlSec - 20)

        allohaSessionRefreshTask = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(refreshDelaySec) * 1_000_000_000)
                } catch {
                    return
                }
                if Task.isCancelled { return }
                do {
                    try await self.refreshAllohaProxySession(proxy: proxy, iframeUrl: iframeUrl)
                } catch {
                    continue
                }
            }
        }
    }

    private func scheduleImmediateAllohaRecovery(for itemMeta: CollapsAVPlaylistItem) {
        guard let proxy = playbackProxy,
              let iframeUrl = itemMeta.headers["X-Neo-Alloha-Iframe"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !iframeUrl.isEmpty else {
            return
        }
        if let task = allohaRecoveryTask, !task.isCancelled {
            return
        }
        allohaRecoveryTask = Task.detached(priority: .high) { [weak self] in
            guard let self else { return }
            defer { self.allohaRecoveryTask = nil }
            do {
                try await self.refreshAllohaProxySession(proxy: proxy, iframeUrl: iframeUrl)
                await MainActor.run {
                    guard self.playlist[safe: self.currentIndex]?.mediaId == itemMeta.mediaId else { return }
                    self.recoverPlaybackAfterAllohaRecovery()
                }
            } catch {}
        }
    }

    private func refreshAllohaProxySession(proxy: AllohaHLSProxyServer, iframeUrl: String) async throws {
        let resolved = try await MainActor.run { AllohaRuntimeResolver() }.resolve(iframeUrl: iframeUrl)
        guard let newUrlString = resolved["url"] as? String,
              let newURL = URL(string: newUrlString) else {
            return
        }
        let newHeaders = (resolved["headers"] as? [String: String]) ?? [:]
        proxy.updateHeaders(newHeaders)
        proxy.updateMasterURL(newURL)
    }

    @MainActor
    private func recoverPlaybackAfterAllohaRecovery() {
        if let item = playlist[safe: currentIndex] {
            let wasPlaying = player.rate > 0
            let currentState = snapshot()
            let resumeAt = currentState.currentTimeSec.isFinite ? max(0, currentState.currentTimeSec) : nil
            pendingRelativeSeekProgress = normalizedRelativeProgress(
                currentTime: currentState.currentTimeSec,
                duration: currentState.durationSec
            )

            if selectedQualityIndex != 0 {
                selectedQualityIndex = 0
                qualityRecoveryCursorByMediaId[item.mediaId] = 0
                player.currentItem?.preferredPeakBitRate = 0
                do {
                    try loadCurrentItem(
                        autoplay: wasPlaying,
                        overrideStartSec: resumeAt,
                        overrideUrlString: nil
                    )
                    return
                } catch {
                    // Fall through to lower-quality ladder below if reload on Auto fails.
                }
            }

            let candidates = qualityRecoveryCandidates(from: currentQualityOptions)
            let cursor = qualityRecoveryCursorByMediaId[item.mediaId] ?? 0
            if candidates.indices.contains(cursor),
               let option = currentQualityOptions.first(where: { $0.index == candidates[cursor] }),
               let forcedUrl = option.url,
               !forcedUrl.isEmpty {
                selectedQualityIndex = option.index
                qualityRecoveryCursorByMediaId[item.mediaId] = cursor + 1
                do {
                    try loadCurrentItem(
                        autoplay: wasPlaying,
                        overrideStartSec: resumeAt,
                        overrideUrlString: forcedUrl
                    )
                    return
                } catch {
                    // Fall through to seek-nudge if no fallback quality worked.
                }
            }
        }

        let wasPlaying = player.rate > 0
        let currentSeconds = player.currentTime().seconds
        let safeCurrent = currentSeconds.isFinite ? max(0, currentSeconds) : 0
        let target = max(0, safeCurrent - 0.15)

        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] _ in
            guard let self else { return }
            if wasPlaying {
                self.player.play()
            }
        }
    }

    private func qualityRecoveryCandidates(from options: [CollapsAVQualityOption]) -> [Int] {
        let nonAuto = options.filter { !$0.isAuto }
        guard !nonAuto.isEmpty else { return [] }

        let preferredMediumOrLow = nonAuto
            .filter { ($0.height ?? Int.max) <= 720 }
            .sorted { lhs, rhs in
                let l = lhs.height ?? 0
                let r = rhs.height ?? 0
                if l == r { return lhs.bitrate > rhs.bitrate }
                return l > r
            }

        let remaining = nonAuto
            .filter { candidate in
                !preferredMediumOrLow.contains(where: { $0.index == candidate.index })
            }
            .sorted { lhs, rhs in
                let l = lhs.height ?? 0
                let r = rhs.height ?? 0
                if l == r { return lhs.bitrate > rhs.bitrate }
                return l > r
            }

        return (preferredMediumOrLow + remaining).map(\.index)
    }

    private func shouldUseProxy(url: URL, headers: [String: String]) -> Bool {
        !headers.isEmpty && url.path.lowercased().contains(".m3u8")
    }

    private func isAllohaPlaylistItem(_ item: CollapsAVPlaylistItem) -> Bool {
        let iframe = item.headers["X-Neo-Alloha-Iframe"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !iframe.isEmpty
    }

    private func makeAllohaQualityOptions(for item: CollapsAVPlaylistItem) -> [CollapsAVQualityOption] {
        let selectedVariantIndex = selectedAudioVariantIndexByMediaId[item.mediaId] ?? 0
        let rawOptions: [CollapsAVQualityOption]
        if !item.audioVariants.isEmpty,
           item.audioVariants.indices.contains(selectedVariantIndex),
           !item.audioVariants[selectedVariantIndex].qualityVariants.isEmpty {
            rawOptions = item.audioVariants[selectedVariantIndex].qualityVariants
        } else {
            rawOptions = item.qualityVariants
        }

        let filtered = rawOptions
            .filter { option in
                let label = option.label.lowercased()
                return !label.contains("av1") && !label.contains("av01")
            }
            .sorted { lhs, rhs in
                let l = lhs.height ?? 0
                let r = rhs.height ?? 0
                if l == r { return lhs.bitrate > rhs.bitrate }
                return l > r
            }

        var result: [CollapsAVQualityOption] = [
            CollapsAVQualityOption(index: 0, bitrate: 0, height: nil, label: "Auto", isAuto: true, url: nil)
        ]
        for (offset, option) in filtered.enumerated() {
            result.append(
                CollapsAVQualityOption(
                    index: offset + 1,
                    bitrate: option.bitrate,
                    height: option.height,
                    label: option.label,
                    isAuto: false,
                    url: option.url
                )
            )
        }
        return result
    }

    private func localProxyRouteBase(for item: CollapsAVPlaylistItem) -> String {
        let rawMediaId = item.mediaId.trimmingCharacters(in: .whitespacesAndNewlines)
        let mediaPath = rawMediaId
            .replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let base = mediaPath.isEmpty ? "stream" : mediaPath

        if let season = item.season, let episode = item.episode {
            return "\(base)/\(season)/\(episode)"
        }
        return base
    }

    private func installProgressObserver() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        let interval = CMTime(seconds: 1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self else { return }
            let state = self.snapshot()
            if let mediaId = state.mediaId {
                let dur = state.durationSec > 0 ? state.durationSec : nil
                CollapsPlaybackProgressStore.shared.save(mediaId: mediaId, positionSec: state.currentTimeSec, durationSec: dur)
                if let scopedMediaId = self.currentScopedPlaybackMediaId() {
                    CollapsPlaybackProgressStore.shared.save(mediaId: scopedMediaId, positionSec: state.currentTimeSec, durationSec: dur)
                }
                if let kpId = self.kpId, let currentItem = self.playlist[safe: self.currentIndex] {
                    print("[AVPlayer] Saving progress: kpId=\(kpId), season=\(currentItem.season ?? 0), episode=\(currentItem.episode ?? 0), position=\(state.currentTimeSec)s, duration=\(state.durationSec)s")
                }
            }
            self.onProgress?(state)
            self.refreshOverlayUI()
        }
    }

    private func observeItemEnd() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleItemEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }

    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func handleAppWillResignActive() {
        persistCurrentProgress()
    }

    @objc private func handleAppDidEnterBackground() {
        persistCurrentProgress()
    }

    @objc private func handleItemEnd(notification: Notification) {
        guard let item = notification.object as? AVPlayerItem,
              item === player.currentItem else { return }

        if currentIndex + 1 < playlist.count {
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    _ = try await self.selectEpisodeAsync(index: self.currentIndex + 1, autoplay: true)
                } catch {
                    emitState()
                }
            }
            return
        }

        emitState()
    }

    private func emitState() {
        onStateChanged?(snapshot())
        refreshOverlayUI()
    }

    private func persistCurrentProgress() {
        guard playlist.indices.contains(currentIndex) else { return }
        let mediaId = playlist[currentIndex].mediaId
        guard !mediaId.isEmpty else { return }

        let seconds = player.currentTime().seconds
        guard seconds.isFinite, seconds >= 0 else { return }
        let rawDur = player.currentItem?.duration.seconds
        let dur: Double? = (rawDur?.isFinite == true && (rawDur ?? 0) > 0) ? rawDur : nil
        CollapsPlaybackProgressStore.shared.save(mediaId: mediaId, positionSec: seconds, durationSec: dur)
        if let scopedMediaId = currentScopedPlaybackMediaId() {
            CollapsPlaybackProgressStore.shared.save(mediaId: scopedMediaId, positionSec: seconds, durationSec: dur)
        }
    }

    private func scheduleDeferredRelativeSeekIfNeeded(for playerItem: AVPlayerItem) {
        guard let relativeProgress = pendingRelativeSeekProgress else { return }
        pendingRelativeSeekProgress = nil

        Task { @MainActor [weak self, weak playerItem] in
            guard let self else { return }
            let checkpoints: [UInt64] = [250_000_000, 900_000_000, 1_800_000_000]
            for delay in checkpoints {
                try? await Task.sleep(nanoseconds: delay)
                guard let playerItem,
                      self.player.currentItem === playerItem else { return }
                let duration = playerItem.duration.seconds
                guard duration.isFinite, duration > 0 else { continue }

                let targetSeconds = max(0, min(duration * relativeProgress, max(duration - 1.5, 0)))
                let currentSeconds = self.player.currentTime().seconds
                guard currentSeconds.isFinite else { return }

                if abs(currentSeconds - targetSeconds) > 2.0 {
                    await self.player.seek(to: CMTime(seconds: targetSeconds, preferredTimescale: 600))
                }
                return
            }
        }
    }

    private func normalizedRelativeProgress(currentTime: Double, duration: Double) -> Double? {
        guard currentTime.isFinite, duration.isFinite, duration > 0 else { return nil }
        let progress = currentTime / duration
        guard progress.isFinite else { return nil }
        return max(0, min(progress, 0.999))
    }

    private func currentScopedPlaybackMediaId() -> String? {
        guard let item = playlist[safe: currentIndex] else { return nil }
        let selectedVariantIndex = selectedAudioVariantIndexByMediaId[item.mediaId] ?? 0
        let urlString: String
        if !item.audioVariants.isEmpty, item.audioVariants.indices.contains(selectedVariantIndex) {
            urlString = item.audioVariants[selectedVariantIndex].url
        } else {
            urlString = item.url
        }
        return scopedPlaybackMediaId(baseMediaId: item.mediaId, urlString: urlString)
    }

    private func scopedPlaybackMediaId(baseMediaId: String, urlString: String) -> String {
        var hash: UInt64 = 5381
        for scalar in urlString.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ UInt64(scalar.value)
        }
        return "\(baseMediaId)__src_\(String(hash, radix: 16))"
    }

    @MainActor
    private func showQualitySheet(from controller: UIViewController, sourceView: UIView) {
        let sheet = UIAlertController(title: "Quality", message: nil, preferredStyle: .actionSheet)
        for option in currentQualityOptions {
            sheet.addAction(
                UIAlertAction(title: option.label, style: .default, handler: { [weak self] _ in
                    self?.selectQuality(index: option.index)
                })
            )
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        controller.present(sheet, animated: true)
    }

    @MainActor
    private func showAudioSheet(from controller: UIViewController, sourceView: UIView) {
        let tracks = listAudioTracks()
        let sheet = UIAlertController(title: "Audio Track", message: nil, preferredStyle: .actionSheet)
        var usedLabels: [String: Int] = [:]
        for track in tracks {
            let baseLabel = ((track["label"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? (track["label"] as? String ?? "Track")
                : "Track"
            usedLabels[baseLabel, default: 0] += 1
            let count = usedLabels[baseLabel] ?? 1
            let label = count > 1 ? "\(baseLabel) \(count)" : baseLabel
            let index = track["index"] as? Int
            sheet.addAction(UIAlertAction(title: label, style: .default, handler: { [weak self] _ in
                self?.selectAudioTrack(index: index)
            }))
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        controller.present(sheet, animated: true)
    }

    @MainActor
    private func forceLandscapeOrientation() {
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: [.landscapeRight, .landscapeLeft])
            windowScene.requestGeometryUpdate(prefs) { _ in }
            UIViewController.attemptRotationToDeviceOrientation()
            return
        }
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()
    }

    @MainActor
    private func forcePortraitOrientation() {
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: [.portrait])
            windowScene.requestGeometryUpdate(prefs) { _ in }
            UIViewController.attemptRotationToDeviceOrientation()
            return
        }
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()
    }

    private static func parseHlsQualityOptions(urlString: String, headers: [String: String]) async -> [CollapsAVQualityOption] {
        guard urlString.lowercased().contains(".m3u8") else {
            return [CollapsAVQualityOption(index: 0, bitrate: 0, height: nil, label: "Auto", isAuto: true, url: nil)]
        }

        do {
            let body = try await fetchPlaylistText(urlString: urlString, headers: headers)
            let lines = body.components(separatedBy: .newlines)
            var options: [CollapsAVQualityOption] = []
            var streamInfoLine: String?
            var nextIndex = 1

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.lowercased().hasPrefix("#ext-x-stream-inf") {
                    streamInfoLine = trimmed
                    continue
                }
                if let info = streamInfoLine, !trimmed.isEmpty, !trimmed.hasPrefix("#") {
                    let height = parseHeight(from: info)
                    let bitrate = parseBitrate(from: info)
                    let codecs = parseCodecs(from: info).lowercased()
                    if codecs.contains("av01") {
                        streamInfoLine = nil
                        continue
                    }
                    let absoluteURL = URL(string: trimmed, relativeTo: URL(string: urlString))?.absoluteURL.absoluteString
                    let label: String
                    if let height {
                        label = "\(height)p"
                    } else if let bitrate {
                        label = "\(Int(bitrate / 1000)) kbps"
                    } else {
                        label = "Variant \(nextIndex)"
                    }

                    options.append(
                        CollapsAVQualityOption(
                            index: nextIndex,
                            bitrate: bitrate ?? 0,
                            height: height,
                            label: label,
                            isAuto: false,
                            url: absoluteURL
                        )
                    )
                    nextIndex += 1
                    streamInfoLine = nil
                }
            }

            let unique = Dictionary(grouping: options, by: { "\($0.height ?? -1)-\($0.bitrate)" })
                .compactMap { $0.value.first }
                .sorted { lhs, rhs in
                    let l = lhs.height ?? 0
                    let r = rhs.height ?? 0
                    if l == r { return lhs.bitrate > rhs.bitrate }
                    return l > r
                }

            var result: [CollapsAVQualityOption] = [
                CollapsAVQualityOption(index: 0, bitrate: 0, height: nil, label: "Auto", isAuto: true, url: nil)
            ]
            for (offset, item) in unique.enumerated() {
                result.append(
                    CollapsAVQualityOption(
                        index: offset + 1,
                        bitrate: item.bitrate,
                        height: item.height,
                        label: item.label,
                        isAuto: false,
                        url: item.url
                    )
                )
            }
            return result
        } catch {
            return [CollapsAVQualityOption(index: 0, bitrate: 0, height: nil, label: "Auto", isAuto: true, url: nil)]
        }
    }

    private static func fetchPlaylistText(urlString: String, headers: [String: String]) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        if request.value(forHTTPHeaderField: "Referer") == nil {
            request.setValue(headers["referer"], forHTTPHeaderField: "Referer")
        }
        if request.value(forHTTPHeaderField: "Origin") == nil {
            request.setValue(headers["origin"], forHTTPHeaderField: "Origin")
        }
        if request.value(forHTTPHeaderField: "User-Agent") == nil {
            request.setValue(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36",
                forHTTPHeaderField: "User-Agent"
            )
        }
        if request.value(forHTTPHeaderField: "Accept") == nil {
            request.setValue("*/*", forHTTPHeaderField: "Accept")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let text = String(data: data, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        return text
    }

    private func awaitFetchMaster(url: String, headers: [String: String]) throws -> String {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<String, Error> = .failure(URLError(.cannotLoadFromNetwork))
        Task {
            do {
                let text = try await CollapsHTTPClient.fetch(
                    url: url,
                    referer: headers["Referer"] ?? headers["referer"],
                    origin: headers["Origin"] ?? headers["origin"]
                )
                result = .success(text)
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()
        return try result.get()
    }

    private static func parseHeight(from streamInf: String) -> Int? {
        let pattern = #"RESOLUTION=\d+x(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: streamInf, options: [], range: NSRange(streamInf.startIndex..., in: streamInf)),
              let range = Range(match.range(at: 1), in: streamInf) else {
            return nil
        }
        return Int(streamInf[range])
    }

    private static func parseBitrate(from streamInf: String) -> Double? {
        let pattern = #"BANDWIDTH=(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: streamInf, options: [], range: NSRange(streamInf.startIndex..., in: streamInf)),
              let range = Range(match.range(at: 1), in: streamInf) else {
            return nil
        }
        return Double(streamInf[range])
    }

    private static func parseCodecs(from streamInf: String) -> String {
        let pattern = #"CODECS=\"([^\"]+)\""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: streamInf, options: [], range: NSRange(streamInf.startIndex..., in: streamInf)),
              let range = Range(match.range(at: 1), in: streamInf) else {
            return ""
        }
        return String(streamInf[range])
    }

    private static func heightFromQualityLabel(_ label: String) -> Int? {
        let pattern = #"(\d{3,4})p"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: label, options: [], range: NSRange(label.startIndex..., in: label)),
              let range = Range(match.range(at: 1), in: label) else {
            return nil
        }
        return Int(label[range])
    }

    private func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let base = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController

        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }

    private func refreshOverlayUI() {
        guard let vc = playerVC else { return }
        let state = snapshot()
        let duration = max(state.durationSec, 0)
        let current = min(max(state.currentTimeSec, 0), duration > 0 ? duration : state.currentTimeSec)
        let item = playlist.indices.contains(currentIndex) ? playlist[currentIndex] : nil
        let rawTitle = (item?.title.isEmpty == false) ? item!.title : "NeoMovies"
        let title = normalizedOverlayLabel(rawTitle, fallback: "NeoMovies")
        let subtitle: String
        if let season = item?.season, let episode = item?.episode {
            subtitle = "Season \(season), Episode \(episode)"
        } else {
            subtitle = "NeoMovies"
        }
        let audioLabel = currentAudioTrackLabel()
        let qualityLabel = currentQualityOptions.first(where: { $0.index == selectedQualityIndex })?.label ?? "Auto"
        let useEpisodeNav = !isCustomAllohaVoiceoverPlaylist
        Task { @MainActor in
            vc.updateOverlay(
                title: title,
                subtitle: subtitle,
                isPlaying: state.isPlaying,
                currentTime: current,
                duration: duration,
                audioLabel: audioLabel,
                qualityLabel: qualityLabel,
                canGoPreviousEpisode: useEpisodeNav && currentIndex > 0,
                canGoNextEpisode: useEpisodeNav && currentIndex < playlist.count - 1
            )
        }
    }

    private func currentAudioTrackLabel() -> String {
        if let current = playlist[safe: currentIndex], !current.audioVariants.isEmpty {
            let selected = selectedAudioVariantIndexByMediaId[current.mediaId] ?? 0
            if current.audioVariants.indices.contains(selected) {
                return normalizedOverlayLabel(current.audioVariants[selected].title, fallback: "Audio")
            }
            return "Audio"
        }

        if isCustomAllohaVoiceoverPlaylist {
            guard playlist.indices.contains(currentIndex) else { return "Audio" }
            return normalizedOverlayLabel(playlist[currentIndex].title, fallback: "Audio")
        }
        guard let item = player.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
            return "Audio"
        }
        if let selected = item.currentMediaSelection.selectedMediaOption(in: group) {
            return normalizedOverlayLabel(selected.displayName, fallback: "Audio")
        }
        return "Audio"
    }

    private func normalizedOverlayLabel(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        // Remove leading "(Lang)" prefix and collapse extra spaces.
        let noLangPrefix = trimmed.replacingOccurrences(of: #"^\([^)]*\)\s*"#, with: "", options: .regularExpression)
        let compact = noLangPrefix.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        if compact.isEmpty { return fallback }
        // Keep chip/title compact to avoid layout breakage.
        return String(compact.prefix(42))
    }
}
