import Foundation
import AVFoundation

/// Manages audio track selection for AVPlayer
final class CollapsAVAudioManager {
    
    // MARK: - Dependencies
    
    private weak var player: AVPlayer?
    
    // MARK: - State
    
    private(set) var selectedAudioVariantIndexByMediaId: [String: Int] = [:]
    private(set) var isCustomAllohaVoiceoverPlaylist: Bool = false
    private(set) var playlist: [CollapsAVPlaylistItem] = []
    private(set) var currentIndex: Int = 0
    
    // MARK: - Initialization
    
    init(player: AVPlayer) {
        self.player = player
    }
    
    // MARK: - Public API
    
    /// Updates the playlist state
    func updatePlaylist(_ playlist: [CollapsAVPlaylistItem], currentIndex: Int) {
        self.playlist = playlist
        self.currentIndex = currentIndex
        self.isCustomAllohaVoiceoverPlaylist = Self.checkIsCustomAllohaVoiceoverPlaylist(playlist)
    }
    
    /// Lists available audio tracks
    func listAudioTracks(normalizedOverlayLabel: (String, String) -> String) -> [[String: Any]] {
        if let current = playlist[safe: currentIndex], !current.audioVariants.isEmpty {
            return current.audioVariants.enumerated().map { index, variant in
                CollapsAVTrack(
                    index: index,
                    id: "alloha-\(index)",
                    label: normalizedOverlayLabel(variant.title, "Unknown"),
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

        guard let group = player?.currentItem?.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
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
    
    /// Selects an audio track by index
    func selectAudioTrack(index: Int?, emitState: @escaping () -> Void) {
        if let current = playlist[safe: currentIndex], !current.audioVariants.isEmpty {
            guard let index, index >= 0, index < current.audioVariants.count else { return }
            selectedAudioVariantIndexByMediaId[current.mediaId] = index
            emitState()
            return
        }

        if isCustomAllohaVoiceoverPlaylist {
            guard let index, index >= 0, index < playlist.count else { return }
            if index == currentIndex { return }
            // Note: Episode selection would need to be handled by caller
            return
        }

        guard let item = player?.currentItem,
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
    
    /// Lists available subtitle tracks
    func listSubtitleTracks() -> [[String: Any]] {
        guard let group = player?.currentItem?.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
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
    
    /// Selects a subtitle track by index
    func selectSubtitleTrack(index: Int?, emitState: @escaping () -> Void) {
        guard let item = player?.currentItem,
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
    
    /// Sets the selected audio variant index for a media ID
    func setSelectedAudioVariantIndex(_ index: Int, for mediaId: String) {
        selectedAudioVariantIndexByMediaId[mediaId] = index
    }
    
    /// Gets the current audio track label
    func currentAudioTrackLabel(normalizedOverlayLabel: (String, String) -> String) -> String {
        if let current = playlist[safe: currentIndex], !current.audioVariants.isEmpty {
            let selected = selectedAudioVariantIndexByMediaId[current.mediaId] ?? 0
            if current.audioVariants.indices.contains(selected) {
                return normalizedOverlayLabel(current.audioVariants[selected].title, "Audio")
            }
            return "Audio"
        }

        if isCustomAllohaVoiceoverPlaylist {
            guard playlist.indices.contains(currentIndex) else { return "Audio" }
            return normalizedOverlayLabel(playlist[currentIndex].title, "Audio")
        }
        guard let item = player?.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
            return "Audio"
        }
        if let selected = item.currentMediaSelection.selectedMediaOption(in: group) {
            return normalizedOverlayLabel(selected.displayName, "Audio")
        }
        return "Audio"
    }
    
    // MARK: - Private Helper Methods
    
    private static func checkIsCustomAllohaVoiceoverPlaylist(_ playlist: [CollapsAVPlaylistItem]) -> Bool {
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
}
