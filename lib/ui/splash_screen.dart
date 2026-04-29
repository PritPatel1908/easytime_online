import 'package:flutter/material.dart';
import 'dart:async';
import 'package:easytime_online/main/main.dart';
import 'package:path_drawing/path_drawing.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Keep system UI hidden
    SystemUIUtil.hideSystemNavigationBar();

    // Animation duration setup (3 seconds)
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    // Start animation and navigation after first frame so the
    // native/app splash is visible before animations play.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.forward();

      // Navigate to home after splash
      Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(title: 'EasyTime Online'),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Animation (SVG-based)
                const SizedBox(
                  width: 150,
                  height: 150,
                  child: AnimatedIndianInfotechLogo(size: 150),
                ),
                const SizedBox(height: 20),
                // Text Animation
                Opacity(
                  opacity: _animation.value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - _animation.value)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 2.0,
                            ),
                            children: [
                              TextSpan(
                                text: "Indian ",
                                style: TextStyle(
                                  color: Colors.blue[700],
                                ),
                              ),
                              TextSpan(
                                text: "Infotech",
                                style: TextStyle(
                                  color: Colors.green[700],
                                ),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.top,
                                child: Transform.translate(
                                  offset: const Offset(0, -4),
                                  child: const Text(
                                    "®",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          "the solution people...",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2.0,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Animated SVG-based logo built from the original SVG groups.
class AnimatedIndianInfotechLogo extends StatefulWidget {
  final double size;

  const AnimatedIndianInfotechLogo({super.key, this.size = 150});

  @override
  State<AnimatedIndianInfotechLogo> createState() =>
      _AnimatedIndianInfotechLogoState();
}

class _AnimatedIndianInfotechLogoState extends State<AnimatedIndianInfotechLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _opacityAnims;
  late final List<Animation<double>> _scaleAnims;
  late final List<Animation<double>> _translateAnims;
  late final List<Path> _parsedPaths;
  late final List<String> _fills;

  static const _delays = [200, 350, 500, 650, 800, 950];
  static const _partAnimMs = 600;
  static final int _totalMs = _delays.last + _partAnimMs; // 1550

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs),
    );

    const paths = [
      'M7.96639 4.13436C3.12098 7.79713 0 13.5416 0 20C0 24.1229 1.27185 27.9548 3.45224 31.1399C0.60574 18.8235 5.27563 8.00438 7.96639 4.13436Z',
      'M19.3274 0C17.0104 0.122871 14.796 0.623467 12.7472 1.44002C11.6488 3.19959 10.4003 5.5404 9.24994 8.22912C10.5209 7.5429 13.8391 6.11042 16.9443 5.87031C17.8213 3.5107 18.6632 1.47698 19.3274 0Z',
      'M8.98704 36.5893C11.9667 38.5683 15.5077 39.7974 19.3274 40C16.8454 39.7037 11.8813 36.8556 11.8813 27.8344C11.8813 21.8986 14.0304 14.1131 16.2075 7.90964C14.9308 7.90494 11.617 8.29185 8.57551 9.87715C5.34213 18.1516 3.38294 29.0243 8.98704 36.5893Z',
      'M30.3387 27.9232C30.3387 21.8175 34.5144 11.9049 36.6022 7.71179C38.102 9.59991 39.2642 11.758 40 14.099C39.4918 14.7019 38.0357 17.1901 36.2775 22.3196C34.0797 28.7314 35.5293 29.4641 37.2127 29.9679C32.3027 36.2881 30.3387 32.67 30.3387 27.9232Z',
      'M27.5953 38.7734C21.1883 40.9577 18.2275 37.1573 18.2275 27.9229C18.2275 20.6156 20.358 13.3439 22.5251 7.77133C25.6725 7.59013 28.9668 8.78837 30.2205 9.41014C28.7785 12.8389 27.0974 17.7883 25.6711 24.2825C22.4885 38.7734 31.3051 38.3321 36.9147 31.8844C34.5765 34.9861 31.3464 37.4035 27.5953 38.7734Z',
      'M32.9357 4.13412C30.8074 2.5253 28.3465 1.31809 25.6711 0.628418C25.0291 1.94114 24.2209 3.65539 23.3755 5.6687C24.7346 5.87661 28.1027 6.69381 30.7024 8.29936C31.6297 6.22933 32.424 4.84338 32.9357 4.13412Z',
    ];

    _fills = [
      'paintBlue',
      'paintBlue',
      'paintBlue',
      'paintBlue',
      'paintGreen',
      'paintGreen'
    ];

    // Parse SVG path data into Path objects once
    _parsedPaths = paths.map((s) => parseSvgPathData(s)).toList();

    // Prepare per-part animations with staggered intervals
    _opacityAnims = [];
    _scaleAnims = [];
    _translateAnims = [];

    for (var delay in _delays) {
      final start = delay / _totalMs;
      final end = (delay + _partAnimMs) / _totalMs;

      _opacityAnims.add(Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _controller,
            curve: Interval(start, end, curve: Curves.easeIn)),
      ));

      _scaleAnims.add(Tween(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(
            parent: _controller,
            curve: Interval(start, end, curve: Curves.easeOutBack)),
      ));

      _translateAnims.add(Tween(begin: 8.0, end: 0.0).animate(
        CurvedAnimation(
            parent: _controller,
            curve: Interval(start, end, curve: Curves.easeOut)),
      ));
    }

    // Ensure the logo animation starts after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacities = _opacityAnims.map((a) => a.value).toList();
        final scales = _scaleAnims.map((a) => a.value).toList();
        final trans = _translateAnims.map((a) => a.value).toList();

        return CustomPaint(
          size: Size(size, size),
          painter:
              _SvgPartsPainter(_parsedPaths, opacities, scales, trans, _fills),
        );
      },
    );
  }
}

class _SvgPartsPainter extends CustomPainter {
  final List<Path> paths;
  final List<double> opacities;
  final List<double> scales;
  final List<double> translateYs; // pixels
  final List<String> fills;

  _SvgPartsPainter(
      this.paths, this.opacities, this.scales, this.translateYs, this.fills);

  @override
  void paint(Canvas canvas, Size size) {
    const double viewBox = 40.0;
    final double scale = size.width / viewBox;

    // Use a shader rect in SVG coordinate space
    const Rect shaderRect = Rect.fromLTWH(0, 0, viewBox, viewBox);

    canvas.save();
    // scale canvas so Paths (which are in 0..40 space) fill the widget
    canvas.scale(scale, scale);

    for (int i = 0; i < paths.length; i++) {
      final Path p = paths[i];
      final double op =
          (i < opacities.length) ? opacities[i].clamp(0.0, 1.0) : 1.0;
      final double s = (i < scales.length) ? scales[i] : 1.0;
      final double tyPx = (i < translateYs.length) ? translateYs[i] : 0.0;
      final double tySvg = tyPx / scale; // convert screen px to SVG units

      // compute bounds & center for correct scaling around center
      final Rect bounds = p.getBounds();
      final Offset center = bounds.center;

      canvas.save();
      canvas.translate(center.dx, center.dy + tySvg);
      canvas.scale(s, s);
      canvas.translate(-center.dx, -center.dy);

      // build paint with gradient shader
      Paint paint = Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      Shader shader;
      if (fills[i] == 'paintBlue') {
        shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF00A8FF), Color(0xFF007CF0)],
        ).createShader(shaderRect);
      } else {
        shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6DD400), Color(0xFF3FA800)],
        ).createShader(shaderRect);
      }

      // apply opacity via saveLayer for correct alpha with shader
      canvas.saveLayer(
          shaderRect, Paint()..color = Colors.white.withOpacity(op));
      paint.shader = shader;
      canvas.drawPath(p, paint);
      canvas.restore(); // restore layer

      canvas.restore(); // restore transforms
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SvgPartsPainter oldDelegate) => true;
}
