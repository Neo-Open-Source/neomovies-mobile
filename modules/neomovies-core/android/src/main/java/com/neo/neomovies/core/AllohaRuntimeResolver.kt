package com.neo.neomovies.core

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.URL
import java.util.Locale

internal class AllohaRuntimeResolver(private val context: Context) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var webView: WebView? = null
    private var finished = false
    private val headers = linkedMapOf<String, String>()
    private val pendingPayloads = ArrayDeque<String>()
    private var bestMasterPayload: String? = null
    private var bestHlsSourcePayload: String? = null
    private var bestDirectPayload: String? = null
    private var baseUrl: String? = null
    private var deferred: CompletableDeferred<Map<String, Any>>? = null
    private var timeoutRunnable: Runnable? = null
    private var fallbackRunnable: Runnable? = null

    suspend fun resolve(iframeUrl: String): Map<String, Any> {
        URL(iframeUrl)
        baseUrl = iframeUrl
        val waiter = CompletableDeferred<Map<String, Any>>()
        deferred = waiter
        withContext(Dispatchers.Main) { start(iframeUrl) }
        return waiter.await()
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun start(iframeUrl: String) {
        val wv = WebView(context)
        webView = wv
        wv.settings.javaScriptEnabled = true
        wv.settings.domStorageEnabled = true
        wv.settings.mediaPlaybackRequiresUserGesture = false
        wv.settings.allowFileAccess = false
        wv.settings.allowContentAccess = false
        wv.addJavascriptInterface(Bridge(), "AndroidAllohaResolver")
        wv.webChromeClient = WebChromeClient()
        wv.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean = false
        }
        startTimeout()
        wv.loadDataWithBaseURL(iframeUrl, wrapperHtml(iframeUrl), "text/html", "UTF-8", iframeUrl)
    }

    private fun startTimeout() {
        val timeout = Runnable {
            if (!finished) finishError("Alloha runtime parser did not return playable URL (timeout)")
        }
        timeoutRunnable = timeout
        mainHandler.postDelayed(timeout, 20_000)
    }

    private inner class Bridge {
        @JavascriptInterface
        fun post(raw: String?) {
            if (raw.isNullOrBlank() || finished) return
            runCatching {
                val obj = JSONObject(raw)
                val incomingHeaders = obj.optJSONObject("headers")
                if (incomingHeaders != null) {
                    val keys = incomingHeaders.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        headers[key.lowercase(Locale.ROOT)] = incomingHeaders.optString(key)
                    }
                    resolveBestPayloadIfReady()
                }

                val payload = obj.optString("payload")
                if (payload.isBlank()) return@runCatching
                pendingPayloads.addLast(payload)
                while (pendingPayloads.size > 12) pendingPayloads.removeFirst()

                if (isMasterPlaylistPayload(payload)) {
                    bestMasterPayload = payload
                    scheduleFallbackResolve(payload, if (bestHlsSourcePayload == null) 2400L else 800L)
                    return@runCatching
                }

                resolveIfReady(payload)
            }
        }
    }

    private fun resolveIfReady(payload: String) {
        if (finished) return
        when {
            payload.contains("hlsSource") -> {
                bestHlsSourcePayload = payload
                scheduleFallbackResolve(payload, if (hasAllohaPlaybackHeaders()) 3000L else 3800L)
            }
            isPlayablePayload(payload) -> {
                bestDirectPayload = payload
                scheduleFallbackResolve(payload, 5000L)
            }
        }
    }

    private fun resolveBestPayloadIfReady() {
        if (finished) return
        if (hasAllohaPlaybackHeaders() && (bestHlsSourcePayload != null || bestMasterPayload != null)) {
            resolveBestAvailablePayload(bestHlsSourcePayload ?: bestMasterPayload.orEmpty())
        }
    }

    private fun resolveBestAvailablePayload(fallback: String) {
        val base = baseUrl ?: return
        val payloads = listOfNotNull(bestHlsSourcePayload, bestMasterPayload, bestDirectPayload, fallback.ifBlank { null })
        val seen = mutableSetOf<String>()
        for (payload in payloads) {
            if (!seen.add(payload)) continue
            val parsed = AllohaRuntimeParser.parsePayload(payload, base, headers) ?: emptyMap()
            val variants = (parsed["audioVariants"] as? List<*>)?.mapNotNull { raw ->
                val item = raw as? Map<*, *> ?: return@mapNotNull null
                val url = item["url"] as? String ?: return@mapNotNull null
                if (url.isBlank()) return@mapNotNull null
                val title = (item["title"] as? String)?.trim().orEmpty().ifBlank { "Unknown" }
                mapOf("title" to title, "url" to url)
            }.orEmpty()
            val variantUrl = variants.firstOrNull()?.get("url")
            if (!variantUrl.isNullOrBlank()) {
                finishOk(mapOf("url" to variantUrl, "subtitles" to (parsed["subtitles"] ?: emptyList<Any>()), "audioVariants" to variants))
                return
            }
            val direct = parsed["videoURL"] as? String
            if (!direct.isNullOrBlank()) {
                finishOk(mapOf("url" to direct, "subtitles" to (parsed["subtitles"] ?: emptyList<Any>()), "audioVariants" to emptyList<Any>()))
                return
            }
        }
    }

    private fun scheduleFallbackResolve(payload: String, delayMs: Long) {
        fallbackRunnable?.let { mainHandler.removeCallbacks(it) }
        val task = Runnable {
            if (!finished) resolveBestAvailablePayload(payload)
        }
        fallbackRunnable = task
        mainHandler.postDelayed(task, delayMs)
    }

    private fun hasAllohaPlaybackHeaders(): Boolean = !headers["authorizations"].isNullOrBlank()

    private fun isMasterPlaylistPayload(payload: String): Boolean = payload.contains("master.m3u8", ignoreCase = true)

    private fun isPlayablePayload(payload: String): Boolean {
        val lower = payload.lowercase(Locale.ROOT)
        return lower.contains(".m3u8") || lower.contains(".mp4") || lower.contains(".mpd")
    }

    private fun finishOk(result: Map<String, Any>) {
        if (finished) return
        finished = true
        cleanup()
        deferred?.complete(result)
        deferred = null
    }

    private fun finishError(message: String) {
        if (finished) return
        finished = true
        cleanup()
        deferred?.completeExceptionally(Exception(message))
        deferred = null
    }

    private fun cleanup() {
        timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        fallbackRunnable?.let { mainHandler.removeCallbacks(it) }
        timeoutRunnable = null
        fallbackRunnable = null
        val view = webView
        webView = null
        if (view != null) {
            mainHandler.post {
                runCatching {
                    view.stopLoading()
                    view.removeJavascriptInterface("AndroidAllohaResolver")
                    view.webViewClient = WebViewClient()
                    view.webChromeClient = WebChromeClient()
                    view.destroy()
                }
            }
        }
    }

    private fun wrapperHtml(url: String): String {
        return """
        <!doctype html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
            <style>html, body, iframe { margin:0; width:100%; height:100%; background:#000; overflow:hidden; }</style>
        </head>
        <body>
            <iframe id="alloha_iframe" src="$url" allow="autoplay; fullscreen; encrypted-media; picture-in-picture" allowfullscreen frameborder="0"></iframe>
            <script>
            (function() {
              if (window.__neoAllohaResolverInstalled) return;
              window.__neoAllohaResolverInstalled = true;
              var capturedHeaders = {};
              var lastPayload = '';
              var lastM3u8 = '';
              function post(type, payload) {
                try {
                  AndroidAllohaResolver.post(JSON.stringify({ type: type, payload: payload || '', headers: capturedHeaders }));
                } catch(e) {}
              }
              function putHeader(name, value) {
                if (!name || !value) return;
                capturedHeaders[String(name).toLowerCase()] = String(value);
              }
              function defaultHeaders(win) {
                try {
                  putHeader('origin', win.location.origin);
                  putHeader('referer', win.location.origin + '/');
                  putHeader('user-agent', win.navigator.userAgent);
                  putHeader('accept', '*/*');
                  putHeader('sec-fetch-dest', 'empty');
                  putHeader('sec-fetch-mode', 'cors');
                  putHeader('sec-fetch-site', 'cross-site');
                } catch(e) {}
              }
              function looksPlayable(text) {
                return typeof text === 'string' && (
                  text.indexOf('hlsSource') !== -1 ||
                  text.indexOf('.m3u8') !== -1 ||
                  text.indexOf('.mp4') !== -1 ||
                  text.indexOf('.vtt') !== -1
                );
              }
              function report(payload) {
                if (!looksPlayable(payload)) return;
                if (payload === lastPayload) return;
                lastPayload = payload;
                post('payload', payload);
              }
              function scan(win) {
                try {
                  defaultHeaders(win);
                  var chunks = [];
                  if (win.location && win.location.href) chunks.push(win.location.href);
                  if (win.document && win.document.documentElement) chunks.push(win.document.documentElement.outerHTML);
                  var media = win.document ? win.document.querySelectorAll('video, source, track') : [];
                  for (var i = 0; i < media.length; i++) chunks.push(media[i].currentSrc || media[i].src || media[i].getAttribute('src') || '');
                  if (win.performance && win.performance.getEntriesByType) {
                    var entries = win.performance.getEntriesByType('resource');
                    for (var p = 0; p < entries.length; p++) chunks.push(entries[p].name || '');
                  }
                  report(chunks.join('\n'));
                } catch(e) {}
              }
              function install(win) {
                try {
                  if (!win || win.__neoAllohaHooksInstalled) return;
                  win.__neoAllohaHooksInstalled = true;
                  defaultHeaders(win);
                  var originalOpen = win.XMLHttpRequest && win.XMLHttpRequest.prototype.open;
                  var originalSetHeader = win.XMLHttpRequest && win.XMLHttpRequest.prototype.setRequestHeader;
                  if (originalOpen && originalSetHeader) {
                    win.XMLHttpRequest.prototype.open = function(method, requestUrl) {
                      this.__neoAllohaUrl = requestUrl || '';
                      this.addEventListener('load', function() {
                        var responseUrl = this.responseURL || this.__neoAllohaUrl || '';
                        var responseText = '';
                        try { responseText = this.responseText || ''; } catch(e) {}
                        if (responseUrl.indexOf('/bnsi/') !== -1 && responseText) report(responseText);
                        if (looksPlayable(responseText)) report(responseText);
                        if (responseUrl.indexOf('master.m3u8') !== -1 && responseUrl !== lastM3u8) { lastM3u8 = responseUrl; post('payload', responseUrl); }
                      });
                      return originalOpen.apply(this, arguments);
                    };
                    win.XMLHttpRequest.prototype.setRequestHeader = function(name, value) {
                      putHeader(name, value);
                      return originalSetHeader.apply(this, arguments);
                    };
                  }
                  var originalFetch = win.fetch;
                  if (originalFetch) {
                    win.fetch = function(input, init) {
                      try {
                        var requestUrl = (typeof input === 'string') ? input : (input && input.url ? input.url : '');
                        if (init && init.headers) {
                          if (typeof init.headers.forEach === 'function') init.headers.forEach(function(value, name) { putHeader(name, value); });
                          else for (var key in init.headers) putHeader(key, init.headers[key]);
                        }
                        if (input && input.headers && typeof input.headers.forEach === 'function') input.headers.forEach(function(value, name) { putHeader(name, value); });
                        if (looksPlayable(requestUrl)) post('payload', requestUrl);
                      } catch(e) {}
                      return originalFetch.apply(this, arguments).then(function(response) {
                        try {
                          var responseUrl = response.url || '';
                          if (looksPlayable(responseUrl)) post('payload', responseUrl);
                          var clone = response.clone();
                          clone.text().then(function(text) { report(text); }).catch(function(){});
                        } catch(e) {}
                        return response;
                      });
                    };
                  }
                  var originalSend = win.WebSocket && win.WebSocket.prototype.send;
                  if (originalSend) {
                    win.WebSocket.prototype.send = function(data) {
                      if (!this.__neoAllohaWsHooked) {
                        this.__neoAllohaWsHooked = true;
                        this.addEventListener('message', function(event) {
                          try {
                            var msg = JSON.parse(event.data);
                            if (msg && msg.edge_hash) { putHeader('authorizations', msg.edge_hash); post('headers', ''); }
                          } catch(e) {}
                        });
                      }
                      return originalSend.apply(this, arguments);
                    };
                  }
                } catch(e) {}
              }
              function tick() {
                install(window);
                scan(window);
                try {
                  var frames = document.querySelectorAll('iframe');
                  for (var i = 0; i < frames.length; i++) { install(frames[i].contentWindow); scan(frames[i].contentWindow); }
                } catch(e) {}
              }
              tick();
              setInterval(tick, 700);
              window.addEventListener('load', tick);
            })();
            </script>
        </body>
        </html>
        """.trimIndent()
    }
}
