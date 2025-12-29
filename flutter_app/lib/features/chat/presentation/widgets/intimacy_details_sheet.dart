import 'package:flutter/material.dart';
import '../../../../core/theme/wink_theme.dart';

/// Detailed intimacy view showing tier progression
class IntimacyDetailsSheet extends StatelessWidget {
  final String personaName;
  final String personaAvatar;
  final int score;
  final String tier;

  const IntimacyDetailsSheet({
    super.key,
    required this.personaName,
    required this.personaAvatar,
    required this.score,
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: WinkTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: WinkTheme.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Text(
            'Relationship with $personaName',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: WinkTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),

          // Current tier display
          CircleAvatar(
            radius: 40,
            backgroundImage: NetworkImage(personaAvatar),
            onBackgroundImageError: (_, __) {},
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getTierColor(tier).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getTierLabel(tier),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _getTierColor(tier),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$score / 1000',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: WinkTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 32),

          // Tier progression
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _TierRow(
                  tier: 'Stranger',
                  range: '0-100',
                  icon: Icons.person_outline,
                  isCurrent: tier == 'stranger',
                  isUnlocked: score >= 0,
                ),
                _TierRow(
                  tier: 'Acquaintance',
                  range: '101-300',
                  icon: Icons.handshake_outlined,
                  isCurrent: tier == 'acquaintance',
                  isUnlocked: score > 100,
                ),
                _TierRow(
                  tier: 'Friend',
                  range: '301-500',
                  icon: Icons.people_outline,
                  isCurrent: tier == 'friend',
                  isUnlocked: score > 300,
                ),
                _TierRow(
                  tier: 'Close',
                  range: '501-750',
                  icon: Icons.favorite_border,
                  isCurrent: tier == 'close',
                  isUnlocked: score > 500,
                ),
                _TierRow(
                  tier: 'Intimate',
                  range: '751-1000',
                  icon: Icons.favorite,
                  isCurrent: tier == 'intimate',
                  isUnlocked: score > 750,
                ),
              ],
            ),
          ),

          // Tips
          Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WinkTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: WinkTheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Chat daily to earn streak bonuses and unlock deeper connections!',
                    style: TextStyle(
                      color: WinkTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'stranger':
        return Colors.grey;
      case 'acquaintance':
        return Colors.blue;
      case 'friend':
        return Colors.green;
      case 'close':
        return Colors.orange;
      case 'intimate':
        return WinkTheme.secondary;
      default:
        return Colors.grey;
    }
  }

  String _getTierLabel(String tier) {
    switch (tier) {
      case 'stranger':
        return 'Stranger';
      case 'acquaintance':
        return 'Acquaintance';
      case 'friend':
        return 'Friend';
      case 'close':
        return 'Close Friend';
      case 'intimate':
        return 'Intimate';
      default:
        return tier;
    }
  }
}

class _TierRow extends StatelessWidget {
  final String tier;
  final String range;
  final IconData icon;
  final bool isCurrent;
  final bool isUnlocked;

  const _TierRow({
    required this.tier,
    required this.range,
    required this.icon,
    required this.isCurrent,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent
            ? WinkTheme.primary.withOpacity(0.1)
            : WinkTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: isCurrent
            ? Border.all(color: WinkTheme.primary, width: 2)
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? WinkTheme.primary.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isUnlocked ? WinkTheme.primary : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isUnlocked
                        ? WinkTheme.textPrimary
                        : WinkTheme.textSecondary,
                  ),
                ),
                Text(
                  range,
                  style: TextStyle(
                    fontSize: 12,
                    color: WinkTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: WinkTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Current',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
          else if (isUnlocked)
            Icon(
              Icons.check_circle,
              color: WinkTheme.primary,
              size: 20,
            )
          else
            Icon(
              Icons.lock_outline,
              color: Colors.grey,
              size: 20,
            ),
        ],
      ),
    );
  }
}
