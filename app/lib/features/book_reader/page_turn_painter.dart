import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
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
    this.enableEdgeVerticalDrag = false,
    this.edgeZoneWidth = 56.0,
    this.onEdgeVerticalDragUpdate,
    this.onEdgeVerticalDragEnd,
    this.onSwipeUpAction,
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
  final bool enableEdgeVerticalDrag;
  final double edgeZoneWidth;
  final void Function(double deltaY, double viewportHeight)?
      onEdgeVerticalDragUpdate;
  final VoidCallback? onEdgeVerticalDragEnd;
  final VoidCallback? onSwipeUpAction;

  bool get effectiveCanTurnNext => canTurnNext ?? (nextPage != null);
  bool get effectiveCanTurnPrev => canTurnPrev ?? (previousPage != null);

  @override
  State<PageTurnStage> createState() => _PageTurnStageState();
}

enum _DragMode { undecided, horizontal, edgeBrightness, bodySwipeUp }

class _PageTurnStageState extends State<PageTurnStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  double _dragProgress = 0.0; // -1.0 (turn next) .. +1.0 (turn prev)
  double _touchY = 0.62;
  double _dragStartY = 0.78;
  double _startAnimFrom = 0.0;
  double _targetAnimTo = 0.0;
  Curve _activeCurve = Curves.easeOutCubic;
  bool _isDragging = false;
  bool _isAnimating = false;
  bool _isCommitting = false;
  int _animToken = 0;
  _DragMode _dragMode = _DragMode.undecided;
  Offset _panOrigin = Offset.zero;
  Offset _panDelta = Offset.zero;

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
    _dragStartY = 0.78;
    _touchY = 0.72;
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

  void _handleDragStart(Offset origin, Size size) {
    if (_isCommitting) return;
    _animToken++;
    _anim.stop();
    _isAnimating = false;
    _isDragging = true;
    final relY = size.height > 0
        ? (origin.dy / size.height).clamp(0.06, 0.94)
        : 0.62;
    _dragStartY = relY;
    _touchY = relY;
  }

  void _handleDragUpdate(DragUpdateDetails d, Size size, double deltaX) {
    if (!_isDragging || size.width <= 0) return;
    final rawDelta = deltaX / size.width;
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
      _touchY = (d.localPosition.dy / size.height).clamp(0.06, 0.94);
    });
  }

  void _handlePanStart(DragStartDetails details) {
    _panOrigin = details.localPosition;
    _panDelta = Offset.zero;
    _dragMode = _DragMode.undecided;
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    if (_isCommitting || size.isEmpty) return;
    final delta = details.localPosition - _panOrigin;
    var frameDelta = delta - _panDelta;
    _panDelta = delta;

    if (_dragMode == _DragMode.undecided) {
      final insets = MediaQuery.systemGestureInsetsOf(context);
      final inReadingArea = _panOrigin.dy > insets.top + 24 &&
          _panOrigin.dy < size.height - insets.bottom - 48;
      final onBrightnessEdge = _panOrigin.dx >= insets.left &&
          _panOrigin.dx < insets.left + widget.edgeZoneWidth;
      final cornerWidth =
          (size.width * (widget.isDualSpread ? 0.18 : 0.24)).clamp(56.0, 160.0);
      final nearRight = _panOrigin.dx >= size.width - cornerWidth;
      final nearLeft = _panOrigin.dx <= cornerWidth;
      final nearTopOrBottom = _panOrigin.dy < size.height * 0.28 ||
          _panOrigin.dy > size.height * 0.72;
      final simulationCorner = widget.mode == PageTurnMode.simulation &&
          nearTopOrBottom && (nearRight || nearLeft);
      final diagonallyTurning = simulationCorner &&
          ((nearRight && delta.dx < 0) || (nearLeft && delta.dx > 0)) &&
          delta.dx.abs() >= delta.dy.abs() * 0.22;

      if (delta.dx.abs() > delta.dy.abs() || diagonallyTurning) {
        _dragMode = _DragMode.horizontal;
        _handleDragStart(_panOrigin, size);
      } else if (inReadingArea && onBrightnessEdge && widget.enableEdgeVerticalDrag) {
        _dragMode = _DragMode.edgeBrightness;
      } else if (inReadingArea &&
          !onBrightnessEdge &&
          !simulationCorner &&
          widget.onSwipeUpAction != null) {
        _dragMode = _DragMode.bodySwipeUp;
      }
      frameDelta = delta;
    }

    switch (_dragMode) {
      case _DragMode.horizontal:
        _handleDragUpdate(details, size, frameDelta.dx);
      case _DragMode.edgeBrightness:
        widget.onEdgeVerticalDragUpdate?.call(frameDelta.dy, size.height);
      case _DragMode.bodySwipeUp:
      case _DragMode.undecided:
        break;
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    switch (_dragMode) {
      case _DragMode.horizontal:
        _handleDragEnd(details);
      case _DragMode.edgeBrightness:
        widget.onEdgeVerticalDragEnd?.call();
      case _DragMode.bodySwipeUp:
        if (_panDelta.dy <= -56.0 && _panDelta.dx.abs() <= -_panDelta.dy * 0.65) {
          widget.onSwipeUpAction?.call();
        }
      case _DragMode.undecided:
        break;
    }
    _dragMode = _DragMode.undecided;
  }

  void _handlePanCancel() {
    if (_dragMode == _DragMode.edgeBrightness) {
      widget.onEdgeVerticalDragEnd?.call();
    }
    _dragMode = _DragMode.undecided;
    _handleDragCancel();
  }

  void _handleDragEnd(DragEndDetails d) {
    if (!_isDragging) return;
    _isDragging = false;
    final vx = d.velocity.pixelsPerSecond.dx;

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
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: widget.selectionActive ? null : _handlePanStart,
          onPanUpdate: widget.selectionActive
              ? null
              : (details) => _handlePanUpdate(details, size),
          onPanEnd: widget.selectionActive ? null : _handlePanEnd,
          onPanCancel: widget.selectionActive ? null : _handlePanCancel,
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
          startY: _dragStartY,
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

}

enum _CurlCorner { topRight, middleEdge, bottomRight }

class _CurlGeometry {
  const _CurlGeometry({
    required this.foldX,
    required this.pivotY,
    required this.startY,
    required this.edgeFactor,
    required this.corner,
    required this.xTop,
    required this.xCtrl,
    required this.xBot,
    required this.py,
    required this.foldW,
    required this.shadowW,
    this.frontPoly = const [],
    this.backPoly = const [],
    this.creaseStart = Offset.zero,
    this.creaseEnd = Offset.zero,
    this.creaseNormal = const Offset(1, 0),
    this.flapDepth = 0.0,
    this.isComplete = false,
  });

  final double foldX;
  final double pivotY;
  final double startY;
  final double edgeFactor;
  final _CurlCorner corner;
  final double xTop;
  final double xCtrl;
  final double xBot;
  final double py;
  final double foldW;
  final double shadowW;
  final List<Offset> frontPoly;
  final List<Offset> backPoly;
  final Offset creaseStart;
  final Offset creaseEnd;
  final Offset creaseNormal;
  final double flapDepth;
  final bool isComplete;

  factory _CurlGeometry.compute({
    required Size size,
    required double foldX,
    required double pivotY,
    double startY = 0.5,
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

    final corner = startY < 0.36
        ? _CurlCorner.topRight
        : (startY > 0.64 ? _CurlCorner.bottomRight : _CurlCorner.middleEdge);

    if (corner == _CurlCorner.middleEdge) {
      return _CurlGeometry(
        foldX: clampedFoldX,
        pivotY: pivotY,
        startY: startY,
        edgeFactor: edgeFactor,
        corner: corner,
        xTop: xTop,
        xCtrl: xCtrl,
        xBot: xBot,
        py: py,
        foldW: foldW,
        shadowW: shadowW,
      );
    }

    final pageRect = <Offset>[
      Offset.zero,
      Offset(w, 0),
      Offset(w, h),
      Offset(0, h),
    ];

    if (norm >= 0.998) {
      return _CurlGeometry(
        foldX: clampedFoldX,
        pivotY: pivotY,
        startY: startY,
        edgeFactor: edgeFactor,
        corner: corner,
        xTop: xTop,
        xCtrl: xCtrl,
        xBot: xBot,
        py: py,
        foldW: foldW,
        shadowW: shadowW,
        frontPoly: pageRect,
      );
    }

    if (norm <= 0.002) {
      return _CurlGeometry(
        foldX: clampedFoldX,
        pivotY: pivotY,
        startY: startY,
        edgeFactor: edgeFactor,
        corner: corner,
        xTop: xTop,
        xCtrl: xCtrl,
        xBot: xBot,
        py: py,
        foldW: foldW,
        shadowW: shadowW,
        isComplete: true,
      );
    }

    final peelDist = (w - clampedFoldX).clamp(0.0, w);
    final ax = w - peelDist * 2.05;
    final Offset anchorCorner;
    final Offset foldedCorner;
    if (corner == _CurlCorner.topRight) {
      final targetDrop = (pivotY * h).clamp(28.0, h * 0.72);
      final ay = (math.min(targetDrop, peelDist * 0.85 + targetDrop * 0.35) *
              edgeFactor)
          .clamp(0.0, h * 0.75);
      anchorCorner = Offset(w, 0);
      foldedCorner = Offset(ax, ay);
    } else {
      final targetLift = ((1.0 - pivotY) * h).clamp(28.0, h * 0.72);
      final ay = h -
          (math.min(targetLift, peelDist * 0.85 + targetLift * 0.35) *
                  edgeFactor)
              .clamp(0.0, h * 0.75);
      anchorCorner = Offset(w, h);
      foldedCorner = Offset(ax, ay);
    }

    final diff = anchorCorner - foldedCorner;
    final len = diff.distance <= 1e-4 ? 1.0 : diff.distance;
    final n = Offset(diff.dx / len, diff.dy / len);
    final g = Offset(
      (anchorCorner.dx + foldedCorner.dx) * 0.5,
      (anchorCorner.dy + foldedCorner.dy) * 0.5,
    );

    double signedDist(Offset p) => (p.dx - g.dx) * n.dx + (p.dy - g.dy) * n.dy;

    final frontPoly = _clipHalfPlane(pageRect, (p) => signedDist(p) <= 1e-3, (a, b) {
      final da = signedDist(a);
      final db = signedDist(b);
      final denom = da - db;
      final t = denom.abs() < 1e-6 ? 0.5 : (da / denom).clamp(0.0, 1.0);
      return Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
    });

    final peeledPoly = _clipHalfPlane(pageRect, (p) => signedDist(p) >= -1e-3, (a, b) {
      final da = signedDist(a);
      final db = signedDist(b);
      final denom = da - db;
      final t = denom.abs() < 1e-6 ? 0.5 : (da / denom).clamp(0.0, 1.0);
      return Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
    });

    var reflected = peeledPoly.map((p) {
      final d = signedDist(p);
      return Offset(p.dx - 2 * d * n.dx, p.dy - 2 * d * n.dy);
    }).toList();
    reflected = _clipRect(reflected, w, h);

    // Determine crease segment inside front rect and max flap depth along -n.
    final creasePts = frontPoly.where((p) => signedDist(p).abs() <= 0.75).toList();
    final Offset c0;
    final Offset c1;
    if (creasePts.length >= 2) {
      c0 = creasePts.first;
      c1 = creasePts.last;
    } else {
      c0 = Offset(clampedFoldX, 0);
      c1 = Offset(clampedFoldX, h);
    }

    var maxDepth = 0.0;
    for (final p in reflected) {
      final d = -signedDist(p);
      if (d > maxDepth) maxDepth = d;
    }

    return _CurlGeometry(
      foldX: clampedFoldX,
      pivotY: pivotY,
      startY: startY,
      edgeFactor: edgeFactor,
      corner: corner,
      xTop: xTop,
      xCtrl: xCtrl,
      xBot: xBot,
      py: py,
      foldW: foldW,
      shadowW: shadowW,
      frontPoly: frontPoly,
      backPoly: reflected,
      creaseStart: c0,
      creaseEnd: c1,
      creaseNormal: n,
      flapDepth: maxDepth,
    );
  }

  static List<Offset> _clipHalfPlane(
    List<Offset> poly,
    bool Function(Offset p) inside,
    Offset Function(Offset a, Offset b) intersect,
  ) {
    if (poly.isEmpty) return const [];
    final out = <Offset>[];
    for (var i = 0; i < poly.length; i++) {
      final curr = poly[i];
      final prev = poly[(i + poly.length - 1) % poly.length];
      final currIn = inside(curr);
      final prevIn = inside(prev);
      if (currIn) {
        if (!prevIn) out.add(intersect(prev, curr));
        out.add(curr);
      } else if (prevIn) {
        out.add(intersect(prev, curr));
      }
    }
    return out;
  }

  static List<Offset> _clipRect(List<Offset> poly, double w, double h) {
    var out = poly;
    out = _clipHalfPlane(
      out,
      (p) => p.dx >= -1e-3,
      (a, b) {
        final denom = b.dx - a.dx;
        final t = denom.abs() < 1e-6 ? 0.5 : (-a.dx / denom).clamp(0.0, 1.0);
        return Offset(0, a.dy + (b.dy - a.dy) * t);
      },
    );
    out = _clipHalfPlane(
      out,
      (p) => p.dx <= w + 1e-3,
      (a, b) {
        final denom = b.dx - a.dx;
        final t = denom.abs() < 1e-6 ? 0.5 : ((w - a.dx) / denom).clamp(0.0, 1.0);
        return Offset(w, a.dy + (b.dy - a.dy) * t);
      },
    );
    out = _clipHalfPlane(
      out,
      (p) => p.dy >= -1e-3,
      (a, b) {
        final denom = b.dy - a.dy;
        final t = denom.abs() < 1e-6 ? 0.5 : (-a.dy / denom).clamp(0.0, 1.0);
        return Offset(a.dx + (b.dx - a.dx) * t, 0);
      },
    );
    out = _clipHalfPlane(
      out,
      (p) => p.dy <= h + 1e-3,
      (a, b) {
        final denom = b.dy - a.dy;
        final t = denom.abs() < 1e-6 ? 0.5 : ((h - a.dy) / denom).clamp(0.0, 1.0);
        return Offset(a.dx + (b.dx - a.dx) * t, h);
      },
    );
    return out;
  }
}

class _PageCurlClipper extends CustomClipper<Path> {
  const _PageCurlClipper({required this.geom});

  final _CurlGeometry geom;

  @override
  Path getClip(Size size) {
    if (geom.corner != _CurlCorner.middleEdge) {
      if (geom.isComplete || geom.frontPoly.length < 3) {
        return Path();
      }
      final path = Path()..moveTo(geom.frontPoly.first.dx, geom.frontPoly.first.dy);
      for (var i = 1; i < geom.frontPoly.length; i++) {
        path.lineTo(geom.frontPoly[i].dx, geom.frontPoly[i].dy);
      }
      return path..close();
    }
    return Path()
      ..moveTo(0, 0)
      ..lineTo(geom.xTop, 0)
      ..quadraticBezierTo(geom.xCtrl, geom.py, geom.xBot, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_PageCurlClipper old) =>
      old.geom.foldX != geom.foldX ||
      old.geom.pivotY != geom.pivotY ||
      old.geom.startY != geom.startY;
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

    if (geom.corner != _CurlCorner.middleEdge) {
      _paintCornerCurl(canvas, isDarkPaper);
      return;
    }

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

  void _paintCornerCurl(Canvas canvas, bool isDarkPaper) {
    if (geom.isComplete || geom.backPoly.length < 3) return;
    final c0 = geom.creaseStart;
    final c1 = geom.creaseEnd;
    final n = geom.creaseNormal;
    final midCrease = Offset((c0.dx + c1.dx) * 0.5, (c0.dy + c1.dy) * 0.5);

    // 1. Cast shadow onto the revealed underneath page along +n
    final sW = 30.0 * (0.2 + 0.8 * geom.edgeFactor);
    if (sW > 1.0) {
      final castPath = Path()
        ..moveTo(c0.dx, c0.dy)
        ..lineTo(c1.dx, c1.dy)
        ..lineTo(c1.dx + n.dx * sW, c1.dy + n.dy * sW)
        ..lineTo(c0.dx + n.dx * sW, c0.dy + n.dy * sW)
        ..close();
      final peakAlpha = (isDarkPaper ? 0.50 : 0.28) * geom.edgeFactor;
      final castPaint = Paint()
        ..shader = ui.Gradient.linear(
          midCrease,
          midCrease + n * sW,
          [
            Colors.black.withValues(alpha: peakAlpha),
            Colors.black.withValues(alpha: peakAlpha * 0.25),
            Colors.transparent,
          ],
          const [0.0, 0.45, 1.0],
        );
      canvas.drawPath(castPath, castPaint);
    }

    // 2. Rolled paper back-face polygon & soft under-flap drop shadow
    final backPath = Path()..moveTo(geom.backPoly.first.dx, geom.backPoly.first.dy);
    for (var i = 1; i < geom.backPoly.length; i++) {
      backPath.lineTo(geom.backPoly[i].dx, geom.backPoly[i].dy);
    }
    backPath.close();

    final dropPath = backPath.shift(Offset(-n.dx * 7.0, -n.dy * 7.0));
    canvas.drawPath(
      dropPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12 * geom.edgeFactor)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
    );

    final depth = math.max(12.0, geom.flapDepth);
    final cCrease = Color.lerp(
      paperColor,
      Colors.black,
      isDarkPaper ? 0.30 : 0.16,
    )!;
    final cHighlight = Color.lerp(
      paperColor,
      Colors.white,
      isDarkPaper ? 0.16 : 0.38,
    )!;
    final cOuter = Color.lerp(
      paperColor,
      isDarkPaper ? Colors.white : Colors.black,
      isDarkPaper ? 0.05 : 0.10,
    )!;

    final flapPaint = Paint()
      ..shader = ui.Gradient.linear(
        midCrease,
        midCrease - n * depth,
        [cCrease, cHighlight, paperColor, cOuter],
        const [0.0, 0.28, 0.68, 1.0],
      );
    canvas.drawPath(backPath, flapPaint);

    // Subtle hairline along the crease & outer peeled edge
    canvas.drawPath(
      backPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = (isDarkPaper ? Colors.white : Colors.black)
            .withValues(alpha: 0.10 * geom.edgeFactor),
    );
    canvas.drawLine(
      c0,
      c1,
      Paint()
        ..strokeWidth = 0.9
        ..color = (isDarkPaper ? Colors.white : Colors.black)
            .withValues(alpha: 0.16 * geom.edgeFactor),
    );
  }

  @override
  bool shouldRepaint(_PageCurlPainter old) =>
      old.geom.foldX != geom.foldX ||
      old.geom.pivotY != geom.pivotY ||
      old.geom.startY != geom.startY ||
      old.paperColor != paperColor;
}
