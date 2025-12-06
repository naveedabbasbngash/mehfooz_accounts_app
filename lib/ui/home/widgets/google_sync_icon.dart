import 'dart:math';
import 'package:flutter/material.dart';

class GoogleStyleSyncIcon extends StatefulWidget {
  final bool syncing;
  final bool success;
  final bool error;

  const GoogleStyleSyncIcon({
    super.key,
    required this.syncing,
    required this.success,
    required this.error,
  });

  @override
  State<GoogleStyleSyncIcon> createState() => _GoogleStyleSyncIconState();
}

class _GoogleStyleSyncIconState extends State<GoogleStyleSyncIcon>
    with TickerProviderStateMixin {
  late AnimationController _rotation;
  late AnimationController _pulse;
  late AnimationController _fade;

  @override
  void initState() {
    super.initState();

    // Smooth rotation (Google Photos style)
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // slow, smooth
    );

    // Pulse only while syncing
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.90,
      upperBound: 1.05,
    );

    // Fade animation for success/error/sync icons
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _updateAnimations();
  }

  @override
  void didUpdateWidget(covariant GoogleStyleSyncIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimations();
  }

  void _updateAnimations() {
    if (widget.syncing) {
      _rotation.repeat();
      _pulse.repeat(reverse: true);
    } else {
      _rotation.stop();
      _pulse.stop();
    }

    _fade.forward(from: 0); // smooth transition
  }

  @override
  void dispose() {
    _rotation.dispose();
    _pulse.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.error
        ? Colors.red
        : widget.success
        ? Colors.green
        : Colors.blue;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: widget.syncing ? _pulse : const AlwaysStoppedAnimation(1),
        child: SizedBox(
          width: 22,
          height: 22,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating Google-style arc
              RotationTransition(
                turns: _rotation,
                child: CustomPaint(
                  size: const Size(22, 22),
                  painter: _ArcPainter(color),
                ),
              ),

              // Status Icon
              Icon(
                widget.syncing
                    ? Icons.sync
                    : widget.error
                    ? Icons.close
                    : Icons.check,
                size: 13,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;

  _ArcPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color.withOpacity(0.85)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);

    // Partial arc (Google Photos style)
    canvas.drawArc(
      rect,
      pi * 0.15,
      pi * 1.3,
      false,
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}