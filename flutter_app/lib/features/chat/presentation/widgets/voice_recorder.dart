import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme/wink_theme.dart';

/// Voice recorder widget for recording audio messages
class VoiceRecorder extends StatefulWidget {
  final Function(String path, Duration duration) onRecordingComplete;
  final VoidCallback onCancel;

  const VoiceRecorder({
    super.key,
    required this.onRecordingComplete,
    required this.onCancel,
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _duration = Duration.zero;
  Timer? _timer;
  String? _recordingPath;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        _recordingPath =
            '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _recordingPath!,
        );

        setState(() => _isRecording = true);
        _startTimer();
      } else {
        widget.onCancel();
      }
    } catch (e) {
      widget.onCancel();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() => _duration += const Duration(seconds: 1));
      }
    });
  }

  Future<void> _pauseRecording() async {
    if (_isRecording && !_isPaused) {
      await _recorder.pause();
      setState(() => _isPaused = true);
    }
  }

  Future<void> _resumeRecording() async {
    if (_isRecording && _isPaused) {
      await _recorder.resume();
      setState(() => _isPaused = false);
    }
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (path != null) {
      widget.onRecordingComplete(path, _duration);
    } else {
      widget.onCancel();
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    await _recorder.stop();
    if (_recordingPath != null) {
      try {
        await File(_recordingPath!).delete();
      } catch (_) {}
    }
    widget.onCancel();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: WinkTheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // Cancel button
          IconButton(
            onPressed: _cancelRecording,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Cancel',
          ),

          // Recording indicator and duration
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing recording indicator
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isPaused
                            ? Colors.orange
                            : Colors.red.withOpacity(
                                0.5 + 0.5 * _pulseController.value),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),

                // Duration
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(
                    color: WinkTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),

                const SizedBox(width: 12),

                // Pause/Resume button
                IconButton(
                  onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                  icon: Icon(
                    _isPaused ? Icons.play_arrow : Icons.pause,
                    color: WinkTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Send button
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: WinkTheme.primary,
            ),
            child: IconButton(
              onPressed: _duration.inSeconds >= 1 ? _stopAndSend : null,
              icon: const Icon(Icons.send, color: Colors.white),
              tooltip: 'Send',
            ),
          ),
        ],
      ),
    );
  }
}

/// Voice message player widget
class VoiceMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final Duration duration;
  final bool isFromMe;

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.duration,
    required this.isFromMe,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.duration.inMilliseconds > 0
        ? _position.inMilliseconds / widget.duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: () {
              setState(() => _isPlaying = !_isPlaying);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isFromMe
                    ? Colors.white.withOpacity(0.2)
                    : WinkTheme.primary.withOpacity(0.2),
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.isFromMe ? Colors.white : WinkTheme.primary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Waveform placeholder
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: widget.isFromMe
                        ? Colors.white.withOpacity(0.3)
                        : WinkTheme.textSecondary.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation(
                      widget.isFromMe ? Colors.white : WinkTheme.primary,
                    ),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                // Duration
                Text(
                  _formatDuration(_isPlaying ? _position : widget.duration),
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isFromMe
                        ? Colors.white.withOpacity(0.7)
                        : WinkTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
