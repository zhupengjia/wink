import 'package:flutter/material.dart';
import '../../../../core/theme/wink_theme.dart';

/// Chat input field with media attachment button
class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final VoidCallback onMediaTap;
  final bool isLoading;
  final String? hintText;

  const ChatInput({
    super.key,
    required this.onSend,
    required this.onMediaTap,
    this.isLoading = false,
    this.hintText,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isLoading) return;

    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: WinkTheme.surface,
        border: const Border(
          top: BorderSide(color: WinkTheme.surfaceLight, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Media button
          IconButton(
            onPressed: widget.onMediaTap,
            icon: const Icon(Icons.add_circle_outline),
            color: WinkTheme.textSecondary,
            splashRadius: 24,
          ),

          // Text input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: WinkTheme.surfaceLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                style: const TextStyle(
                  color: WinkTheme.textPrimary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText ?? 'Type a message...',
                  hintStyle: TextStyle(
                    color: WinkTheme.textSecondary.withOpacity(0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hasText && !widget.isLoading
                  ? WinkTheme.primary
                  : WinkTheme.surfaceLight,
              boxShadow: _hasText && !widget.isLoading
                  ? [
                      BoxShadow(
                        color: WinkTheme.primary.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: IconButton(
              onPressed: _hasText && !widget.isLoading ? _send : null,
              icon: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      color: _hasText && !widget.isLoading
                          ? Colors.white
                          : WinkTheme.textSecondary,
                      size: 20,
                    ),
              splashRadius: 22,
            ),
          ),
        ],
      ),
    );
  }
}

/// Media picker bottom sheet
class MediaPickerSheet extends StatelessWidget {
  final VoidCallback onPhotoTap;
  final VoidCallback onVideoTap;
  final VoidCallback onVoiceTap;
  final VoidCallback onCameraTap;

  const MediaPickerSheet({
    super.key,
    required this.onPhotoTap,
    required this.onVideoTap,
    required this.onVoiceTap,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: WinkTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: WinkTheme.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MediaOption(
                icon: Icons.photo,
                label: 'Photo',
                color: Colors.blue,
                onTap: onPhotoTap,
              ),
              _MediaOption(
                icon: Icons.videocam,
                label: 'Video',
                color: Colors.purple,
                onTap: onVideoTap,
              ),
              _MediaOption(
                icon: Icons.mic,
                label: 'Voice',
                color: Colors.orange,
                onTap: onVoiceTap,
              ),
              _MediaOption(
                icon: Icons.camera_alt,
                label: 'Camera',
                color: Colors.green,
                onTap: onCameraTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MediaOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: WinkTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
