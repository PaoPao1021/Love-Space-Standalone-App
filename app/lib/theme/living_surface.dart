import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Paint-only ambient motion: content never relayouts or flickers with the light.
class LivingSurface extends StatefulWidget {
  const LivingSurface({required this.child, this.dark = false, super.key});
  final Widget child;
  final bool dark;
  @override
  State<LivingSurface> createState() => _LivingSurfaceState();
}

class _LivingSurfaceState extends State<LivingSurface>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );
  bool _paused = false;
  bool _foreground = true;
  bool _pressed = false;
  ScrollPosition? _scroll;

  bool get _visible {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return true;
    final origin = box.localToGlobal(Offset.zero);
    return (origin & box.size).overlaps(
      Offset.zero & MediaQuery.sizeOf(context),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _sync() {
    final enabled =
        !_paused &&
        _foreground &&
        _visible &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (enabled && !_motion.isAnimating) _motion.repeat();
    if (!enabled) _motion.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scroll = Scrollable.maybeOf(context)?.position;
    if (_scroll != scroll) {
      _scroll?.removeListener(_sync);
      _scroll = scroll;
      _scroll?.addListener(_sync);
    }
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll?.removeListener(_sync);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Listener(
          onPointerDown: (_) => setState(() => _pressed = true),
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed && !reduced ? .975 : 1,
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  widget.child,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _LoveLight(_motion, widget.dark),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: reduced
                ? null
                : () {
                    setState(() => _paused = !_paused);
                    _sync();
                  },
            icon: Icon(
              _paused || reduced
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              size: 16,
            ),
            label: Text(
              reduced
                  ? '已跟随系统关闭动效'
                  : _paused
                  ? '播放氛围'
                  : '暂停氛围',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoveLight extends CustomPainter {
  _LoveLight(this.motion, this.dark) : super(repaint: motion);
  final Animation<double> motion;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final t = motion.value * math.pi * 2;
    final color = dark ? const Color(0xFFFFB9CC) : const Color(0xFFE85D75);
    // A broad satin highlight moves along the surface, not across the text layout.
    final center = Offset(
      size.width * (.5 + .4 * math.sin(t)),
      size.height * .35,
    );
    final radius = size.width * .65;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: dark ? .18 : .075),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    // Hearts stay at the edges, away from the reading and input areas.
    for (var i = 0; i < 7; i++) {
      final phase = (motion.value + i / 7) % 1;
      final x = size.width * (i.isEven ? .045 : .94) + math.sin(t + i) * 7;
      final y = size.height * (1 - phase);
      final opacity = math.sin(phase * math.pi) * (dark ? .6 : .28);
      final r = 4.0 + i % 3 * 2;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(t + i) * .18);
      final heart = Path()
        ..moveTo(0, r)
        ..cubicTo(-r * 2, -r * .2, -r, -r * 1.7, 0, -r * .65)
        ..cubicTo(r, -r * 1.7, r * 2, -r * .2, 0, r);
      canvas.drawPath(heart, Paint()..color = color.withValues(alpha: opacity));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LoveLight oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.motion != motion;
}
