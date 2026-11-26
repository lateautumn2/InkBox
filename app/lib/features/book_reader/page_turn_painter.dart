import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'book_reader_settings.dart';

/// Programmatic controller allowing tap-zones and volume keys to trigger the exact
/// same fluid Simulation / Cover / Slide animations as manual finger drags.
class PageTurnController {
  _PageTurnStageState? _state;

  bool get isAnimating => _state?._isAnimating ?? false;

  void _attach(_PageTurnStageState state) {
    _state = state;
  }

  void _detach(_PageTurnStageState state) {
    if (_state == state) _state = null;
  }

  /// Animates a forward page turn (`current -> next`).
  bool turnNext() => _state?._triggerProgrammaticTurn(forward: true) ?? false;

  /// Animates a backward page turn (`current -> prev`).
  bool turnPrev() => _state?._triggerProgrammaticTurn(forward: false) ?? false;
}

/// Interactive page-turn container supporting Simulation (cohesive Bezier page curl),
/// Cover (crisp sliding top sheet with directional spine shadow), and Slide transitions
/// with real finger-tracking physics and programmatic tap/volume-key animation.
class PageTurnStage extends StatefulWidget {
  const PageTurnStage({
    super.key,
    required this.mode,
    required this.currentPage,
    required this.previousPage,
    required this.nextPage,
    required this.paperColor,
    required this.onTurnNext,
    required this.onTurnPrev,
    required this.onTapNormalized,
    this.controller,
    this.canTurnPrev,
    this.canTurnNext,
    this.onBoundaryReached,
    this.onInterceptTap,
    this.selectionActive = false,
    this.isDualSpread = false,
  });

  final PageTurnMode mode;
  final PageTurnController? controller;
  final Widget currentPage;
  final Widget? previousPage;
  final Widget? nextPage;
  final bool? canTurnPrev;
  final bool? canTurnNext;
  final Color paperColor;
  final VoidCallback onTurnNext;
  final VoidCallback onTurnPrev;
  final void Function(bool isEnd)? onBoundaryReached;
  final void Function(double nx, double ny) onTapNormalized;
  final bool Function(Offset globalPosition)? onInterceptTap;
  final bool selectionActive;
  final bool isDualSpread;

  bool get effectiveCanTurnNext => canTurnNext ?? (nextPage != null);
  bool get effectiveCanTurnPrev => canTurnPrev ?? (previousPage != null);

  @override
  State<PageTurnStage> createState() => _PageTurnStageState();
}

class _PageTurnStageState extends State<PageTurnStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  double _dragProgress = 0.0; // -1.0 (turn next) .. +1.0 (turn prev)
  double _touchY = 0.62;
  double _startAnimFrom = 0.0;
  double _targetAnimTo = 0.0;
  Curve _activeCurve = Curves.easeOutCubic;
  bool _isDragging = false;
  bool _isAnimating = false;
  bool _isCommitting = false;
  int _animToken = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        final t = _activeCurve.transform(_anim.value);
        setState(() {
          _dragProgress = _startAnimFrom + (_targetAnimTo - _startAnimFrom) * t;
        });
      });
  }

  @override
  void didUpdateWidget(covariant PageTurnStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _anim.dispose();
    super.dispose();
  }

  bool _triggerProgrammaticTurn({required bool forward}) {
    if (_isCommitting || _isDragging) return false;
    if (forward && !widget.effectiveCanTurnNext) {
      widget.onBoundaryReached?.call(true);
      return false;
    }
    if (!forward && !widget.effectiveCanTurnPrev) {
      widget.onBoundaryReached?.call(false);
      return false;
    }
    _touchY = 0.58;
    _animateTo(
      forward ? -1.0 : 1.0,
      curve: Curves.easeInOutCubic,
      commitTurn: true,
      onComplete: forward ? widget.onTurnNext : widget.onTurnPrev,
    );
    return true;
  }

  void _animateTo(
    double target, {
    Curve curve = Curves.easeOutCubic,
    bool commitTurn = false,
    VoidCallback? onComplete,
  }) {
    final token = ++_animToken;
    _startAnimFrom = _dragProgress;
    _targetAnimTo = target;
    _activeCurve = curve;
    _isAnimating = true;
    _isCommitting = commitTurn;

    final distance = (target - _dragProgress).abs().clamp(0.0, 1.0);
    final ms = (130 + distance * 190).round().clamp(140, 320);
    _anim.duration = Duration(milliseconds: ms);
    _anim.reset();

    _anim.forward().orCancel.then((_) {
      if (!mounted || token != _animToken) return;
      _isAnimating = false;
      _isCommitting = false;
      if (onComplete != null) {
        onComplete();
      }
      if (mounted && token == _animToken) {
        setState(() {
          _dragProgress = 0.0;
        });
      }
    }).catchError((_) {
      // Cancelled cleanly by a new drag or dispose
    });
  }

  void _handleDragStart(DragStartDetails d, Size size) {
    if (_isCommitting) return;
    _animToken++;
    _anim.stop();
    _isAnimating = false;
    _isDragging = true;
    _touchY = (d.localPosition.dy / size.height).clamp(0.14, 0.86);
  }

  void _handleDragUpdate(DragUpdateDetails d, Size size) {
    if (!_isDragging || size.width <= 0) return;
    final rawDelta = d.delta.dx / size.width;
    var candidate = _dragProgress + rawDelta;

    // Gentle rubber-band damping if dragging past the very first or last page of the book
    if (candidate < 0 && !widget.effectiveCanTurnNext) {
      candidate = (_dragProgress + rawDelta * 0.22).clamp(-0.14, 0.0);
    } else if (candidate > 0 && !widget.effectiveCanTurnPrev) {
      candidate = (_dragProgress + rawDelta * 0.22).clamp(0.0, 0.14);
    } else {
      candidate = candidate.clamp(-1.0, 1.0);
    }

    setState(() {
      _dragProgress = candidate;
      _touchY = (d.localPosition.dy / size.height).clamp(0.14, 0.86);
    });
  }

  void _handleDragEnd(DragEndDetails d) {
    if (!_isDragging) return;
    _isDragging = false;
    final vx = d.primaryVelocity ?? 0.0;

    final wantsNext =
        _dragProgress < -0.14 || (vx < -280 && _dragProgress <= 0.02);
    final wantsPrev =
        _dragProgress > 0.14 || (vx > 280 && _dragProgress >= -0.02);

    if (wantsNext) {
      if (widget.effectiveCanTurnNext) {
        _animateTo(-1.0, commitTurn: true, onComplete: widget.onTurnNext);
      } else {
        _animateTo(0.0);
        widget.onBoundaryReached?.call(true);
      }
    } else if (wantsPrev) {
      if (widget.effectiveCanTurnPrev) {
        _animateTo(1.0, commitTurn: true, onComplete: widget.onTurnPrev);
      } else {
        _animateTo(0.0);
        widget.onBoundaryReached?.call(false);
      }
    } else {
      _animateTo(0.0);
    }
  }

  void _handleDragCancel() {
    if (!_isDragging) return;
    _isDragging = false;
    _animateTo(0.0);
  }

  Widget _fallbackPaper() => ColoredBox(color: widget.paperColor);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final turningNext = _dragProgress < 0;
        final turningPrev = _dragProgress > 0;
        final absP = _dragProgress.abs();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            if (_isDragging || _isCommitting || size.width <= 0 || size.height <= 0) {
              return;
            }
            if (widget.onInterceptTap?.call(d.globalPosition) == true) {
              return;
            }
            widget.onTapNormalized(
              (d.localPosition.dx / size.width).clamp(0.0, 1.0),
              (d.localPosition.dy / size.height).clamp(0.0, 1.0),
            );
          },
          onHorizontalDragStart: widget.selectionActive
              ? null
              : (d) => _handleDragStart(d, size),
          onHorizontalDragUpdate: widget.selectionActive
              ? null
              : (d) => _handleDragUpdate(d, size),
          onHorizontalDragEnd: widget.selectionActive ? null : _handleDragEnd,
          onHorizontalDragCancel:
              widget.selectionActive ? null : _handleDragCancel,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: _buildLayers(size, turningNext, turningPrev, absP),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildLayers(
    Size size,
    bool turningNext,
    bool turningPrev,
    double absP,
  ) {
    if (absP < 0.001) {
      return [widget.currentPage];
    }

    switch (widget.mode) {
      case PageTurnMode.slide:
        final seamX = turningNext
            ? size.width * (1.0 - absP)
            : size.width * absP;
        return [
          if (turningNext && widget.effectiveCanTurnNext)
            Transform.translate(
              offset: Offset(size.width * (1.0 - absP), 0),
              child: widget.nextPage ?? _fallbackPaper(),
            )
          else if (turningNext)
            _fallbackPaper(),
          if (turningPrev && widget.effectiveCanTurnPrev)
            Transform.translate(
              offset: Offset(-size.width * (1.0 - absP), 0),
              child: widget.previousPage ?? _fallbackPaper(),
            )
          else if (turningPrev)
            _fallbackPaper(),
          Transform.translate(
            offset: Offset(size.width * _dragProgress, 0),
            child: widget.currentPage,
          ),
          if (seamX > 1 && seamX < size.width - 1)
            Positioned(
              left: seamX - 0.5,
              top: 0,
              bottom: 0,
              width: 1,
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.10),
                ),
              ),
            ),
        ];

      case PageTurnMode.cover:
        // Clean Legado-style cover transition: top sheet slides horizontally over a
        // stationary underneath page with a crisp directional right-edge shadow strip.
        final edgeFade = (1.0 - absP * 0.65).clamp(0.0, 1.0);
        if (turningNext) {
          final edgeX = (size.width * (1.0 - absP)).clamp(0.0, size.width);
          return [
            widget.effectiveCanTurnNext
                ? (widget.nextPage ?? _fallbackPaper())
                : _fallbackPaper(),
            Transform.translate(
              offset: Offset(size.width * _dragProgress, 0),
              child: widget.currentPage,
            ),
            if (edgeX > 0 && edgeX < size.width)
              Positioned(
                left: edgeX,
                top: 0,
                bottom: 0,
                width: 24,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.28 * edgeFade),
                          Colors.black.withValues(alpha: 0.08 * edgeFade),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.42, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
          ];
        } else {
          final edgeX = (size.width * absP).clamp(0.0, size.width);
          if (!widget.effectiveCanTurnPrev) {
            return [
              _fallbackPaper(),
              Transform.translate(
                offset: Offset(size.width * _dragProgress, 0),
                child: widget.currentPage,
              ),
            ];
          }
          return [
            widget.currentPage,
            Transform.translate(
              offset: Offset(-size.width * (1.0 - absP), 0),
              child: widget.previousPage ?? _fallbackPaper(),
            ),
            if (edgeX > 0 && edgeX < size.width)
              Positioned(
                left: edgeX,
                top: 0,
                bottom: 0,
                width: 24,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.28 * edgeFade),
                          Colors.black.withValues(alpha: 0.08 * edgeFade),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.42, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
          ];
        }

      case PageTurnMode.simulation:
      case PageTurnMode.scroll:
        // Cohesive Bezier simulation curl: top clip, rolled paper back-face,
        // inner drop shadow, and cast shadow all follow the exact same spine curve.
        if ((turningNext && !widget.effectiveCanTurnNext) ||
            (turningPrev && !widget.effectiveCanTurnPrev)) {
          return [
            _fallbackPaper(),
            Transform.translate(
              offset: Offset(size.width * _dragProgress, 0),
              child: widget.currentPage,
            ),
          ];
        }

        if (widget.isDualSpread && widget.mode == PageTurnMode.simulation) {
          return _buildDualSpreadSimulation(size, turningNext, absP);
        }

        final underPage = turningNext
            ? (widget.nextPage ?? _fallbackPaper())
            : widget.currentPage;
        final topPage = turningNext
            ? widget.currentPage
            : (widget.previousPage ?? _fallbackPaper());
        final foldX = turningNext
            ? size.width * (1.0 - absP)
            : size.width * absP;
        final geom = _CurlGeometry.compute(
          size: size,
          foldX: foldX,
          pivotY: _touchY,
        );

        return [
          underPage,
          ClipPath(
            clipper: _PageCurlClipper(geom: geom),
            child: topPage,
          ),
          IgnorePointer(
            child: CustomPaint(
              size: size,
              painter: _PageCurlPainter(
                geom: geom,
                paperColor: widget.paperColor,
              ),
            ),
          ),
        ];
    }
  }

  List<Widget> _buildDualSpreadSimulation(
    Size size,
    bool turningNext,
    double absP,
  ) {
    final incoming = turningNext
        ? (widget.nextPage ?? _fallbackPaper())
        : (widget.previousPage ?? _fallbackPaper());
    final firstHalfOfDrag = absP < 0.5;

    if (turningNext) {
      if (firstHalfOfDrag) {
        final foldX = size.width * (1.0 - absP);
        final geom = _CurlGeometry.compute(
          size: size,
          foldX: foldX,
          pivotY: _touchY,
        );
        return [
          incoming,
          ClipPath(
            clipper: _PageCurlClipper(geom: geom),
            child: widget.currentPage,
          ),
          IgnorePointer(
            child: CustomPaint(
              size: size,
              painter: _PageCurlPainter(
                geom: geom,
                paperColor: widget.paperColor,
              ),
            ),
          ),
        ];
      }

      final revealX = (size.width * 0.5) * (1.0 - (absP - 0.5) * 2.0);
      final spineShade = ((1.0 - (absP - 0.5) * 2.0) * 0.16).clamp(0.0, 0.2);
      return [
        widget.currentPage,
        ClipRect(
          clipper: _HorizontalRectClipper(left: revealX, right: size.width),
          child: incoming,
        ),
        if (revealX > 1)
          Positioned(
            left: (revealX - 18).clamp(0.0, size.width),
            top: 0,
            bottom: 0,
            width: 18,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: spineShade),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ];
    }

    if (firstHalfOfDrag) {
      final revealX = size.width * absP;
      final spineShade = (absP * 2.0 * 0.16).clamp(0.0, 0.2);
      return [
        incoming,
        ClipRect(
          clipper: _HorizontalRectClipper(left: revealX, right: size.width),
          child: widget.currentPage,
        ),
        if (revealX > 1)
          Positioned(
            left: (revealX - 18).clamp(0.0, size.width),
            top: 0,
            bottom: 0,
            width: 18,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: spineShade),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ];
    }

    final foldX = size.width * absP;
    final geom = _CurlGeometry.compute(
      size: size,
      foldX: foldX,
      pivotY: _touchY,
    );
    return [
      widget.currentPage,
      ClipPath(
        clipper: _PageCurlClipper(geom: geom),
        child: incoming,
      ),
      IgnorePointer(
        child: CustomPaint(
          size: size,
          painter: _PageCurlPainter(
            geom: geom,
            paperColor: widget.paperColor,
          ),
        ),
      ),
    ];
  }
}

class _HorizontalRectClipper extends CustomClipper<Rect> {
  const _HorizontalRectClipper({required this.left, required this.right});

  final double left;
  final double right;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
        left.clamp(0.0, size.width),
        0,
        right.clamp(0.0, size.width),
        size.height,
      );

  @override
  bool shouldReclip(_HorizontalRectClipper old) =>
      old.left != left || old.right != right;
}

class _CurlGeometry {
  const _CurlGeometry({
    required this.foldX,
    required this.pivotY,
    required this.edgeFactor,
    required this.xTop,
    required this.xCtrl,
    required this.xBot,
    required this.py,
    required this.foldW,
    required this.shadowW,
  });

  final double foldX;
  final double pivotY;
  final double edgeFactor;
  final double xTop;
  final double xCtrl;
  final double xBot;
  final double py;
  final double foldW;
  final double shadowW;

  factory _CurlGeometry.compute({
    required Size size,
    required double foldX,
    required double pivotY,
  }) {
    final w = size.width <= 0 ? 1.0 : size.width;
    final h = size.height <= 0 ? 1.0 : size.height;
    final clampedFoldX = foldX.clamp(0.0, w);
    final norm = (clampedFoldX / w).clamp(0.0, 1.0);
    // Smooth sine envelope: 0 right at both edges, 1 at center -> zero edge artifacts
    final edgeFactor = math.sin(math.pi * norm);
    final bow = math.min(34.0, w * 0.095) * edgeFactor;
    final tilt = (pivotY - 0.5) * 34.0 * edgeFactor;
    final py = h * pivotY;

    final xTop = (clampedFoldX + bow * 0.42 - tilt).clamp(0.0, w);
    final xCtrl = (clampedFoldX - bow * 0.58).clamp(0.0, w);
    final xBot = (clampedFoldX + bow * 0.42 + tilt).clamp(0.0, w);

    final peeledWidth = (w - clampedFoldX).clamp(0.0, w);
    final foldW = math.min(52.0, peeledWidth * 0.34) * (0.28 + 0.72 * edgeFactor);
    final shadowW = 28.0 * (0.18 + 0.82 * edgeFactor);

    return _CurlGeometry(
      foldX: clampedFoldX,
      pivotY: pivotY,
      edgeFactor: edgeFactor,
      xTop: xTop,
      xCtrl: xCtrl,
      xBot: xBot,
      py: py,
      foldW: foldW,
      shadowW: shadowW,
    );
  }
}

class _PageCurlClipper extends CustomClipper<Path> {
  const _PageCurlClipper({required this.geom});

  final _CurlGeometry geom;

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(geom.xTop, 0)
      ..quadraticBezierTo(geom.xCtrl, geom.py, geom.xBot, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_PageCurlClipper old) =>
      old.geom.foldX != geom.foldX || old.geom.pivotY != geom.pivotY;
}

class _PageCurlPainter extends CustomPainter {
  const _PageCurlPainter({
    required this.geom,
    required this.paperColor,
  });

  final _CurlGeometry geom;
  final Color paperColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (geom.edgeFactor < 0.015) return;

    final h = size.height;
    final w = size.width;
    final isDarkPaper = paperColor.computeLuminance() < 0.25;

    // 1. Curved cast shadow falling onto the revealed underneath page (right of spine)
    if (geom.shadowW > 1.0) {
      final sTopR = (geom.xTop + geom.shadowW).clamp(0.0, w);
      final sCtrlR = (geom.xCtrl + geom.shadowW).clamp(0.0, w);
      final sBotR = (geom.xBot + geom.shadowW).clamp(0.0, w);

      final shadowPath = Path()
        ..moveTo(geom.xTop, 0)
        ..quadraticBezierTo(geom.xCtrl, geom.py, geom.xBot, h)
        ..lineTo(sBotR, h)
        ..quadraticBezierTo(sCtrlR, geom.py, sTopR, 0)
        ..close();

      final minX = math.min(geom.xCtrl, math.min(geom.xTop, geom.xBot));
      final maxX = math.max(sCtrlR, math.max(sTopR, sBotR));
      if (maxX > minX + 0.5) {
        final shadowRect = Rect.fromLTRB(minX, 0, maxX, h);
        final peakAlpha = (isDarkPaper ? 0.52 : 0.30) * geom.edgeFactor;
        final shadowPaint = Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.black.withValues(alpha: peakAlpha),
              Colors.black.withValues(alpha: peakAlpha * 0.28),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(shadowRect);
        canvas.drawPath(shadowPath, shadowPaint);
      }
    }

    // 2. Curved rolled paper back-face immediately to the left of the spine
    if (geom.foldW > 1.5) {
      final bTopL = (geom.xTop - geom.foldW).clamp(0.0, w);
      final bCtrlL = (geom.xCtrl - geom.foldW).clamp(0.0, w);
      final bBotL = (geom.xBot - geom.foldW).clamp(0.0, w);

      // Soft drop shadow cast by the curled flap onto the flat left portion of top page
      final innerW = math.min(14.0, geom.foldW * 0.42);
      final iTopL = (bTopL - innerW).clamp(0.0, w);
      final iCtrlL = (bCtrlL - innerW).clamp(0.0, w);
      final iBotL = (bBotL - innerW).clamp(0.0, w);
      if (bCtrlL > iCtrlL + 0.5) {
        final innerShadowPath = Path()
          ..moveTo(iTopL, 0)
          ..lineTo(bTopL, 0)
          ..quadraticBezierTo(bCtrlL, geom.py, bBotL, h)
          ..lineTo(iBotL, h)
          ..quadraticBezierTo(iCtrlL, geom.py, iTopL, 0)
          ..close();
        final iRect = Rect.fromLTRB(
          math.min(iCtrlL, math.min(iTopL, iBotL)),
          0,
          math.max(bCtrlL, math.max(bTopL, bBotL)),
          h,
        );
        final innerPaint = Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.16 * geom.edgeFactor),
            ],
          ).createShader(iRect);
        canvas.drawPath(innerShadowPath, innerPaint);
      }

      // Rolled cylindrical paper highlight & shading along the exact same Bezier curve
      final backPath = Path()
        ..moveTo(bTopL, 0)
        ..lineTo(geom.xTop, 0)
        ..quadraticBezierTo(geom.xCtrl, geom.py, geom.xBot, h)
        ..lineTo(bBotL, h)
        ..quadraticBezierTo(bCtrlL, geom.py, bTopL, 0)
        ..close();

      final backMinX = math.min(bCtrlL, math.min(bTopL, bBotL));
      final backMaxX = math.max(geom.xCtrl, math.max(geom.xTop, geom.xBot));
      if (backMaxX > backMinX + 0.5) {
        final backRect = Rect.fromLTRB(backMinX, 0, backMaxX, h);
        final cOuter = Color.lerp(
          paperColor,
          isDarkPaper ? Colors.white : Colors.black,
          isDarkPaper ? 0.06 : 0.14,
        )!;
        final cHighlight = Color.lerp(
          paperColor,
          Colors.white,
          isDarkPaper ? 0.14 : 0.34,
        )!;
        final cCrease = Color.lerp(
          paperColor,
          Colors.black,
          isDarkPaper ? 0.32 : 0.18,
        )!;

        final backPaint = Paint()
          ..shader = LinearGradient(
            colors: [cOuter, cHighlight, paperColor, cCrease],
            stops: const [0.0, 0.34, 0.72, 1.0],
          ).createShader(backRect);
        canvas.drawPath(backPath, backPaint);

        // Crisp paper-edge highlight stroke along the spine curve
        final edgeStroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = (isDarkPaper ? Colors.white : Colors.black)
              .withValues(alpha: 0.14 * geom.edgeFactor);
        final spinePath = Path()
          ..moveTo(geom.xTop, 0)
          ..quadraticBezierTo(geom.xCtrl, geom.py, geom.xBot, h);
        canvas.drawPath(spinePath, edgeStroke);
      }
    }
  }

  @override
  bool shouldRepaint(_PageCurlPainter old) =>
      old.geom.foldX != geom.foldX ||
      old.geom.pivotY != geom.pivotY ||
      old.paperColor != paperColor;
}
