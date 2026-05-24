import Foundation

public class CollapsHlsRewriter {
    public static func rewrite(
        master: String,
        voices: [String],
        subtitles: [CollapsSubtitle] = [],
        mediaId: String,
        rewriteVariantUris: Bool = true,
        stripExistingSubtitles: Bool = false
    ) -> String {
        guard !master.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return master
        }
        
        let lines = master.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        
        var output: [String] = []
        let subsGroupId = "subs0"
        
        // Filter out failover duplicates
        let filteredLines = filterFailoverDuplicates(lines: lines)
        
        // Find first STREAM-INF index
        let streamInfIndex = filteredLines.firstIndex { $0.hasPrefix("#EXT-X-STREAM-INF") } ?? filteredLines.count
        
        // Process header (before STREAM-INF)
        for i in 0..<streamInfIndex {
            let line = filteredLines[i]
            if stripExistingSubtitles && isSubtitleMediaLine(line) {
                continue
            }
            output.append(rewriteMediaLine(line, voices: voices))
        }
        
        // Inject subtitles
        if !subtitles.isEmpty {
            for sub in subtitles {
                let lang = sub.language.isEmpty ? "ru" : sub.language
                let label = sub.label.isEmpty ? "Subtitle" : sub.label
                let uri = sub.url
                guard !uri.isEmpty else { continue }
                
                output.append("#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID=\"\(subsGroupId)\",NAME=\"\(escapeAttr(label))\",DEFAULT=NO,AUTOSELECT=YES,LANGUAGE=\"\(escapeAttr(lang))\",URI=\"\(escapeAttr(uri))\"")
            }
        }
        
        // Process variants and rewrite URIs with proper naming
        var variantIndex = 0
        for i in streamInfIndex..<filteredLines.count {
            let line = filteredLines[i]
            
            if line.hasPrefix("#EXT-X-STREAM-INF") {
                var modifiedLine = line
                if !subtitles.isEmpty {
                    modifiedLine = addOrReplaceAttribute(modifiedLine, key: "SUBTITLES", value: subsGroupId)
                }
                output.append(modifiedLine)
            } else if !line.hasPrefix("#") && !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // This is a variant URI - rewrite it with proper naming
                if rewriteVariantUris {
                    let newUri = "\(mediaId)_\(variantIndex).m3u8"
                    output.append(newUri)
                } else {
                    output.append(line)
                }
                variantIndex += 1
            } else {
                output.append(line)
            }
        }
        
        return output.joined(separator: "\n")
    }
    
    private static func filterFailoverDuplicates(lines: [String]) -> [String] {
        var filtered: [String] = []
        var seenVariantKeys = Set<String>()
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            
            // Skip failover MEDIA renditions
            if line.hasPrefix("#EXT-X-MEDIA") {
                if let groupId = extractQuotedAttr(line, key: "GROUP-ID"),
                   groupId.lowercased().hasPrefix("failover-") {
                    i += 1
                    continue
                }
                filtered.append(line)
                i += 1
                continue
            }
            
            // Skip failover STREAM-INF variants
            if line.hasPrefix("#EXT-X-STREAM-INF") {
                if let audioGroup = extractQuotedAttr(line, key: "AUDIO"),
                   audioGroup.lowercased().hasPrefix("failover-") {
                    i += 2 // Skip STREAM-INF and following URI
                    continue
                }
                
                // Deduplicate variants by resolution/codecs/audio
                let resolution = extractAttrValue(line, key: "RESOLUTION")
                let codecs = extractQuotedAttr(line, key: "CODECS")
                let audioGroup = extractQuotedAttr(line, key: "AUDIO")
                let key = [resolution, codecs, audioGroup].compactMap { $0 }.joined(separator: "|")
                
                if !key.isEmpty && !seenVariantKeys.insert(key).inserted {
                    i += 2 // Skip duplicate variant
                    continue
                }
                
                filtered.append(line)
                if i + 1 < lines.count {
                    filtered.append(lines[i + 1]) // URI line
                }
                i += 2
                continue
            }
            
            filtered.append(line)
            i += 1
        }
        
        return filtered
    }
    
    private static func rewriteMediaLine(_ line: String, voices: [String]) -> String {
        guard line.hasPrefix("#EXT-X-MEDIA") else { return line }
        guard line.contains("TYPE=AUDIO") else { return line }
        
        // Extract NAME attribute
        guard let rawName = extractQuotedAttr(line, key: "NAME") else { return line }
        
        // Try to extract voice index from NAME (e.g., "rus0", "ru1")
        let pattern = "^(?:rus|ru)(\\d+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: rawName, options: [], range: NSRange(rawName.startIndex..., in: rawName)),
              let indexRange = Range(match.range(at: 1), in: rawName),
              let index = Int(rawName[indexRange]),
              index < voices.count else {
            return line
        }
        
        let voiceName = voices[index]
        
        // Determine language
        let normalizedLang: String
        if voiceName.lowercased().contains("eng") || voiceName.lowercased().contains("original") {
            normalizedLang = "en"
        } else {
            normalizedLang = "ru"
        }
        
        var output = addOrReplaceAttribute(line, key: "NAME", value: voiceName)
        output = addOrReplaceAttribute(output, key: "LANGUAGE", value: normalizedLang)
        
        return output
    }

    private static func isSubtitleMediaLine(_ line: String) -> Bool {
        guard line.hasPrefix("#EXT-X-MEDIA") else { return false }
        let upper = line.uppercased()
        return upper.contains("TYPE=SUBTITLES") || upper.contains("TYPE=CLOSED-CAPTIONS")
    }
    
    private static func addOrReplaceAttribute(_ line: String, key: String, value: String) -> String {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: key))=\"([^\"]*)\""
        let escapedValue = escapeAttr(value)
        let newAttr = "\(key)=\"\(escapedValue)\""
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) != nil {
            return regex.stringByReplacingMatches(in: line, options: [], range: NSRange(line.startIndex..., in: line), withTemplate: newAttr)
        } else {
            // Insert after tag name
            if let colonIndex = line.firstIndex(of: ":") {
                let prefix = line[...colonIndex]
                let rest = line[line.index(after: colonIndex)...]
                return "\(prefix)\(newAttr),\(rest)"
            } else {
                return "\(line),\(newAttr)"
            }
        }
    }
    
    private static func extractQuotedAttr(_ line: String, key: String) -> String? {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: key))=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return String(line[range])
    }
    
    private static func extractAttrValue(_ line: String, key: String) -> String? {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: key))=([^,\\s]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return String(line[range])
    }
    
    private static func escapeAttr(_ s: String) -> String {
        return s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
