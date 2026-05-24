import AVFoundation
import AVKit
import Foundation
import UIKit

public final class CollapsAVPlayerController: NSObject {
    public static let shared = CollapsAVPlayerController()

    public var onStateChanged: ((CollapsAVPlayerState) -> Void)?
    public var onProgress: ((CollapsAVPlayerState) -> Void)?
    public var onEpisodeChanged: ((CollapsAVPlayerState) -> Void)?

    private let player = AVPlayer()
    private var playerVC: CollapsNativePlayerViewController?
    private var timeObserver: Any?
    private var currentBridge: CollapsAVAssetBridge?
    private var playlist: [CollapsAVPlaylistItem] = []
    private var currentIndex: Int = 0
    private var selectedQualityIndex: Int = 0
    private var currentQualityOptions: [CollapsAVQualityOption] = [
        CollapsAVQualityOption(index: 0, bitrate: 0, height: nil, label: "Auto", isAuto: true)
    ]

    private override init() {
        super.init()
        observeItemEnd()
        observeAppLifecycle()
    }

    deinit {
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
        currentBridge = nil
        playlist = []
        currentIndex = 0
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
            emitState()
            return
        }
        player.currentItem?.preferredPeakBitRate = option.isAuto ? 0 : option.bitrate
        selectedQualityIndex = option.index
        emitState()
    }

    public func refreshQualityOptions() async -> [[String: Any]] {
        guard playlist.indices.contains(currentIndex) else {
            currentQualityOptions = [CollapsAVQualityOption(index: 0, bitrate: 0, height: nil, label: "Auto", isAuto: true)]
            return listQualityOptions()
        }
        let current = playlist[currentIndex]
        currentQualityOptions = await Self.parseHlsQualityOptions(urlString: current.url, headers: current.headers)
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
        currentIndex = index
        selectedQualityIndex = 0
        try loadCurrentItem(autoplay: autoplay, overrideStartSec: nil)
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

    private func loadCurrentItem(autoplay: Bool, overrideStartSec: Double?) throws {
        guard playlist.indices.contains(currentIndex) else {
            throw NSError(domain: "NeomoviesCore", code: 1003, userInfo: [NSLocalizedDescriptionKey: "No current episode"])
        }
        guard let url = URL(string: playlist[currentIndex].url) else {
            throw URLError(.badURL)
        }

        let itemMeta = playlist[currentIndex]
        // Keep original master untouched for AVPlayer stability.
        // Runtime master rewrite can introduce subtle HLS parse incompatibilities (-12642 / -12860).
        currentBridge = CollapsAVAssetBridge(sourceURL: url, headers: itemMeta.headers, rewrittenMaster: nil)
        let playerItem = AVPlayerItem(asset: currentBridge!.asset)
        player.replaceCurrentItem(with: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        player.isMuted = false
        player.volume = 1.0

        let startAt = overrideStartSec ?? CollapsPlaybackProgressStore.shared.load(mediaId: itemMeta.mediaId)
        if startAt > 0 {
            player.seek(to: CMTime(seconds: startAt, preferredTimescale: 600))
        }

        installProgressObserver()

        if autoplay {
            player.play()
        }

        Task {
            _ = await refreshQualityOptions()
        }
        emitState()
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
                CollapsPlaybackProgressStore.shared.save(mediaId: mediaId, positionSec: state.currentTimeSec)
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
            do {
                currentIndex += 1
                try loadCurrentItem(autoplay: true, overrideStartSec: 0)
                onEpisodeChanged?(snapshot())
            } catch {
                emitState()
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
        CollapsPlaybackProgressStore.shared.save(mediaId: mediaId, positionSec: seconds)
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
        for track in tracks {
            let label = (track["label"] as? String) ?? "Track"
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
            return [CollapsAVQualityOption(index: 0, bitrate: 0, height: nil, label: "Auto", isAuto: true)]
        }

        do {
            let body = try await CollapsHTTPClient.fetch(
                url: urlString,
                referer: headers["Referer"] ?? headers["referer"],
                origin: headers["Origin"] ?? headers["origin"]
            )
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
                            isAuto: false
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
                CollapsAVQualityOption(index: 0, bitrate: 0, height: nil, label: "Auto", isAuto: true)
            ]
            for (offset, item) in unique.enumerated() {
                result.append(
                    CollapsAVQualityOption(
                        index: offset + 1,
                        bitrate: item.bitrate,
                        height: item.height,
                        label: item.label,
                        isAuto: false
                    )
                )
            }
            return result
        } catch {
            return [CollapsAVQualityOption(index: 0, bitrate: 0, height: nil, label: "Auto", isAuto: true)]
        }
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
        let title = (item?.title.isEmpty == false) ? item!.title : "NeoMovies"
        let subtitle = "Collaps"
        let audioLabel = currentAudioTrackLabel()
        let qualityLabel = currentQualityOptions.first(where: { $0.index == selectedQualityIndex })?.label ?? "Auto"
        Task { @MainActor in
            vc.updateOverlay(
                title: title,
                subtitle: subtitle,
                isPlaying: state.isPlaying,
                currentTime: current,
                duration: duration,
                audioLabel: audioLabel,
                qualityLabel: qualityLabel
            )
        }
    }

    private func currentAudioTrackLabel() -> String {
        guard let item = player.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
            return "Audio"
        }
        if let selected = item.currentMediaSelection.selectedMediaOption(in: group) {
            return selected.displayName
        }
        return "Audio"
    }
}

private final class CollapsNativePlayerViewController: AVPlayerViewController {
    var onWillDisappearCallback: (() -> Void)?
    var onCloseTapped: (() -> Void)?
    var onPlayPauseTapped: (() -> Void)?
    var onSeekRelative: ((Double) -> Void)?
    var onSliderSeek: ((Double) -> Void)?
    var onAudioTapped: ((UIView) -> Void)?
    var onQualityTapped: ((UIView) -> Void)?

    private let dimTop = CAGradientLayer()
    private let dimBottom = CAGradientLayer()
    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let rewindButton = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private let forwardButton = UIButton(type: .system)
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let progressSlider = UISlider()
    private let audioChip = UIButton(type: .system)
    private let qualityChip = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        buildOverlay()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        dimTop.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 150)
        dimBottom.frame = CGRect(x: 0, y: view.bounds.height - 220, width: view.bounds.width, height: 220)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onWillDisappearCallback?()
    }

    @MainActor
    func updateOverlay(title: String, subtitle: String, isPlaying: Bool, currentTime: Double, duration: Double, audioLabel: String, qualityLabel: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        playPauseButton.setImage(UIImage(systemName: isPlaying ? "pause.fill" : "play.fill"), for: .normal)
        currentTimeLabel.text = formatTime(currentTime)
        durationLabel.text = formatTime(duration)
        progressSlider.minimumValue = 0
        progressSlider.maximumValue = Float(max(duration, 0.1))
        progressSlider.value = Float(currentTime)
        audioChip.setTitle("  \(audioLabel)  ", for: .normal)
        qualityChip.setTitle("  \(qualityLabel)  ", for: .normal)
    }

    private func buildOverlay() {
        guard let overlay = contentOverlayView else { return }
        overlay.layer.addSublayer(dimTop)
        overlay.layer.addSublayer(dimBottom)
        dimTop.colors = [UIColor.black.withAlphaComponent(0.72).cgColor, UIColor.clear.cgColor]
        dimBottom.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.75).cgColor]

        closeButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        closeButton.layer.cornerRadius = 24
        closeButton.addAction(UIAction { [weak self] _ in self?.onCloseTapped?() }, for: .touchUpInside)

        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        subtitleLabel.textAlignment = .center

        configureCircleButton(rewindButton, symbol: "gobackward.10", size: 52)
        rewindButton.addAction(UIAction { [weak self] _ in self?.onSeekRelative?(-10) }, for: .touchUpInside)
        configureCircleButton(playPauseButton, symbol: "pause.fill", size: 84)
        playPauseButton.addAction(UIAction { [weak self] _ in self?.onPlayPauseTapped?() }, for: .touchUpInside)
        configureCircleButton(forwardButton, symbol: "goforward.10", size: 52)
        forwardButton.addAction(UIAction { [weak self] _ in self?.onSeekRelative?(10) }, for: .touchUpInside)

        currentTimeLabel.textColor = .white
        currentTimeLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        durationLabel.textColor = .white
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        durationLabel.textAlignment = .right

        progressSlider.minimumTrackTintColor = .white
        progressSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.22)
        progressSlider.addAction(UIAction { [weak self] _ in
            self?.onSliderSeek?(Double(self?.progressSlider.value ?? 0))
        }, for: .valueChanged)

        configureChip(audioChip, icon: "speaker.wave.2.fill")
        audioChip.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onAudioTapped?(self.audioChip)
        }, for: .touchUpInside)

        configureChip(qualityChip, icon: "slider.horizontal.3")
        qualityChip.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onQualityTapped?(self.qualityChip)
        }, for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        header.axis = .vertical
        header.spacing = 2

        let center = UIStackView(arrangedSubviews: [rewindButton, playPauseButton, forwardButton])
        center.axis = .horizontal
        center.alignment = .center
        center.spacing = 26

        let times = UIStackView(arrangedSubviews: [currentTimeLabel, progressSlider, durationLabel])
        times.axis = .horizontal
        times.alignment = .center
        times.spacing = 14

        let chips = UIStackView(arrangedSubviews: [audioChip, qualityChip])
        chips.axis = .horizontal
        chips.spacing = 14
        chips.alignment = .center

        [closeButton, header, center, times, chips].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            overlay.addSubview($0)
        }

        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 28),
            closeButton.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 28),
            closeButton.widthAnchor.constraint(equalToConstant: 48),
            closeButton.heightAnchor.constraint(equalToConstant: 48),

            header.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            header.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 28),

            center.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            center.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: 10),

            times.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 24),
            times.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -24),
            times.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -74),
            currentTimeLabel.widthAnchor.constraint(equalToConstant: 90),
            durationLabel.widthAnchor.constraint(equalToConstant: 90),

            chips.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            chips.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -26)
        ])
    }

    private func configureCircleButton(_ button: UIButton, symbol: String, size: CGFloat) {
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        button.layer.cornerRadius = size / 2
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: size),
            button.heightAnchor.constraint(equalToConstant: size)
        ])
    }

    private func configureChip(_ button: UIButton, icon: String) {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: icon)
        config.imagePadding = 8
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        button.configuration = config
        button.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        button.layer.cornerRadius = 24
    }

    private func formatTime(_ sec: Double) -> String {
        guard sec.isFinite else { return "0:00" }
        let total = Int(max(0, sec))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
