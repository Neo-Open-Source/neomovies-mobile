import Foundation

public final class CollapsPlaybackProgressStore {
    public static let shared = CollapsPlaybackProgressStore()
    private let defaults = UserDefaults.standard
    private let prefix = "neomovies.collaps.progress."

    private init() {}

    public func save(mediaId: String, positionSec: Double) {
        guard !mediaId.isEmpty, positionSec.isFinite, positionSec >= 0 else { return }
        defaults.set(positionSec, forKey: key(for: mediaId))
        defaults.synchronize()
    }

    public func load(mediaId: String) -> Double {
        guard !mediaId.isEmpty else { return 0 }
        return defaults.double(forKey: key(for: mediaId))
    }

    private func key(for mediaId: String) -> String {
        "\(prefix)\(mediaId)"
    }
}
