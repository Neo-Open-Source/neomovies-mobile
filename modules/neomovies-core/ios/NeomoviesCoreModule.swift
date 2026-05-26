import ExpoModulesCore
import Foundation

public class NeomoviesCoreModule: Module {
  private var didBindPlayerCallbacks = false

  public func definition() -> ModuleDefinition {
    Name("NeomoviesCore")
    Events("onAVPlayerStateChanged", "onAVPlayerProgress", "onAVPlayerEpisodeChanged")

    Function("parseCollapsCatalog") { (embedHtml: String) -> [String: Any] in
      return CollapsParser.parseCollapsCatalog(embedHtml: embedHtml)
    }

    Function("parseAllohaRuntimePayload") { (payload: String, baseUrl: String, headers: [String: String]) -> [String: Any] in
      return AllohaRuntimeParser.parsePayload(payload, baseURL: baseUrl, headers: headers) ?? [:]
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

    AsyncFunction("fetchUrlTextInsecure") { (url: String, referer: String?, origin: String?) -> String in
      return try await CollapsHTTPClient.fetchInsecure(
        url: url,
        referer: referer,
        origin: origin
      )
    }

    AsyncFunction("fetchAllohaSeriesCatalog") { (kpId: String, token: String) -> [String: Any] in
      let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
      let encodedKp = kpId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? kpId
      let url = "https://api.alloha.tv/?token=\(encodedToken)&kp=\(encodedKp)"
      let body = try await CollapsHTTPClient.fetchInsecure(
        url: url,
        referer: "https://api.alloha.tv/",
        origin: "https://api.alloha.tv"
      )
      guard
        let data = body.data(using: .utf8),
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let payload = json["data"] as? [String: Any]
      else { return [:] }

      let seasonsAny = payload["seasons"]
      let seasonsObj: [String: Any]
      if let dict = seasonsAny as? [String: Any] {
        seasonsObj = dict
      } else if let nsDict = seasonsAny as? NSDictionary {
        seasonsObj = nsDict as? [String: Any] ?? [:]
      } else {
        seasonsObj = [:]
      }
      if seasonsObj.isEmpty { return [:] }

      func intFromAny(_ value: Any?, fallback: Int = 1) -> Int {
        if let n = value as? Int { return n }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String, let n = Int(s) { return n }
        return fallback
      }

      func firstIframe(from translationAny: Any?) -> String? {
        let translationObj: [String: Any]
        if let dict = translationAny as? [String: Any] {
          translationObj = dict
        } else if let nsDict = translationAny as? NSDictionary {
          translationObj = nsDict as? [String: Any] ?? [:]
        } else {
          translationObj = [:]
        }
        for (_, transRaw) in translationObj {
          if let transMap = transRaw as? [String: Any],
             let iframe = transMap["iframe"] as? String,
             !iframe.isEmpty {
            return iframe
          }
          if let ns = transRaw as? NSDictionary,
             let iframe = ns["iframe"] as? String,
             !iframe.isEmpty {
            return iframe
          }
        }
        return nil
      }

      var seasons: [[String: Any]] = []
      for (seasonKey, seasonRaw) in seasonsObj {
        let seasonMap: [String: Any]
        if let dict = seasonRaw as? [String: Any] {
          seasonMap = dict
        } else if let nsDict = seasonRaw as? NSDictionary {
          seasonMap = nsDict as? [String: Any] ?? [:]
        } else {
          seasonMap = [:]
        }
        if seasonMap.isEmpty { continue }

        let seasonNum = intFromAny(seasonMap["season"] ?? seasonKey, fallback: Int(seasonKey) ?? 1)
        let episodesAny = seasonMap["episodes"]
        let episodesObj: [String: Any]
        if let dict = episodesAny as? [String: Any] {
          episodesObj = dict
        } else if let nsDict = episodesAny as? NSDictionary {
          episodesObj = nsDict as? [String: Any] ?? [:]
        } else {
          episodesObj = [:]
        }

        var episodes: [[String: Any]] = []
        for (episodeKey, episodeRaw) in episodesObj {
          let episodeMap: [String: Any]
          if let dict = episodeRaw as? [String: Any] {
            episodeMap = dict
          } else if let nsDict = episodeRaw as? NSDictionary {
            episodeMap = nsDict as? [String: Any] ?? [:]
          } else {
            episodeMap = [:]
          }
          if episodeMap.isEmpty { continue }

          let episodeNum = intFromAny(episodeMap["episode"] ?? episodeKey, fallback: Int(episodeKey) ?? 1)
          let iframe = firstIframe(from: episodeMap["translation"])
            ?? (episodeMap["iframe"] as? String)
          guard let iframe, !iframe.isEmpty else { continue }

          episodes.append([
            "season": seasonNum,
            "episode": episodeNum,
            "title": "Episode \(episodeNum)",
            "playlist": [
              "primaryUrl": iframe,
              "hlsUrl": NSNull(),
              "dashUrl": NSNull(),
              "voiceovers": [],
              "subtitles": []
            ]
          ])
        }

        // Fallback: if season has no explicit episodes, still expose season-level iframe as episode 1
        if episodes.isEmpty, let seasonIframe = seasonMap["iframe"] as? String, !seasonIframe.isEmpty {
          episodes.append([
            "season": seasonNum,
            "episode": 1,
            "title": "Episode 1",
            "playlist": [
              "primaryUrl": seasonIframe,
              "hlsUrl": NSNull(),
              "dashUrl": NSNull(),
              "voiceovers": [],
              "subtitles": []
            ]
          ])
        }

        let sorted = episodes.sorted { (($0["episode"] as? Int) ?? 0) < (($1["episode"] as? Int) ?? 0) }
        if !sorted.isEmpty {
          seasons.append([
            "season": seasonNum,
            "title": "Season \(seasonNum)",
            "episodes": sorted
          ])
        }
      }
      let sortedSeasons = seasons.sorted { (($0["season"] as? Int) ?? 0) < (($1["season"] as? Int) ?? 0) }
      if sortedSeasons.isEmpty { return [:] }
      return ["kind": "series", "source": "alloha", "seasons": sortedSeasons]
    }

    AsyncFunction("resolveAllohaPlayableFromIframe") { (iframeUrl: String) -> [String: Any] in
      var visited = Set<String>()
      var currentUrl = iframeUrl
      var lastReason = "unknown"

      for _ in 0..<3 {
        if visited.contains(currentUrl) { break }
        visited.insert(currentUrl)
        guard let current = URL(string: currentUrl) else { break }
        let origin = "\(current.scheme ?? "https")://\(current.host ?? "")"
        let html = try await CollapsHTTPClient.fetchInsecure(
          url: currentUrl,
          referer: "\(origin)/",
          origin: origin
        )

        let parsed = AllohaRuntimeParser.parsePayload(html, baseURL: origin, headers: [
          "Referer": "\(origin)/",
          "Origin": origin
        ]) ?? [:]
        if let variants = parsed["audioVariants"] as? [[String: Any]] {
          if let url = variants.first(where: { (($0["url"] as? String) ?? "").isEmpty == false })?["url"] as? String {
            return ["url": url, "subtitles": parsed["subtitles"] ?? []]
          }
        }
        if let url = parsed["videoURL"] as? String, !url.isEmpty {
          return ["url": url, "subtitles": parsed["subtitles"] ?? []]
        }

        let patterns = [
          #"https?:\\\/\\\/[^\"'\s>]+\.(m3u8|mpd)[^\"'\s>]*"#,
          #"https?://[^\"'\s>]+\.(m3u8|mpd)[^\"'\s>]*"#,
        ]
        for pattern in patterns {
          if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            if let m = regex.firstMatch(in: html, options: [], range: nsrange),
               let range = Range(m.range, in: html) {
              let raw = String(html[range]).replacingOccurrences(of: "\\/", with: "/")
              let resolved = URL(string: raw, relativeTo: URL(string: origin))?.absoluteString ?? raw
              return ["url": resolved, "subtitles": parsed["subtitles"] ?? []]
            }
          }
        }

        if let iframeRegex = try? NSRegularExpression(pattern: #"<iframe[^>]+src=["']([^"']+)["']"#, options: [.caseInsensitive]) {
          let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
          if let m = iframeRegex.firstMatch(in: html, options: [], range: nsrange),
             let range = Range(m.range(at: 1), in: html) {
            let nested = String(html[range])
            currentUrl = URL(string: nested, relativeTo: URL(string: currentUrl))?.absoluteString ?? nested
            lastReason = "nested_iframe_followed"
            continue
          }
        }

        lastReason = "no_stream_no_iframe"
        break
      }

      throw NSError(domain: "NeomoviesCore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Alloha runtime parser did not return playable URL (\(lastReason))"])
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

    AsyncFunction("avPlayerConfigurePlaylist") { (items: [[String: Any]], startIndex: Int, autoplay: Bool, kpId: Int?) throws -> [String: Any] in
      print("[NeomoviesCore] avPlayerConfigurePlaylist called with kpId: \(kpId ?? -1), items: \(items.count), startIndex: \(startIndex)")
      if let kpId = kpId {
        print("[NeomoviesCore] Setting kpId: \(kpId)")
        CollapsAVPlayerController.shared.setKinopoiskId(kpId)
      } else {
        print("[NeomoviesCore] WARNING: kpId is nil!")
      }
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

    Function("getCollapsWatchProgress") { (kpId: Int, season: Int?, episode: Int?) -> [String: Any] in
      let store = CollapsPlaybackProgressStore.shared

      let lastSeason = store.loadLastSeason(kpId: kpId)
      let lastEpisode = store.loadLastEpisode(kpId: kpId)

      let resolvedSeason = season ?? lastSeason
      let resolvedEpisode = episode ?? lastEpisode

      let mediaId: String
      if let s = resolvedSeason, let e = resolvedEpisode {
        mediaId = "kp_\(kpId)_s\(s)_e\(e)"
      } else {
        mediaId = "kp_\(kpId)"
      }

      let positionMs = Int(store.load(mediaId: mediaId) * 1000)
      let durationMs = Int(store.loadDuration(mediaId: mediaId) * 1000)
      let watched = store.loadWatched(mediaId: mediaId)
      let updatedAtMs = store.loadUpdatedAtMs(mediaId: mediaId)
      let progressPercent = durationMs > 0 ? Int(Double(positionMs) / Double(durationMs) * 100.0) : 0

      let lastMediaId: String
      if let ls = lastSeason, let le = lastEpisode {
        lastMediaId = "kp_\(kpId)_s\(ls)_e\(le)"
      } else {
        lastMediaId = "kp_\(kpId)"
      }
      let lastPositionMs = Int(store.load(mediaId: lastMediaId) * 1000)
      let lastDurationMs = Int(store.loadDuration(mediaId: lastMediaId) * 1000)
      let lastUpdatedAtMs = store.loadUpdatedAtMs(mediaId: lastMediaId)

      func opt(_ v: Int?) -> Any { v.map { $0 as Any } ?? NSNull() }

      return [
        "schemaVersion": 1,
        "source": "collaps",
        "mediaId": mediaId,
        "kpId": kpId,
        "season": opt(resolvedSeason),
        "episode": opt(resolvedEpisode),
        "kind": (resolvedSeason != nil && resolvedEpisode != nil) ? "episode" : "movie_or_generic",
        "positionMs": positionMs,
        "durationMs": durationMs,
        "progressPercent": progressPercent,
        "watched": watched,
        "updatedAtMs": updatedAtMs,
        "lastSeason": opt(lastSeason),
        "lastEpisode": opt(lastEpisode),
        "lastPositionMs": lastPositionMs,
        "lastDurationMs": lastDurationMs,
        "lastUpdatedAtMs": lastUpdatedAtMs,
      ]
    }

    Function("listCollapsWatchProgressRecords") { (kpId: Int?) -> [[String: Any]] in
      let store = CollapsPlaybackProgressStore.shared
      let allDefaults = UserDefaults.standard.dictionaryRepresentation()
      let prefix = store.positionKeyPrefix
      guard let regex = try? NSRegularExpression(pattern: "^kp_(\\d+)_s(\\d+)_e(\\d+)$") else { return [] }

      var records: [[String: Any]] = []
      for key in allDefaults.keys {
        guard key.hasPrefix(prefix) else { continue }
        let mediaId = String(key.dropFirst(prefix.count))
        let range = NSRange(mediaId.startIndex..., in: mediaId)
        guard let match = regex.firstMatch(in: mediaId, range: range) else { continue }
        guard
          let kidRange = Range(match.range(at: 1), in: mediaId),
          let sRange   = Range(match.range(at: 2), in: mediaId),
          let eRange   = Range(match.range(at: 3), in: mediaId),
          let itemKpId = Int(mediaId[kidRange]),
          let season   = Int(mediaId[sRange]),
          let episode  = Int(mediaId[eRange])
        else { continue }

        if let kpId = kpId, itemKpId != kpId { continue }

        let positionMs   = Int(store.load(mediaId: mediaId) * 1000)
        let durationMs   = Int(store.loadDuration(mediaId: mediaId) * 1000)
        let watched      = store.loadWatched(mediaId: mediaId)
        let updatedAtMs  = store.loadUpdatedAtMs(mediaId: mediaId)
        let progressPercent = durationMs > 0 ? Int(Double(positionMs) / Double(durationMs) * 100.0) : 0

        records.append([
          "schemaVersion": 1,
          "source": "collaps",
          "mediaId": mediaId,
          "kpId": itemKpId,
          "season": season,
          "episode": episode,
          "kind": "episode",
          "positionMs": positionMs,
          "durationMs": durationMs,
          "progressPercent": progressPercent,
          "watched": watched,
          "updatedAtMs": updatedAtMs,
        ])
      }

      return records.sorted { ($0["updatedAtMs"] as? Int ?? 0) > ($1["updatedAtMs"] as? Int ?? 0) }
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
