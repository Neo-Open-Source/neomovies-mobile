import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class VideoPlayerScreen extends StatefulWidget {
  final String filePath;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isControlsVisible = true;
  bool _isFullscreen = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _setOrientation(false);
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _error = 'Файл не найден: ${widget.filePath}';
          _isLoading = false;
        });
        return;
      }

      _controller = VideoPlayerController.file(file);
      
      await _controller!.initialize();
      
      _controller!.addListener(() {
        setState(() {});
      });

      setState(() {
        _isLoading = false;
      });

      // Auto play
      _controller!.play();
    } catch (e) {
      setState(() {
        _error = 'Ошибка инициализации плеера: $e';
        _isLoading = false;
      });
    }
  }

  void _togglePlayPause() {
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {});
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

  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });

    if (_isControlsVisible) {
      // Hide controls after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _controller!.value.isPlaying) {
          setState(() {
            _isControlsVisible = false;
          });
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final hours = duration.inHours;
    
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullscreen ? null : AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ошибка воспроизведения',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Назад'),
            ),
          ],
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        children: [
          // Video player
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
          
          // Controls overlay
          if (_isControlsVisible)
            _buildControlsOverlay(),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Column(
        children: [
          // Top bar
          if (_isFullscreen) _buildTopBar(),
          
          // Center play/pause
          Expanded(
            child: Center(
              child: _buildCenterControls(),
            ),
          ),
          
          // Bottom controls
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 48,
          icon: Icon(
            Icons.replay_10,
            color: Colors.white.withOpacity(0.8),
          ),
          onPressed: () {
            final newPosition = _controller!.value.position - const Duration(seconds: 10);
            _controller!.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
          },
        ),
        const SizedBox(width: 32),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            iconSize: 64,
            icon: Icon(
              _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: _togglePlayPause,
          ),
        ),
        const SizedBox(width: 32),
        IconButton(
          iconSize: 48,
          icon: Icon(
            Icons.forward_10,
            color: Colors.white.withOpacity(0.8),
          ),
          onPressed: () {
            final newPosition = _controller!.value.position + const Duration(seconds: 10);
            final maxDuration = _controller!.value.duration;
            _controller!.seekTo(newPosition > maxDuration ? maxDuration : newPosition);
          },
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Progress bar
            Row(
              children: [
                Text(
                  _formatDuration(_controller!.value.position),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: VideoProgressIndicator(
                    _controller!,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: Theme.of(context).primaryColor,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      bufferedColor: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_controller!.value.duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    _controller!.value.volume == 0 ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (_controller!.value.volume == 0) {
                      _controller!.setVolume(1.0);
                    } else {
                      _controller!.setVolume(0.0);
                    }
                    setState(() {});
                  },
                ),
                IconButton(
                  icon: Icon(
                    _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                  ),
                  onPressed: _toggleFullscreen,
                ),
                PopupMenuButton<double>(
                  icon: const Icon(Icons.speed, color: Colors.white),
                  onSelected: (speed) {
                    _controller!.setPlaybackSpeed(speed);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 0.5, child: Text('0.5x')),
                    const PopupMenuItem(value: 0.75, child: Text('0.75x')),
                    const PopupMenuItem(value: 1.0, child: Text('1.0x')),
                    const PopupMenuItem(value: 1.25, child: Text('1.25x')),
                    const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                    const PopupMenuItem(value: 2.0, child: Text('2.0x')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}