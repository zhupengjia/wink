import 'package:flutter/material.dart';
import '../../../../core/theme/wink_theme.dart';

/// Shows a typing indicator with animated dots
class TypingIndicator extends StatefulWidget {
  final String? name;
  final String? avatarUrl;
  final bool isAI;

  const TypingIndicator({
    super.key,
    this.name,
    this.avatarUrl,
    this.isAI = false,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar
          if (widget.avatarUrl != null)
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(widget.avatarUrl!),
              onBackgroundImageError: (_, __) {},
              child: widget.avatarUrl == null
                  ? Icon(
                      widget.isAI ? Icons.auto_awesome : Icons.person,
                      size: 16,
                      color: WinkTheme.textSecondary,
                    )
                  : null,
            )
          else
            CircleAvatar(
              radius: 16,
              backgroundColor: WinkTheme.surface,
              child: Icon(
                widget.isAI ? Icons.auto_awesome : Icons.person,
                size: 16,
                color: WinkTheme.textSecondary,
              ),
            ),
          const SizedBox(width: 8),

          // Typing bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: WinkTheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final delay = index * 0.2;
                    final value = (_controller.value + delay) % 1.0;

                    // Create a bouncing effect
                    double offsetY = 0;
                    double opacity = 0.3;

                    if (value < 0.5) {
                      // Rising
                      offsetY = -4 * (value * 2);
                      opacity = 0.3 + 0.7 * (value * 2);
                    } else {
                      // Falling
                      offsetY = -4 * (1 - (value - 0.5) * 2);
                      opacity = 1.0 - 0.7 * ((value - 0.5) * 2);
                    }

                    final dotColor = widget.isAI
                        ? WinkTheme.secondary
                        : WinkTheme.textSecondary;

                    return Transform.translate(
                      offset: Offset(0, offsetY),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor.withOpacity(opacity.clamp(0.3, 1.0)),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
