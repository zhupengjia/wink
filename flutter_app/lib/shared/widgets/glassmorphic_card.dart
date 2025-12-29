import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/wink_theme.dart';

/// A glassmorphic card with blur effect and gradient border
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurAmount;
  final Color? backgroundColor;
  final EdgeInsets? padding;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.blurAmount = 20,
    this.backgroundColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(borderRadius),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurAmount,
          sigmaY: blurAmount,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? WinkTheme.surface.withOpacity(0.9),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(borderRadius),
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        ),
      ),
    );
  }
}

/// A glassmorphic container for inline use
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurAmount;
  final Color? backgroundColor;
  final EdgeInsets padding;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.blurAmount = 10,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurAmount,
          sigmaY: blurAmount,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? WinkTheme.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
