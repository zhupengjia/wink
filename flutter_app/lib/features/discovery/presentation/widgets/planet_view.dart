import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/models/discoverable_entity.dart';
import 'starfield_painter.dart';
import 'floating_node.dart';
import 'node_physics.dart';
import '../../../../core/theme/wink_theme.dart';

/// The main 3D planet view with floating entities
class PlanetView extends StatefulWidget {
  final List<DiscoverableEntity> entities;
  final Function(DiscoverableEntity) onEntityTap;
  final DiscoverableEntity? selectedEntity;

  const PlanetView({
    super.key,
    required this.entities,
    required this.onEntityTap,
    this.selectedEntity,
  });

  @override
  State<PlanetView> createState() => _PlanetViewState();
}

class _PlanetViewState extends State<PlanetView> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late List<Star> _stars;
  final Random _random = Random();

  Offset _panOffset = Offset.zero;
  double _zoom = 1.0;
  Offset _lastFocalPoint = Offset.zero;
  double _lastScale = 1.0;

  @override
  void initState() {
    super.initState();
    _stars = generateStars(200);

    // Spread entities on initial load
    if (widget.entities.isNotEmpty) {
      NodePhysics.spreadEntities(widget.entities);
    }

    // Main animation loop for physics and starfield
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Pulse animation for node glows
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _animationController.addListener(_updatePhysics);
  }

  void _updatePhysics() {
    // Update physics simulation
    NodePhysics.update(widget.entities, 16.0);
    NodePhysics.applyGravity(widget.entities, 1.0);

    // Occasional brownian motion for liveliness
    if (_random.nextDouble() < 0.1) {
      NodePhysics.applyBrownianMotion(widget.entities, 1.0, _random);
    }

    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(PlanetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If entities changed, spread them
    if (oldWidget.entities.length != widget.entities.length) {
      NodePhysics.spreadEntities(widget.entities);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;
    _lastScale = _zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // Pan
      final delta = details.focalPoint - _lastFocalPoint;
      _panOffset += Offset(
        delta.dx / MediaQuery.of(context).size.width * 2,
        delta.dy / MediaQuery.of(context).size.height * 2,
      );
      _lastFocalPoint = details.focalPoint;

      // Zoom
      if (details.scale != 1.0) {
        _zoom = (_lastScale * details.scale).clamp(0.5, 2.0);
      }
    });
  }

  void _onTapUp(TapUpDetails details) {
    final size = MediaQuery.of(context).size;
    final tapPosition = details.localPosition;

    // Check if tap is on any entity
    for (final entity in widget.entities.reversed) {
      if (entity.containsPoint(tapPosition, size, _panOffset, _zoom)) {
        widget.onEntityTap(entity);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final time = _animationController.value;

    return Container(
      color: WinkTheme.background,
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onTapUp: _onTapUp,
        child: Stack(
          children: [
            // Starfield background
            CustomPaint(
              size: size,
              painter: StarfieldPainter(
                stars: _stars,
                panOffset: _panOffset,
                zoom: _zoom,
                time: time,
              ),
            ),

            // Center glow (planet core effect)
            Center(
              child: Container(
                width: 150 * _zoom,
                height: 150 * _zoom,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      WinkTheme.primary.withOpacity(0.15),
                      WinkTheme.secondary.withOpacity(0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Floating nodes
            ...widget.entities.map((entity) {
              final screenPos = entity.toScreenPosition(size, _panOffset, _zoom);

              // Skip if off screen
              if (screenPos.dx < -100 ||
                  screenPos.dx > size.width + 100 ||
                  screenPos.dy < -100 ||
                  screenPos.dy > size.height + 100) {
                return const SizedBox.shrink();
              }

              return Positioned(
                left: screenPos.dx - entity.visualRadius * 1.5,
                top: screenPos.dy - entity.visualRadius * 1.5,
                child: FloatingNode(
                  entity: entity,
                  pulseAnimation: _pulseController.value,
                  isSelected: widget.selectedEntity?.id == entity.id,
                  onTap: () => widget.onEntityTap(entity),
                ),
              );
            }),

            // Vignette overlay for depth
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      WinkTheme.background.withOpacity(0.3),
                      WinkTheme.background.withOpacity(0.6),
                    ],
                    stops: const [0.3, 0.7, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
