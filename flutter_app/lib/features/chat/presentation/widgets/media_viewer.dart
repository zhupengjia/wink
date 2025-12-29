import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import '../../../../core/theme/wink_theme.dart';

/// Full-screen media viewer for images and videos
class MediaViewer extends StatefulWidget {
  final String mediaUrl;
  final String mediaType;
  final String senderName;
  final DateTime timestamp;

  const MediaViewer({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    required this.senderName,
    required this.timestamp,
  });

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  VideoPlayerController? _videoController;
  bool _showControls = true;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (widget.mediaType == 'video') {
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.mediaUrl),
    );

    await _videoController!.initialize();
    setState(() => _isVideoInitialized = true);
    _videoController!.play();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _togglePlayPause() {
    if (_videoController == null) return;

    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Media content
            Center(
              child: widget.mediaType == 'video'
                  ? _buildVideoPlayer()
                  : _buildImageViewer(),
            ),

            // Top bar
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.senderName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatTime(widget.timestamp),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.download, color: Colors.white),
                          onPressed: _downloadMedia,
                        ),
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.white),
                          onPressed: _shareMedia,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Video controls
            if (widget.mediaType == 'video' && _isVideoInitialized)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Center(
                  child: IconButton(
                    iconSize: 64,
                    icon: Icon(
                      _videoController!.value.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    onPressed: _togglePlayPause,
                  ),
                ),
              ),

            // Video progress
            if (widget.mediaType == 'video' && _isVideoInitialized)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: VideoProgressIndicator(
                        _videoController!,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: WinkTheme.primary,
                          bufferedColor: Colors.white30,
                          backgroundColor: Colors.white10,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageViewer() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Image.network(
        widget.mediaUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: WinkTheme.primary,
            ),
          );
        },
        errorBuilder: (_, __, ___) => const Icon(
          Icons.broken_image,
          color: Colors.white54,
          size: 64,
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isVideoInitialized) {
      return const CircularProgressIndicator(color: WinkTheme.primary);
    }

    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: VideoPlayer(_videoController!),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return 'Today ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _downloadMedia() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading...')),
      );

      final response = await http.get(Uri.parse(widget.mediaUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download');
      }

      final directory = await getApplicationDocumentsDirectory();
      final ext = widget.mediaType == 'video' ? 'mp4' : 'jpg';
      final fileName = 'wink_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  Future<void> _shareMedia() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing to share...')),
      );

      final response = await http.get(Uri.parse(widget.mediaUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download for sharing');
      }

      final directory = await getTemporaryDirectory();
      final ext = widget.mediaType == 'video' ? 'mp4' : 'jpg';
      final fileName = 'wink_share_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Shared from Wink',
      );

      // Clean up temp file after a delay
      Future.delayed(const Duration(minutes: 1), () {
        try {
          file.delete();
        } catch (_) {}
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }
}
