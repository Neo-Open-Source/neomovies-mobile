import Foundation

public struct CollapsAVTrack: Codable {
    public let index: Int
    public let id: String
    public let label: String
    public let language: String

    public func asDictionary() -> [String: Any] {
        [
            "index": index,
            "id": id,
            "label": label,
            "language": language
        ]
    }
}

public struct CollapsAVQualityOption: Codable {
    public let index: Int
    public let bitrate: Double
    public let height: Int?
    public let label: String
    public let isAuto: Bool

    public func asDictionary() -> [String: Any] {
        [
            "index": index,
            "bitrate": bitrate,
            "height": height as Any,
            "label": label,
            "isAuto": isAuto
        ]
    }
}

public struct CollapsAVPlayerState: Codable {
    public let isLoaded: Bool
    public let isPlaying: Bool
    public let rate: Float
    public let currentTimeSec: Double
    public let durationSec: Double
    public let currentIndex: Int
    public let totalItems: Int
    public let season: Int?
    public let episode: Int?
    public let mediaId: String?

    public func asDictionary() -> [String: Any] {
        [
            "isLoaded": isLoaded,
            "isPlaying": isPlaying,
            "rate": rate,
            "currentTimeSec": currentTimeSec,
            "durationSec": durationSec,
            "currentIndex": currentIndex,
            "totalItems": totalItems,
            "season": season as Any,
            "episode": episode as Any,
            "mediaId": mediaId as Any
        ]
    }
}

public struct CollapsAVPlaylistItem {
    public let mediaId: String
    public let title: String
    public let url: String
    public let headers: [String: String]
    public let season: Int?
    public let episode: Int?
    public let voiceovers: [String]
    public let subtitles: [CollapsSubtitle]

    public init(
        mediaId: String,
        title: String,
        url: String,
        headers: [String: String],
        season: Int?,
        episode: Int?,
        voiceovers: [String] = [],
        subtitles: [CollapsSubtitle] = []
    ) {
        self.mediaId = mediaId
        self.title = title
        self.url = url
        self.headers = headers
        self.season = season
        self.episode = episode
        self.voiceovers = voiceovers
        self.subtitles = subtitles
    }
}
