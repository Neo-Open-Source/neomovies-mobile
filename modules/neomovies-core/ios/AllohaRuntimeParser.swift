import Foundation

enum AllohaRuntimeParser {
    static func parsePayload(_ payload: String, baseURL: String, headers: [String: String]) -> [String: Any]? {
        guard let url = URL(string: baseURL) else { return nil }

        if let stream = parseAllohaBNsiStream(payload, baseURL: url, headers: headers) {
            return stream
        }

        if let fallback = firstPreferredStreamURL(in: payload, baseURL: url) {
            return [
                "videoURL": fallback.absoluteString,
                "audioTracks": [],
                "audioVariants": [],
                "subtitles": subtitleTracks(in: payload, baseURL: url),
                "qualityVariants": [],
                "httpHeaders": headers
            ]
        }

        return nil
    }

    private static func parseAllohaBNsiStream(_ payload: String, baseURL: URL, headers: [String: String]) -> [String: Any]? {
        let candidates = [payload] + embeddedJSONObjectCandidates(in: payload)

        for candidate in candidates {
            guard let data = candidate.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let source = object["hlsSource"] as? [[String: Any]] else {
                continue
            }

            var qualityVariants: [[String: Any]] = []
            var audioVariants: [[String: Any]] = []
            var masterURL: URL?

            for (index, item) in source.enumerated() {
                guard let quality = item["quality"] as? [String: Any] else { continue }
                var itemVariants: [[String: Any]] = []
                var itemMasterURL: URL?

                for (label, rawValue) in quality {
                    for rawURL in qualityURLStrings(from: rawValue) {
                        let urls = allohaURLs(from: rawURL, baseURL: baseURL)
                        if masterURL == nil {
                            masterURL = urls.first(where: { $0.lastPathComponent.lowercased().contains("master.m3u8") })
                        }
                        if itemMasterURL == nil {
                            itemMasterURL = urls.first(where: { $0.lastPathComponent.lowercased().contains("master.m3u8") })
                        }
                        guard let target = urls.first(where: { !$0.lastPathComponent.lowercased().contains("master.m3u8") }) ?? urls.first else {
                            continue
                        }

                        let variant: [String: Any] = [
                            "label": normalizedQualityLabel(label),
                            "bandwidth": NSNull(),
                            "resolution": NSNull(),
                            "url": target.absoluteString
                        ]
                        itemVariants.append(variant)
                        qualityVariants.append(variant)
                    }
                }

                let chosenAudioURL = itemMasterURL ?? itemVariants.last.flatMap { URL(string: ($0["url"] as? String) ?? "") }
                if let chosenAudioURL {
                    audioVariants.append([
                        "id": "\(index)-\(chosenAudioURL.absoluteString)",
                        "title": audioVariantTitle(from: item, index: index),
                        "url": chosenAudioURL.absoluteString,
                        "qualityVariants": itemVariants
                    ])
                }
            }

            let deduplicatedAudioVariants = deduplicatedAudioVariants(audioVariants)
            let firstURL = deduplicatedAudioVariants.first?["url"] as? String
            let pickedURL = firstURL ?? masterURL?.absoluteString ?? (qualityVariants.last?["url"] as? String)
            guard let pickedURL else { continue }

            return [
                "videoURL": pickedURL,
                "audioTracks": [],
                "audioVariants": deduplicatedAudioVariants,
                "subtitles": subtitleTracks(in: payload, baseURL: baseURL),
                "qualityVariants": qualityVariants,
                "httpHeaders": headers
            ]
        }

        return nil
    }

    private static func deduplicatedAudioVariants(_ variants: [[String: Any]]) -> [[String: Any]] {
        var seen = Set<String>()
        return variants.filter { variant in
            let key = variant["url"] as? String ?? ""
            return seen.insert(key).inserted
        }
    }

    private static func audioVariantTitle(from item: [String: Any], index: Int) -> String {
        if let title = (item["translation"] as? [String: Any])?["name"] as? String, !title.isEmpty {
            return title
        }
        if let title = item["title"] as? String, !title.isEmpty {
            return title
        }
        return "Озвучка \(index + 1)"
    }

    private static func qualityURLStrings(from value: Any) -> [String] {
        if let string = value as? String {
            return string
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        if let values = value as? [Any] {
            return values.flatMap { qualityURLStrings(from: $0) }
        }
        return []
    }

    private static func allohaURLs(from raw: String, baseURL: URL) -> [URL] {
        let decoded = raw.replacingOccurrences(of: "\\/", with: "/")
        let parts = decoded.components(separatedBy: " or ")
        return parts.compactMap { part in
            let clean = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.hasPrefix("//") {
                return URL(string: "https:\(clean)")
            }
            return URL(string: clean, relativeTo: baseURL)?.absoluteURL
        }
    }

    private static func normalizedQualityLabel(_ label: String) -> String {
        let clean = label.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "Auto" : clean
    }

    private static func firstPreferredStreamURL(in payload: String, baseURL: URL) -> URL? {
        let pattern = #"https?:\\/\\/[^\"'\s>]+\\.(m3u8|mpd)[^\"'\s>]*"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(payload.startIndex..<payload.endIndex, in: payload)
        guard let match = regex.firstMatch(in: payload, options: [], range: range),
              let matchRange = Range(match.range(at: 0), in: payload) else {
            return nil
        }
        let value = String(payload[matchRange]).replacingOccurrences(of: "\\/", with: "/")
        return URL(string: value, relativeTo: baseURL)?.absoluteURL
    }

    private static func subtitleTracks(in payload: String, baseURL: URL) -> [[String: Any]] {
        let pattern = #"https?:\\/\\/[^\"'\s>]+\\.(vtt|srt)[^\"'\s>]*"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(payload.startIndex..<payload.endIndex, in: payload)
        return regex.matches(in: payload, options: [], range: range).compactMap { match in
            guard let matchRange = Range(match.range(at: 0), in: payload) else { return nil }
            let value = String(payload[matchRange]).replacingOccurrences(of: "\\/", with: "/")
            guard let url = URL(string: value, relativeTo: baseURL)?.absoluteURL else { return nil }
            return ["url": url.absoluteString, "label": "Subtitle", "language": "ru"]
        }
    }

    private static func embeddedJSONObjectCandidates(in payload: String) -> [String] {
        var candidates = balancedJSONObjectCandidates(containing: #"\"hlsSource\""#, in: payload)
        candidates.append(contentsOf: balancedJSONObjectCandidates(containing: "hlsSource", in: payload))
        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    private static func balancedJSONObjectCandidates(containing marker: String, in payload: String) -> [String] {
        var candidates: [String] = []
        var searchStart = payload.startIndex
        while let markerRange = payload.range(of: marker, options: [.caseInsensitive], range: searchStart..<payload.endIndex) {
            guard let objectStart = payload[..<markerRange.lowerBound].lastIndex(of: "{"),
                  let objectEnd = balancedObjectEnd(from: objectStart, in: payload) else {
                searchStart = markerRange.upperBound
                continue
            }
            candidates.append(String(payload[objectStart...objectEnd]))
            searchStart = markerRange.upperBound
        }
        return candidates
    }

    private static func balancedObjectEnd(from start: String.Index, in payload: String) -> String.Index? {
        var depth = 0
        var quoted = false
        var escaped = false
        var index = start
        while index < payload.endIndex {
            let char = payload[index]
            if escaped {
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "\"" {
                quoted.toggle()
            } else if !quoted {
                if char == "{" {
                    depth += 1
                } else if char == "}" {
                    depth -= 1
                    if depth == 0 { return index }
                }
            }
            index = payload.index(after: index)
        }
        return nil
    }
}
