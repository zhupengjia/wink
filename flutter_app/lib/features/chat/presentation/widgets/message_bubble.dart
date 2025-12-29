import 'package:flutter/material.dart';
import '../../domain/models/message.dart';
import '../../../../core/theme/wink_theme.dart';

/// A chat message bubble
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showAvatar;
  final VoidCallback? onMediaTap;

  const MessageBubble({
    super.key,
    required this.message,
    this.showAvatar = true,
    this.onMediaTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isFromMe;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (other person)
          if (!isMe && showAvatar)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildAvatar(),
            )
          else if (!isMe)
            const SizedBox(width: 40),

          // Message content
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              decoration: BoxDecoration(
                color: isMe ? WinkTheme.primary : WinkTheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isMe ? WinkTheme.primary : Colors.black).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Media content
                    if (message.hasMedia) _buildMedia(),

                    // Text content
                    if (message.content.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          left: 14,
                          right: 14,
                          top: message.hasMedia ? 8 : 12,
                          bottom: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Message text with streaming cursor
                            if (message.isStreaming)
                              _buildStreamingText(isMe)
                            else
                              Text(
                                message.content,
                                style: TextStyle(
                                  color:
                                      isMe ? Colors.white : WinkTheme.textPrimary,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),

                            // Timestamp
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(message.timestamp),
                              style: TextStyle(
                                color:
                                    (isMe ? Colors.white : WinkTheme.textSecondary)
                                        .withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundColor: WinkTheme.surface,
      backgroundImage: message.senderAvatar != null
          ? NetworkImage(message.senderAvatar!)
          : null,
      child: message.senderAvatar == null
          ? Icon(
              message.isFromAI ? Icons.auto_awesome : Icons.person,
              size: 16,
              color: WinkTheme.textSecondary,
            )
          : null,
    );
  }

  Widget _buildMedia() {
    switch (message.mediaType) {
      case MediaType.image:
        return GestureDetector(
          onTap: onMediaTap,
          child: Image.network(
            message.thumbnailUrl ?? message.mediaUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 200,
              color: WinkTheme.surfaceLight,
              child: const Center(
                child: Icon(Icons.broken_image, color: WinkTheme.textSecondary),
              ),
            ),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                color: WinkTheme.surfaceLight,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
          ),
        );

      case MediaType.video:
        return GestureDetector(
          onTap: onMediaTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (message.thumbnailUrl != null)
                Image.network(
                  message.thumbnailUrl!,
                  fit: BoxFit.cover,
                  height: 200,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: WinkTheme.surfaceLight,
                  ),
                )
              else
                Container(
                  height: 200,
                  color: WinkTheme.surfaceLight,
                ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
              ),
              if (message.mediaDuration != null)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(message.mediaDuration!),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        );

      case MediaType.voice:
        return Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_circle_fill, color: Colors.white),
              const SizedBox(width: 8),
              // Voice waveform placeholder
              ...List.generate(
                12,
                (i) => Container(
                  width: 3,
                  height: 8 + (i % 3) * 8.0,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: Colors.white54,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(message.mediaDuration ?? 0),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        );

      default:
        return const SizedBox();
    }
  }

  Widget _buildStreamingText(bool isMe) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            message.content,
            style: TextStyle(
              color: isMe ? Colors.white : WinkTheme.textPrimary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(width: 2),
        const _StreamingCursor(),
      ],
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// Blinking cursor for streaming messages
class _StreamingCursor extends StatefulWidget {
  const _StreamingCursor();

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 16,
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: WinkTheme.secondary,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
