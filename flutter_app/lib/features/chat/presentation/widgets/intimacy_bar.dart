import 'package:flutter/material.dart';
import '../../../../core/theme/wink_theme.dart';

/// Displays the intimacy level progress for AI conversations
class IntimacyBar extends StatefulWidget {
  final int score; // 0-1000
  final String tier; // stranger, acquaintance, friend, close, intimate
  final int? recentGain; // Points just gained (flash animation)

  const IntimacyBar({
    super.key,
    required this.score,
    required this.tier,
    this.recentGain,
  });

  @override
  State<IntimacyBar> createState() => _IntimacyBarState();
}

class _IntimacyBarState extends State<IntimacyBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _gainController;
  late Animation<double> _gainAnimation;

  @override
  void initState() {
    super.initState();
    _gainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _gainAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _gainController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(IntimacyBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recentGain != null &&
        widget.recentGain != oldWidget.recentGain) {
      _gainController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _gainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.score / 1000;
    final tierInfo = _getTierInfo(widget.tier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: WinkTheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tierInfo.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tier icon
          Icon(
            tierInfo.icon,
            color: tierInfo.color,
            size: 16,
          ),
          const SizedBox(width: 6),

          // Progress bar
          SizedBox(
            width: 60,
            child: Stack(
              children: [
                // Background
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: WinkTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Progress
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 300),
                  widthFactor: progress,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [tierInfo.color, tierInfo.color.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: tierInfo.color.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Tier label
          Text(
            tierInfo.shortLabel,
            style: TextStyle(
              fontSize: 11,
              color: tierInfo.color,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Recent gain indicator
          if (widget.recentGain != null && widget.recentGain! > 0)
            AnimatedBuilder(
              animation: _gainAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _gainAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, -4 * (1 - _gainAnimation.value)),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '+${widget.recentGain}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  _TierInfo _getTierInfo(String tier) {
    switch (tier) {
      case 'stranger':
        return _TierInfo(
          Icons.remove_circle_outline,
          Colors.grey,
          'Stranger',
          'STR',
        );
      case 'acquaintance':
        return _TierInfo(
          Icons.handshake_outlined,
          Colors.blue,
          'Acquaintance',
          'ACQ',
        );
      case 'friend':
        return _TierInfo(
          Icons.people_outline,
          Colors.green,
          'Friend',
          'FRD',
        );
      case 'close':
        return _TierInfo(
          Icons.favorite_border,
          Colors.orange,
          'Close',
          'CLS',
        );
      case 'intimate':
        return _TierInfo(
          Icons.favorite,
          WinkTheme.secondary,
          'Intimate',
          'INT',
        );
      default:
        return _TierInfo(
          Icons.help_outline,
          Colors.grey,
          tier,
          tier.substring(0, 3).toUpperCase(),
        );
    }
  }
}

class _TierInfo {
  final IconData icon;
  final Color color;
  final String label;
  final String shortLabel;

  _TierInfo(this.icon, this.color, this.label, this.shortLabel);
}

/// Animated version of FractionallySizedBox
class AnimatedFractionallySizedBox extends ImplicitlyAnimatedWidget {
  final double widthFactor;
  final Widget child;

  const AnimatedFractionallySizedBox({
    super.key,
    required super.duration,
    required this.widthFactor,
    required this.child,
  });

  @override
  AnimatedWidgetBaseState<AnimatedFractionallySizedBox> createState() =>
      _AnimatedFractionallySizedBoxState();
}

class _AnimatedFractionallySizedBoxState
    extends AnimatedWidgetBaseState<AnimatedFractionallySizedBox> {
  Tween<double>? _widthFactor;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _widthFactor = visitor(
      _widthFactor,
      widget.widthFactor,
      (value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: _widthFactor?.evaluate(animation) ?? widget.widthFactor,
      child: widget.child,
    );
  }
}
