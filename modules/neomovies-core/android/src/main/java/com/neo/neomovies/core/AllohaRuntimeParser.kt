package com.neo.neomovies.core

import org.json.JSONArray
import org.json.JSONObject
import java.net.URI

object AllohaRuntimeParser {

    fun parsePayload(payload: String, baseUrl: String, headers: Map<String, String>): Map<String, Any>? {
        val uri = try { URI(baseUrl) } catch (e: Exception) { return null }

        parseAllohaBNsiStream(payload, uri, headers)?.let { return it }

        firstPreferredStreamURL(payload, uri)?.let { fallback ->
            return mapOf(
                "videoURL" to fallback,
                "audioTracks" to emptyList<Any>(),
                "audioVariants" to emptyList<Any>(),
                "subtitles" to subtitleTracks(payload, uri),
                "qualityVariants" to emptyList<Any>(),
                "httpHeaders" to headers
            )
        }

        return null
    }

    private fun parseAllohaBNsiStream(payload: String, baseUrl: URI, headers: Map<String, String>): Map<String, Any>? {
        val candidates = listOf(payload) + embeddedJSONObjectCandidates(payload)

        for (candidate in candidates) {
            val obj = try { JSONObject(candidate) } catch (e: Exception) { continue }
            val source = try { obj.getJSONArray("hlsSource") } catch (e: Exception) { continue }

            val qualityVariants = mutableListOf<Map<String, Any?>>()
            val audioVariants = mutableListOf<Map<String, Any?>>()
            var masterURL: String? = null

            for (i in 0 until source.length()) {
                val item = try { source.getJSONObject(i) } catch (e: Exception) { continue }
                val quality = try { item.getJSONObject("quality") } catch (e: Exception) { continue }

                val itemVariants = mutableListOf<Map<String, Any?>>()
                var itemMasterURL: String? = null

                for (label in quality.keys()) {
                    val rawValue = quality.get(label)
                    for (rawURL in qualityURLStrings(rawValue)) {
                        val urls = allohaURLs(rawURL, baseUrl)
                        if (masterURL == null) masterURL = urls.firstOrNull { isMasterM3u8(it) }
                        if (itemMasterURL == null) itemMasterURL = urls.firstOrNull { isMasterM3u8(it) }
                        val target = urls.firstOrNull { !isMasterM3u8(it) } ?: urls.firstOrNull() ?: continue

                        val variant: Map<String, Any?> = mapOf(
                            "label" to normalizedQualityLabel(label),
                            "bandwidth" to null,
                            "resolution" to null,
                            "url" to target
                        )
                        itemVariants.add(variant)
                        qualityVariants.add(variant)
                    }
                }

                val chosenURL = itemMasterURL ?: (itemVariants.lastOrNull()?.get("url") as? String)
                if (chosenURL != null) {
                    audioVariants.add(mapOf(
                        "id" to "$i-$chosenURL",
                        "title" to audioVariantTitle(item, i),
                        "url" to chosenURL,
                        "qualityVariants" to itemVariants
                    ))
                }
            }

            val deduped = deduplicatedAudioVariants(audioVariants)
            val pickedURL = (deduped.firstOrNull()?.get("url") as? String)
                ?: masterURL
                ?: (qualityVariants.lastOrNull()?.get("url") as? String)
            pickedURL ?: continue

            return mapOf(
                "videoURL" to pickedURL,
                "audioTracks" to emptyList<Any>(),
                "audioVariants" to deduped,
                "subtitles" to subtitleTracks(payload, baseUrl),
                "qualityVariants" to qualityVariants,
                "httpHeaders" to headers
            )
        }

        return null
    }

    private fun isMasterM3u8(url: String): Boolean {
        val path = url.substringAfterLast("/").substringBefore("?").lowercase()
        return path.contains("master.m3u8")
    }

    private fun deduplicatedAudioVariants(variants: List<Map<String, Any?>>): List<Map<String, Any?>> {
        val seen = mutableSetOf<String>()
        return variants.filter { variant ->
            val key = variant["url"] as? String ?: ""
            seen.add(key)
        }
    }

    private fun audioVariantTitle(item: JSONObject, index: Int): String {
        item.optJSONObject("translation")?.optString("name")
            ?.takeIf { it.isNotEmpty() }?.let { return it }

        for (key in listOf("translationName", "translation_name", "translator", "studio", "voice", "voiceover", "dub", "dubbing", "name", "title", "label")) {
            item.optString(key).takeIf { it.isNotEmpty() && it != "null" }?.let { return it }
        }

        return "Озвучка ${index + 1}"
    }

    private fun qualityURLStrings(value: Any): List<String> {
        return when (value) {
            is String -> value.split(",").map { it.trim() }.filter { it.isNotEmpty() }
            is JSONArray -> (0 until value.length()).flatMap { qualityURLStrings(value.get(it)) }
            else -> emptyList()
        }
    }

    private fun allohaURLs(raw: String, baseUrl: URI): List<String> {
        val decoded = raw.replace("\\/", "/")
        return decoded.split(" or ").mapNotNull { part ->
            val clean = part.trim()
            when {
                clean.startsWith("//") -> "https:$clean"
                clean.startsWith("http://") || clean.startsWith("https://") -> clean
                else -> runCatching { baseUrl.resolve(clean).toString() }.getOrNull()
            }
        }
    }

    private fun normalizedQualityLabel(label: String): String {
        val clean = label.replace("_", " ").trim()
        return if (clean.isEmpty()) "Auto" else clean
    }

    private fun firstPreferredStreamURL(payload: String, baseUrl: URI): String? {
        val pattern = Regex("""https?:\\/\\/[^\"'\s>]+\.(m3u8|mpd)[^\"'\s>]*""", RegexOption.IGNORE_CASE)
        val match = pattern.find(payload) ?: return null
        val value = match.value.replace("\\/", "/")
        return runCatching { baseUrl.resolve(value).toString() }.getOrDefault(value)
    }

    private fun subtitleTracks(payload: String, baseUrl: URI): List<Map<String, String>> {
        val pattern = Regex("""https?:\\/\\/[^\"'\s>]+\.(vtt|srt)[^\"'\s>]*""", RegexOption.IGNORE_CASE)
        return pattern.findAll(payload).mapNotNull { match ->
            val value = match.value.replace("\\/", "/")
            val url = runCatching { baseUrl.resolve(value).toString() }.getOrDefault(value)
            mapOf("url" to url, "label" to "Subtitle", "language" to "ru")
        }.toList()
    }

    private fun embeddedJSONObjectCandidates(payload: String): List<String> {
        val candidates = mutableListOf<String>()
        candidates.addAll(balancedJSONObjectCandidates("\"hlsSource\"", payload))
        candidates.addAll(balancedJSONObjectCandidates("hlsSource", payload))
        return candidates.distinct()
    }

    private fun balancedJSONObjectCandidates(marker: String, payload: String): List<String> {
        val candidates = mutableListOf<String>()
        var searchStart = 0
        while (true) {
            val markerIndex = payload.indexOf(marker, searchStart, ignoreCase = true)
            if (markerIndex < 0) break
            val objectStart = payload.lastIndexOf('{', markerIndex)
            if (objectStart < 0) {
                searchStart = markerIndex + marker.length
                continue
            }
            val objectEnd = balancedObjectEnd(objectStart, payload)
            if (objectEnd < 0) {
                searchStart = markerIndex + marker.length
                continue
            }
            candidates.add(payload.substring(objectStart, objectEnd + 1))
            searchStart = markerIndex + marker.length
        }
        return candidates
    }

    private fun balancedObjectEnd(start: Int, payload: String): Int {
        var depth = 0
        var quoted = false
        var escaped = false
        var i = start
        while (i < payload.length) {
            when {
                escaped -> escaped = false
                payload[i] == '\\' -> escaped = true
                payload[i] == '"' -> quoted = !quoted
                !quoted && payload[i] == '{' -> depth++
                !quoted && payload[i] == '}' -> {
                    depth--
                    if (depth == 0) return i
                }
            }
            i++
        }
        return -1
    }
}
