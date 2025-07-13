import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:neomovies_mobile/utils/device_utils.dart';
import 'package:neomovies_mobile/presentation/widgets/player/web_player_widget.dart';
import 'package:neomovies_mobile/data/models/player/video_source.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String mediaId; // Теперь это IMDB ID
  final String mediaType; // 'movie' or 'tv'
  final String? title;
  final String? subtitle;
  final String? posterUrl;

  const VideoPlayerScreen({
    Key? key,
    required this.mediaId,
    required this.mediaType,
    this.title,
    this.subtitle,
    this.posterUrl,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoSource _selectedSource = VideoSource.defaultSources.first;

  @override
  void initState() {
    super.initState();
    _setupPlayerEnvironment();
  }

  void _setupPlayerEnvironment() {
    // Keep screen awake during video playback
    WakelockPlus.enable();
    
    // Set landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _restoreSystemSettings();
    super.dispose();
  }

  void _restoreSystemSettings() {
    // Restore system UI and allow screen to sleep
    WakelockPlus.disable();
    
    // Restore orientation: phones back to portrait, tablets/TV keep free rotation
    if (DeviceUtils.isLargeScreen(context)) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _restoreSystemSettings();
        return true;
      },
      child: _VideoPlayerScreenContent(
        title: widget.title,
        mediaId: widget.mediaId,
        selectedSource: _selectedSource,
        onSourceChanged: (source) {
          if (mounted) {
            setState(() {
              _selectedSource = source;
            });
          }
        },
      ),
    );
  }
}

class _VideoPlayerScreenContent extends StatelessWidget {
  final String mediaId; // IMDB ID
  final String? title;
  final VideoSource selectedSource;
  final ValueChanged<VideoSource> onSourceChanged;

  const _VideoPlayerScreenContent({
    Key? key,
    required this.mediaId,
    this.title,
    required this.selectedSource,
    required this.onSourceChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Source selector header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.black87,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Источник: ',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  _buildSourceSelector(),
                  const Spacer(),
                  if (title != null)
                    Expanded(
                      flex: 2,
                      child: Text(
                        title!,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                ],
              ),
            ),
            
            // Video player
            Expanded(
              child: WebPlayerWidget(
                key: ValueKey(selectedSource.id),
                mediaId: mediaId,
                source: selectedSource,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSelector() {
    return DropdownButton<VideoSource>(
      value: selectedSource,
      dropdownColor: Colors.black87,
      style: const TextStyle(color: Colors.white),
      underline: Container(),
      items: VideoSource.defaultSources
          .where((source) => source.isActive)
          .map((source) => DropdownMenuItem<VideoSource>(
                value: source,
                child: Text(source.name),
              ))
          .toList(),
      onChanged: (VideoSource? newSource) {
        if (newSource != null) {
          onSourceChanged(newSource);
        }
      },
    );
  }
}
