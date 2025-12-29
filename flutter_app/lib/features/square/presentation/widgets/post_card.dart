import 'package:flutter/material.dart';
import '../../../../core/theme/wink_theme.dart';
import '../pages/square_page.dart';

/// Card widget for displaying a post in the Square feed
class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onAuthorTap;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: WinkTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),

          // Content
          _buildContent(),

          // Media
          if (post.mediaUrls.isNotEmpty) _buildMedia(),

          // Actions
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return InkWell(
      onTap: onAuthorTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(post.authorAvatar),
                  onBackgroundImageError: (_, __) {},
                  backgroundColor: WinkTheme.surfaceLight,
                ),
                if (post.isAI)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: WinkTheme.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: WinkTheme.surface, width: 2),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Name and time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: WinkTheme.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      if (post.isAI) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: WinkTheme.secondary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'AI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: WinkTheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(post.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: WinkTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // More options
            IconButton(
              icon: Icon(
                Icons.more_horiz,
                color: WinkTheme.textSecondary,
              ),
              onPressed: () {
                // Show options menu
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        post.content,
        style: const TextStyle(
          color: WinkTheme.textPrimary,
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildMedia() {
    if (post.mediaUrls.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          child: Image.network(
            post.mediaUrls.first,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 200,
              color: WinkTheme.surfaceLight,
              child: const Icon(Icons.broken_image, color: WinkTheme.textSecondary),
            ),
          ),
        ),
      );
    }

    // Grid for multiple images
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: post.mediaUrls.length > 4 ? 4 : post.mediaUrls.length,
        itemBuilder: (context, index) {
          final isLast = index == 3 && post.mediaUrls.length > 4;
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  post.mediaUrls[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: WinkTheme.surfaceLight,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
                if (isLast)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Text(
                        '+${post.mediaUrls.length - 4}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          // Like
          _ActionButton(
            icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
            label: _formatCount(post.likeCount),
            color: post.isLiked ? Colors.red : WinkTheme.textSecondary,
            onTap: onLike,
          ),

          const SizedBox(width: 16),

          // Comment
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            label: _formatCount(post.commentCount),
            color: WinkTheme.textSecondary,
            onTap: onComment,
          ),

          const SizedBox(width: 16),

          // Share
          _ActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            color: WinkTheme.textSecondary,
            onTap: onShare,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${time.month}/${time.day}';
    }
  }

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
