import 'package:flutter/material.dart';
import '../../../../core/theme/wink_theme.dart';

/// Bottom sheet for selecting media type to send
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
      decoration: const BoxDecoration(
        color: WinkTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: WinkTheme.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Send Media',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: WinkTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Options grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MediaOption(
                    icon: Icons.photo_library,
                    label: 'Photo',
                    color: WinkTheme.primary,
                    onTap: onPhotoTap,
                  ),
                  _MediaOption(
                    icon: Icons.videocam,
                    label: 'Video',
                    color: WinkTheme.secondary,
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
            ),
            const SizedBox(height: 30),
          ],
        ),
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: WinkTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
