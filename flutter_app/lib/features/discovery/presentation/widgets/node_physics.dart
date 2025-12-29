import 'dart:math';
import '../../domain/models/discoverable_entity.dart';

/// Physics simulation for floating nodes in the planet view
class NodePhysics {
  // Physics constants
  static const double friction = 0.98;
  static const double repulsionStrength = 0.0005;
  static const double boundaryForce = 0.01;
  static const double maxVelocity = 0.02;
  static const double minDistance = 0.15; // Minimum distance between nodes

  /// Update all node positions with physics simulation
  static void update(List<DiscoverableEntity> entities, double dt) {
    if (entities.isEmpty) return;

    // Apply repulsion between all node pairs
    for (int i = 0; i < entities.length; i++) {
      for (int j = i + 1; j < entities.length; j++) {
        _applyRepulsion(entities[i], entities[j]);
      }
    }

    // Update each entity's position
    for (final entity in entities) {
      // Apply boundary forces (keep nodes in view)
      if (entity.x.abs() > 0.8) {
        entity.vx -= entity.x.sign * boundaryForce;
      }
      if (entity.y.abs() > 0.8) {
        entity.vy -= entity.y.sign * boundaryForce;
      }

      // Clamp velocity to max
      final speed = sqrt(entity.vx * entity.vx + entity.vy * entity.vy);
      if (speed > maxVelocity) {
        entity.vx = entity.vx / speed * maxVelocity;
        entity.vy = entity.vy / speed * maxVelocity;
      }

      // Apply friction
      entity.vx *= friction;
      entity.vy *= friction;

      // Update position
      entity.x += entity.vx * dt;
      entity.y += entity.vy * dt;

      // Clamp to bounds
      entity.x = entity.x.clamp(-1.0, 1.0);
      entity.y = entity.y.clamp(-1.0, 1.0);
    }
  }

  /// Apply repulsion force between two entities
  static void _applyRepulsion(DiscoverableEntity a, DiscoverableEntity b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final distSq = dx * dx + dy * dy + 0.01; // Prevent division by zero

    // Skip if too far apart
    if (distSq > 0.5) return;

    // Calculate repulsion force (inverse square law)
    final force = repulsionStrength / distSq;
    final fx = dx * force;
    final fy = dy * force;

    // Apply forces inversely proportional to mass
    a.vx -= fx / a.mass;
    a.vy -= fy / a.mass;
    b.vx += fx / b.mass;
    b.vy += fy / b.mass;
  }

  /// Apply gentle gravity towards center to prevent drift
  static void applyGravity(List<DiscoverableEntity> entities, double strength) {
    for (final entity in entities) {
      entity.vx -= entity.x * strength * 0.0001;
      entity.vy -= entity.y * strength * 0.0001;
    }
  }

  /// Add random gentle motion to make nodes feel alive
  static void applyBrownianMotion(
    List<DiscoverableEntity> entities,
    double strength,
    Random random,
  ) {
    for (final entity in entities) {
      entity.vx += (random.nextDouble() - 0.5) * strength * 0.001;
      entity.vy += (random.nextDouble() - 0.5) * strength * 0.001;
    }
  }

  /// Spread entities evenly across the view (initial layout)
  static void spreadEntities(List<DiscoverableEntity> entities, {int? seed}) {
    if (entities.isEmpty) return;

    final random = Random(seed);
    final count = entities.length;

    // Distribute in a rough spiral/circle pattern
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * pi + random.nextDouble() * 0.5;
      final radius = 0.3 + random.nextDouble() * 0.5;

      entities[i].x = cos(angle) * radius;
      entities[i].y = sin(angle) * radius;
      entities[i].z = 0.2 + random.nextDouble() * 0.6;

      // Reset velocities
      entities[i].vx = 0;
      entities[i].vy = 0;
    }
  }

  /// Apply attraction force towards a point (for interactive effects)
  static void attractToPoint(
    List<DiscoverableEntity> entities,
    double targetX,
    double targetY,
    double strength,
  ) {
    for (final entity in entities) {
      final dx = targetX - entity.x;
      final dy = targetY - entity.y;
      entity.vx += dx * strength * 0.01;
      entity.vy += dy * strength * 0.01;
    }
  }

  /// Push entities away from a point (for interactive effects)
  static void repelFromPoint(
    List<DiscoverableEntity> entities,
    double pointX,
    double pointY,
    double strength,
    double radius,
  ) {
    for (final entity in entities) {
      final dx = entity.x - pointX;
      final dy = entity.y - pointY;
      final dist = sqrt(dx * dx + dy * dy);

      if (dist < radius && dist > 0.01) {
        final force = strength * (1 - dist / radius);
        entity.vx += (dx / dist) * force * 0.01;
        entity.vy += (dy / dist) * force * 0.01;
      }
    }
  }
}
