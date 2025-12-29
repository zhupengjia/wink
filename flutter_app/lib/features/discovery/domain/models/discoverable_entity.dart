import 'dart:ui';

enum EntityType { user, persona }

/// Represents a discoverable entity (user or AI persona) in the 3D planet view
class DiscoverableEntity {
  final String id;
  final EntityType type;
  final String name;
  final String? nameZh;
  final String avatarUrl;
  final String? bio;
  final String? archetype; // For personas: 'romantic', 'playful', 'mysterious'

  // Position in 3D space (normalized -1 to 1)
  double x;
  double y;
  double z; // Depth for parallax

  // Physics
  double vx = 0;
  double vy = 0;
  double mass;

  // Visual state
  bool isHighlighted = false;
  double pulsePhase = 0;

  DiscoverableEntity({
    required this.id,
    required this.type,
    required this.name,
    this.nameZh,
    required this.avatarUrl,
    this.bio,
    this.archetype,
    required this.x,
    required this.y,
    required this.z,
    double? mass,
  }) : mass = mass ?? (type == EntityType.persona ? 2.0 : 1.0);

  /// Get localized name
  String getLocalizedName(String locale) {
    if (locale == 'zh' && nameZh != null && nameZh!.isNotEmpty) {
      return nameZh!;
    }
    return name;
  }

  /// Screen position with perspective projection
  Offset toScreenPosition(Size screenSize, Offset panOffset, double zoom) {
    final perspective = 1 + (z * 0.3); // Depth effect
    final screenX =
        (x * zoom * perspective + panOffset.dx) * screenSize.width / 2 +
            screenSize.width / 2;
    final screenY =
        (y * zoom * perspective + panOffset.dy) * screenSize.height / 2 +
            screenSize.height / 2;
    return Offset(screenX, screenY);
  }

  /// Node size based on depth (closer = larger)
  double get visualRadius => 30 + (1 - z) * 15;

  /// Glow intensity (personas glow more)
  double get glowIntensity => type == EntityType.persona ? 0.8 : 0.5;

  /// Check if a tap point is within this entity's bounds
  bool containsPoint(Offset point, Size screenSize, Offset panOffset, double zoom) {
    final screenPos = toScreenPosition(screenSize, panOffset, zoom);
    final distance = (point - screenPos).distance;
    return distance <= visualRadius * 1.5;
  }

  /// Create from JSON (API response)
  factory DiscoverableEntity.fromJson(Map<String, dynamic> json) {
    return DiscoverableEntity(
      id: json['id'] as String,
      type: json['type'] == 'persona' ? EntityType.persona : EntityType.user,
      name: json['name'] as String,
      nameZh: json['name_zh'] as String?,
      avatarUrl: json['avatar_url'] as String,
      bio: json['bio'] as String?,
      archetype: json['archetype'] as String?,
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      z: (json['z'] as num?)?.toDouble() ?? 0.5,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type == EntityType.persona ? 'persona' : 'user',
      'name': name,
      'name_zh': nameZh,
      'avatar_url': avatarUrl,
      'bio': bio,
      'archetype': archetype,
      'x': x,
      'y': y,
      'z': z,
    };
  }

  @override
  String toString() {
    return 'DiscoverableEntity(id: $id, name: $name, type: $type, pos: ($x, $y, $z))';
  }
}
