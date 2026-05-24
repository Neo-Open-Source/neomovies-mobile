import ExpoModulesCore

public class NeomoviesCoreModule: Module {
  private var didBindPlayerCallbacks = false

  public func definition() -> ModuleDefinition {
    Name("NeomoviesCore")
    Events("onAVPlayerStateChanged", "onAVPlayerProgress", "onAVPlayerEpisodeChanged")

    Function("parseCollapsCatalog") { (embedHtml: String) -> [String: Any] in
      return CollapsParser.parseCollapsCatalog(embedHtml: embedHtml)
    }

    Function("rewriteCollapsHlsMaster") { (master: String, voices: [String], subtitles: [[String: String]], mediaId: String) -> String in
      let parsedSubtitles = subtitles.map { dict -> CollapsSubtitle in
        CollapsSubtitle(
          url: dict["url"] ?? "",
          label: dict["label"] ?? "",
          language: dict["language"] ?? ""
        )
      }
      return CollapsHlsRewriter.rewrite(
        master: master,
        voices: voices,
        subtitles: parsedSubtitles,
        mediaId: mediaId
      )
    }

    Function("rewriteCollapsDashManifest") { (manifest: String, voices: [String], subtitles: [[String: String]], mediaId: String) -> String in
      let parsedSubtitles = subtitles.map { dict -> CollapsSubtitle in
        CollapsSubtitle(
          url: dict["url"] ?? "",
          label: dict["label"] ?? "",
          language: dict["language"] ?? ""
        )
      }
      return CollapsDashRewriter.rewrite(
        manifest: manifest,
        voices: voices,
        subtitles: parsedSubtitles,
        mediaId: mediaId
      )
    }

    AsyncFunction("rewriteCollapsHlsFromUrl") { (hlsUrl: String, voices: [String], subtitles: [[String: String]], mediaId: String, referer: String?, origin: String?) -> String in
      let parsedSubtitles = subtitles.map { dict -> CollapsSubtitle in
        CollapsSubtitle(
          url: dict["url"] ?? "",
          label: dict["label"] ?? "",
          language: dict["language"] ?? ""
        )
      }
      
      let masterPlaylist = try await CollapsHTTPClient.fetch(
        url: hlsUrl,
        referer: referer,
        origin: origin
      )
      
      return CollapsHlsRewriter.rewrite(
        master: masterPlaylist,
        voices: voices,
        subtitles: parsedSubtitles,
        mediaId: mediaId
      )
    }

    AsyncFunction("rewriteCollapsDashFromUrl") { (dashUrl: String, voices: [String], subtitles: [[String: String]], mediaId: String, referer: String?, origin: String?) -> String in
      let parsedSubtitles = subtitles.map { dict -> CollapsSubtitle in
        CollapsSubtitle(
          url: dict["url"] ?? "",
          label: dict["label"] ?? "",
          language: dict["language"] ?? ""
        )
      }
      
      let manifest = try await CollapsHTTPClient.fetch(
        url: dashUrl,
        referer: referer,
        origin: origin
      )
      
      return CollapsDashRewriter.rewrite(
        manifest: manifest,
        voices: voices,
        subtitles: parsedSubtitles,
        mediaId: mediaId
      )
    }

    OnCreate {
      self.bindPlayerCallbacksIfNeeded()
    }

    AsyncFunction("avPlayerLoad") { (url: String, headers: [String: String], autoplay: Bool, startPositionSec: Double?) throws -> [String: Any] in
      let item = CollapsAVPlaylistItem(
        mediaId: url,
        title: "",
        url: url,
        headers: headers,
        season: nil,
        episode: nil,
        voiceovers: [],
        subtitles: []
      )
      _ = try CollapsAVPlayerController.shared.configurePlaylist(items: [item], startIndex: 0, autoplay: autoplay)
      if let startPositionSec {
        _ = CollapsAVPlayerController.shared.seek(to: startPositionSec)
      }
      return CollapsAVPlayerController.shared.snapshot().asDictionary()
    }

    AsyncFunction("avPlayerConfigurePlaylist") { (items: [[String: Any]], startIndex: Int, autoplay: Bool) throws -> [String: Any] in
      let playlist = items.compactMap { dict -> CollapsAVPlaylistItem? in
        guard let url = dict["url"] as? String, !url.isEmpty else { return nil }
        let mediaId = (dict["mediaId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return CollapsAVPlaylistItem(
          mediaId: (mediaId?.isEmpty == false) ? mediaId! : url,
          title: dict["title"] as? String ?? "",
          url: url,
          headers: dict["headers"] as? [String: String] ?? [:],
          season: dict["season"] as? Int,
          episode: dict["episode"] as? Int,
          voiceovers: dict["voiceovers"] as? [String] ?? [],
          subtitles: (dict["subtitles"] as? [[String: String]] ?? []).map {
            CollapsSubtitle(
              url: $0["url"] ?? "",
              label: $0["label"] ?? "",
              language: $0["language"] ?? ""
            )
          }
        )
      }
      let state = try CollapsAVPlayerController.shared.configurePlaylist(items: playlist, startIndex: startIndex, autoplay: autoplay)
      return state.asDictionary()
    }

    AsyncFunction("avPlayerPresentNativeUI") { () async in
      await MainActor.run {
        CollapsAVPlayerController.shared.presentNativePlayer()
      }
    }

    AsyncFunction("avPlayerDismissNativeUI") { () async in
      await MainActor.run {
        CollapsAVPlayerController.shared.dismissNativePlayer()
      }
    }

    AsyncFunction("avPlayerSelectEpisode") { (index: Int, autoplay: Bool) throws -> [String: Any] in
      let state = try CollapsAVPlayerController.shared.selectEpisode(index: index, autoplay: autoplay)
      return state.asDictionary()
    }

    AsyncFunction("avPlayerNextEpisode") { (autoplay: Bool) throws -> [String: Any] in
      let state = try CollapsAVPlayerController.shared.nextEpisode(autoplay: autoplay)
      return state.asDictionary()
    }

    AsyncFunction("avPlayerPreviousEpisode") { (autoplay: Bool) throws -> [String: Any] in
      let state = try CollapsAVPlayerController.shared.previousEpisode(autoplay: autoplay)
      return state.asDictionary()
    }

    Function("avPlayerPlay") { () -> [String: Any] in
      CollapsAVPlayerController.shared.play().asDictionary()
    }

    Function("avPlayerPause") { () -> [String: Any] in
      CollapsAVPlayerController.shared.pause().asDictionary()
    }

    Function("avPlayerStop") { () in
      CollapsAVPlayerController.shared.stop()
    }

    Function("avPlayerSeek") { (positionSec: Double) -> [String: Any] in
      CollapsAVPlayerController.shared.seek(to: positionSec).asDictionary()
    }

    Function("avPlayerSetRate") { (rate: Double) -> [String: Any] in
      CollapsAVPlayerController.shared.setRate(Float(rate)).asDictionary()
    }

    Function("avPlayerSetPreferredPeakBitRate") { (bitrate: Double) in
      CollapsAVPlayerController.shared.setPreferredPeakBitRate(bitrate)
    }

    AsyncFunction("avPlayerRefreshQualityOptions") { () async -> [[String: Any]] in
      await CollapsAVPlayerController.shared.refreshQualityOptions()
    }

    Function("avPlayerListQualityOptions") { () -> [[String: Any]] in
      CollapsAVPlayerController.shared.listQualityOptions()
    }

    Function("avPlayerSelectQuality") { (index: Int?) in
      CollapsAVPlayerController.shared.selectQuality(index: index)
    }

    Function("avPlayerSnapshot") { () -> [String: Any] in
      CollapsAVPlayerController.shared.snapshot().asDictionary()
    }

    Function("avPlayerListAudioTracks") { () -> [[String: Any]] in
      return CollapsAVPlayerController.shared.listAudioTracks()
    }

    Function("avPlayerSelectAudioTrack") { (index: Int?) in
      CollapsAVPlayerController.shared.selectAudioTrack(index: index)
    }

    Function("avPlayerListSubtitleTracks") { () -> [[String: Any]] in
      return CollapsAVPlayerController.shared.listSubtitleTracks()
    }

    Function("avPlayerSelectSubtitleTrack") { (index: Int?) in
      CollapsAVPlayerController.shared.selectSubtitleTrack(index: index)
    }
  }

  private func bindPlayerCallbacksIfNeeded() {
    if didBindPlayerCallbacks { return }
    didBindPlayerCallbacks = true

    CollapsAVPlayerController.shared.onStateChanged = { [weak self] state in
      self?.sendEvent("onAVPlayerStateChanged", state.asDictionary())
    }
    CollapsAVPlayerController.shared.onProgress = { [weak self] state in
      self?.sendEvent("onAVPlayerProgress", state.asDictionary())
    }
    CollapsAVPlayerController.shared.onEpisodeChanged = { [weak self] state in
      self?.sendEvent("onAVPlayerEpisodeChanged", state.asDictionary())
    }
  }
}
