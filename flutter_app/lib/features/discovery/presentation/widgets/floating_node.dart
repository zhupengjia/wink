import 'package:flutter/material.dart';
import '../../domain/models/discoverable_entity.dart';
import '../../../../core/theme/wink_theme.dart';

/// A floating avatar node in the 3D planet view
class FloatingNode extends StatelessWidget {
  final DiscoverableEntity entity;
  final double pulseAnimation; // 0-1 for glow pulse
  final VoidCallback onTap;
  final bool isSelected;

  const FloatingNode({
    super.key,
    required this.entity,
    required this.pulseAnimation,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = entity.type == EntityType.persona
        ? WinkTheme.personaNode
        : WinkTheme.userNode;

    final glowRadius = entity.visualRadius * (1.2 + pulseAnimation * 0.3);
    final glowOpacity = entity.glowIntensity * (0.3 + pulseAnimation * 0.2);

    // Scale based on depth
    final scale = 0.7 + (1 - entity.z) * 0.5;

    return GestureDetector(
      onTap: onTap,
      child: Transform.scale(
        scale: scale,
        child: SizedBox(
          width: entity.visualRadius * 3,
          height: entity.visualRadius * 3,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: glowRadius * 2,
                height: glowRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withOpacity(glowOpacity),
                      blurRadius: isSelected ? 30 : 20,
                      spreadRadius: isSelected ? 8 : 5,
                    ),
                  ],
                ),
              ),

              // Selection ring (when selected)
              if (isSelected)
                Container(
                  width: entity.visualRadius * 2.4,
                  height: entity.visualRadius * 2.4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.8),
                      width: 2,
                    ),
                  ),
                ),

              // Avatar ring with gradient border
              Container(
                width: entity.visualRadius * 2,
                height: entity.visualRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      baseColor,
                      baseColor.withOpacity(0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: _buildAvatar(),
                ),
              ),

              // AI persona badge
              if (entity.type == EntityType.persona)
                Positioned(
                  bottom: entity.visualRadius * 0.3,
                  right: entity.visualRadius * 0.3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: WinkTheme.secondary,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: WinkTheme.secondary.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // Online indicator (for real users)
              if (entity.type == EntityType.user)
                Positioned(
                  bottom: entity.visualRadius * 0.3,
                  right: entity.visualRadius * 0.3,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: WinkTheme.background,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (entity.avatarUrl.isEmpty) {
      return Container(
        color: WinkTheme.surface,
        child: Icon(
          entity.type == EntityType.persona ? Icons.auto_awesome : Icons.person,
          color: WinkTheme.textSecondary,
          size: entity.visualRadius * 0.8,
        ),
      );
    }

    return Image.network(
      entity.avatarUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: WinkTheme.surface,
          child: Icon(
            entity.type == EntityType.persona
                ? Icons.auto_awesome
                : Icons.person,
            color: WinkTheme.textSecondary,
            size: entity.visualRadius * 0.8,
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: WinkTheme.surface,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
    );
  }
}
