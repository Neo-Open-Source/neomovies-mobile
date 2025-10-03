import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:auto_route/auto_route.dart';
import '../../../data/services/player_embed_service.dart';

enum WebPlayerType { vibix, alloha }

@RoutePage()
class WebViewPlayerScreen extends StatefulWidget {
  final WebPlayerType playerType;
  final String videoUrl;
  final String title;

  const WebViewPlayerScreen({
    super.key,
    required this.playerType,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<WebViewPlayerScreen> createState() => _WebViewPlayerScreenState();
}

class _WebViewPlayerScreenState extends State<WebViewPlayerScreen> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isFullscreen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  @override
  void dispose() {
    _setOrientation(false);
    super.dispose();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading progress
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _error = null;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _error = 'Ошибка загрузки: ${error.description}';
              _isLoading = false;
            });
          },
        ),
      );

    _loadPlayer();
  }

  void _loadPlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final playerUrl = await _getPlayerUrl();
      _controller.loadRequest(Uri.parse(playerUrl));
    } catch (e) {
      setState(() {
        _error = 'Ошибка получения URL плеера: $e';
        _isLoading = false;
      });
    }
  }

  Future<String> _getPlayerUrl() async {
    switch (widget.playerType) {
      case WebPlayerType.vibix:
        return await _getVibixUrl();
      case WebPlayerType.alloha:
        return await _getAllohaUrl();
    }
  }

  Future<String> _getVibixUrl() async {
    try {
      // Try to get embed URL from API server first
      return await PlayerEmbedService.getVibixEmbedUrl(
        videoUrl: widget.videoUrl,
        title: widget.title,
      );
    } catch (e) {
      // Fallback to direct URL if server is unavailable
      final encodedVideoUrl = Uri.encodeComponent(widget.videoUrl);
      return 'https://vibix.me/embed/?src=$encodedVideoUrl&autoplay=1&title=${Uri.encodeComponent(widget.title)}';
    }
  }

  Future<String> _getAllohaUrl() async {
    try {
      // Try to get embed URL from API server first
      return await PlayerEmbedService.getAllohaEmbedUrl(
        videoUrl: widget.videoUrl,
        title: widget.title,
      );
    } catch (e) {
      // Fallback to direct URL if server is unavailable
      final encodedVideoUrl = Uri.encodeComponent(widget.videoUrl);
      return 'https://alloha.tv/embed?src=$encodedVideoUrl&autoplay=1&title=${Uri.encodeComponent(widget.title)}';
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    _setOrientation(_isFullscreen);
  }

  void _setOrientation(bool isFullscreen) {
    if (isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  String _getPlayerName() {
    switch (widget.playerType) {
      case WebPlayerType.vibix:
        return 'Vibix';
      case WebPlayerType.alloha:
        return 'Alloha';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullscreen ? null : AppBar(
        title: Text(
          '${_getPlayerName()} - ${widget.title}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              color: Colors.white,
            ),
            onPressed: _toggleFullscreen,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'reload',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Перезагрузить'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('Поделиться'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildErrorState();
    }

    return Stack(
      children: [
        // WebView
        WebViewWidget(controller: _controller),
        
        // Loading indicator
        if (_isLoading)
          Container(
            color: Colors.black,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Загрузка плеера...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Fullscreen toggle for when player is loaded
        if (!_isLoading && !_isFullscreen)
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white),
                  onPressed: _toggleFullscreen,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки плеера',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                    });
                    _loadPlayer();
                  },
                  child: const Text('Повторить'),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                  ),
                  child: const Text('Назад'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPlayerInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Информация о плеере',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Плеер', _getPlayerName()),
          _buildInfoRow('Файл', widget.title),
          _buildInfoRow('URL', widget.videoUrl),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'reload':
        _loadPlayer();
        break;
      case 'share':
        _shareVideo();
        break;
    }
  }

  void _shareVideo() {
    // TODO: Implement sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Поделиться: ${widget.title}'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// Helper widget for creating custom HTML player if needed
class CustomPlayerWidget extends StatelessWidget {
  final String videoUrl;
  final String title;
  final WebPlayerType playerType;

  const CustomPlayerWidget({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.playerType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_filled,
              size: 64,
              color: Colors.white.withOpacity(0.8),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Плеер: ${playerType == WebPlayerType.vibix ? 'Vibix' : 'Alloha'}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Нажмите для воспроизведения',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}