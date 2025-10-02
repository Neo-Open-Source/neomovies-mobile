import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:neomovies_mobile/data/models/player/video_source.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebPlayerWidget extends StatefulWidget {
  final VideoSource source;
  final String? mediaId;

  const WebPlayerWidget({
    super.key,
    required this.source,
    required this.mediaId,
  });

  @override
  State<WebPlayerWidget> createState() => _WebPlayerWidgetState();
}

class _WebPlayerWidgetState extends State<WebPlayerWidget>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;
  bool _isDisposed = false;
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  
  // Performance optimization flags
  bool _hasInitialized = false;
  String? _lastLoadedUrl;
  
  // Keep alive for better performance
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeWebView();
  }

  void _initializeWebView() {
    if (widget.mediaId == null || widget.mediaId!.isEmpty) {
      setState(() {
        _error = 'Ошибка: IMDB ID не предоставлен.';
        _isLoading = false;
      });
      return;
    }

    final playerUrl = '${dotenv.env['API_URL']}/players/${widget.source.id}?imdb_id=${widget.mediaId}';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(widget.source.id == 'lumex'
          ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36'
          : 'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                // Сбрасываем ошибку, если страница загрузилась
                _error = null;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            // Показываем ошибку только если это главный фрейм (основная страница),
            // иначе игнорируем ошибки под-ресурсов (картинок, шрифтов и т.-д.).
            if ((error.isForMainFrame ?? false) && mounted) {
              setState(() {
                _error = 'Ошибка загрузки: ${error.description}';
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(playerUrl));
  }

  @override
  void didUpdateWidget(WebPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reload player if source or media changed
    if (oldWidget.source != widget.source || oldWidget.mediaId != widget.mediaId) {
      _initializeWebView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // WebView
          WebViewWidget(controller: _controller),
          
          // Индикатор загрузки поверх WebView
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Загрузка плеера...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          
          // Показываем ошибку
          if (_error != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initializeWebView,
                    child: const Text('Повторить'),
                  ),
                  const SizedBox(height: 8),
                  // Debug info
                  if (widget.mediaId != null && widget.mediaId!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Debug Info:',
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'IMDB ID: ${widget.mediaId}',
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            'Source: ${widget.source.name}',
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            'Player URL: ${dotenv.env['API_URL']}/players/${widget.source.id}?imdb_id=${widget.mediaId}',
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}