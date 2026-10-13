import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:wenku8x/utils/flash.dart';

/// 一张纸沿折线翻过去：翻起多宽，纸背就只显示那一截，左右对调。
/// 下一页从右往左，纸背是本页；上一页从左往右，纸背是上一页。
class SimulationReader extends StatefulWidget {
  const SimulationReader({
    super.key,
    required this.pages,
    required this.controller,
    required this.menuOpen,
    required this.onCommit,
    required this.onMenu,
    required this.onDismissMenu,
    this.turnToken = 0,
    this.turnToNext = true,
  });

  final List<Widget> pages;
  final PageController controller;
  final bool menuOpen;
  final void Function(int delta) onCommit;
  final VoidCallback onMenu;
  final VoidCallback onDismissMenu;

  /// 音量键翻页。token 变化时按 [turnToNext] 播一次仿真翻页。
  final int turnToken;
  final bool turnToNext;

  @override
  State<SimulationReader> createState() => _SimulationReaderState();
}

class _SimulationReaderState extends State<SimulationReader>
    with SingleTickerProviderStateMixin {
  final _currentKey = GlobalKey();
  final _nextKey = GlobalKey();
  final _prevKey = GlobalKey();

  late final AnimationController _anim;
  double _fromT = 0;
  double _toT = 0;
  double _t = 0;
  Offset _down = Offset.zero;
  bool _toNext = true;
  bool _showCurl = false;
  bool _dragging = false;
  bool _blocked = false;
  int _animGen = 0;
  int _shotGen = 0;
  int _shotIndex = -1;
  ui.Image? _currentImg;
  ui.Image? _nextImg;
  ui.Image? _prevImg;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addListener(() {
        if (!mounted) return;
        final u = Curves.easeInOut.transform(_anim.value);
        setState(() => _t = _fromT + (_toT - _fromT) * u);
      });
    widget.controller.addListener(_onController);
  }

  @override
  void didUpdateWidget(covariant SimulationReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
    }
    if (widget.menuOpen && !oldWidget.menuOpen) {
      _animGen++;
      _anim.stop();
      setState(() {
        _showCurl = false;
        _dragging = false;
        _t = 0;
      });
    }
    if (widget.turnToken != oldWidget.turnToken) {
      final token = widget.turnToken;
      final toNext = widget.turnToNext;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.turnToken != token) return;
        _play(toNext);
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _anim.dispose();
    _shotGen++;
    _disposeShots();
    super.dispose();
  }

  void _onController() {
    if (!mounted || _showCurl) return;
    setState(() {});
  }

  int _index() {
    final count = widget.pages.length;
    if (count == 0 || !widget.controller.hasClients) return 0;
    final page = widget.controller.page?.round() ?? 0;
    return page.clamp(0, count - 1);
  }

  void _disposeShots() {
    _currentImg?.dispose();
    _nextImg?.dispose();
    _prevImg?.dispose();
    _currentImg = null;
    _nextImg = null;
    _prevImg = null;
    _shotIndex = -1;
  }

  Future<void> _prepareShots() async {
    final gen = ++_shotGen;
    final index = _index();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || gen != _shotGen) return;
    final current = await _capture(_currentKey);
    if (!mounted || gen != _shotGen) {
      current?.dispose();
      return;
    }
    final next =
        index + 1 < widget.pages.length ? await _capture(_nextKey) : null;
    final prev = index > 0 ? await _capture(_prevKey) : null;
    if (!mounted || gen != _shotGen) {
      current?.dispose();
      next?.dispose();
      prev?.dispose();
      return;
    }
    _disposeShots();
    setState(() {
      _currentImg = current;
      _nextImg = next;
      _prevImg = prev;
      _shotIndex = index;
    });
  }

  Future<ui.Image?> _capture(GlobalKey key) async {
    final render = key.currentContext?.findRenderObject();
    if (render is! RenderRepaintBoundary) return null;
    try {
      if (render.debugNeedsPaint) {
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!mounted) return null;
      final dpr = MediaQuery.devicePixelRatioOf(context);
      return await render.toImage(pixelRatio: dpr);
    } catch (_) {
      return null;
    }
  }

  bool get _canPaint {
    if (_shotIndex != _index()) return false;
    if (_toNext) return _currentImg != null && _nextImg != null;
    return _currentImg != null && _prevImg != null;
  }

  void _animateT(double target, VoidCallback onDone) {
    final gen = ++_animGen;
    _fromT = _t;
    _toT = target;
    _anim
      ..stop()
      ..value = 0
      ..forward().whenComplete(() {
        if (!mounted || gen != _animGen) return;
        onDone();
      });
  }

  void _commit() {
    final delta = _toNext ? 1 : -1;
    _shotGen++;
    _showCurl = false;
    _dragging = false;
    _blocked = false;
    _t = 0;
    _disposeShots();
    widget.onCommit(delta);
    if (mounted) setState(() {});
  }

  void _snapBack() {
    _animateT(0, () {
      if (!mounted) return;
      setState(() {
        _showCurl = false;
        _dragging = false;
        _blocked = false;
        _t = 0;
      });
    });
  }

  void _play(bool toNext) {
    if (_anim.isAnimating || _dragging) return;
    final index = _index();
    if (toNext && index >= widget.pages.length - 1) {
      Show.error("已经是最后一页了~");
      return;
    }
    if (!toNext && index <= 0) return;
    setState(() {
      _toNext = toNext;
      _blocked = false;
      _t = 0;
      _showCurl = true;
      _dragging = false;
    });
    _prepareShots();
    _animateT(1, _commit);
  }

  void _onDown(PointerDownEvent event) {
    if (widget.menuOpen || widget.pages.isEmpty || _anim.isAnimating) return;
    _down = event.localPosition;
    _dragging = false;
    _blocked = false;
    _prepareShots();
  }

  void _onMove(PointerMoveEvent event) {
    if (widget.menuOpen || _anim.isAnimating) return;
    final size = context.size;
    if (size == null || size.width < 1) return;
    final local = event.localPosition;
    final dx = local.dx - _down.dx;
    final dy = local.dy - _down.dy;
    if (!_dragging) {
      if (dx.abs() < 8 && dy.abs() < 8) return;
      if (dx.abs() < dy.abs() * 0.65) return;
      final toNext = dx < 0;
      final index = _index();
      _toNext = toNext;
      _blocked = toNext ? index >= widget.pages.length - 1 : index <= 0;
      _showCurl = true;
      _dragging = true;
    }
    final drag = _toNext ? _down.dx - local.dx : local.dx - _down.dx;
    var t = (drag / size.width).clamp(0.0, 1.0).toDouble();
    if (_blocked) t = math.min(t, 0.12);
    setState(() => _t = t);
  }

  void _onUp(PointerUpEvent event) {
    if (widget.menuOpen) {
      widget.onDismissMenu();
      return;
    }
    final local = event.localPosition;
    final dx = local.dx - _down.dx;
    final dy = local.dy - _down.dy;
    if (!_dragging) {
      if (dx.abs() < 8 && dy.abs() < 8) _handleTap(local);
      return;
    }
    if (_blocked) {
      if (_toNext && _index() >= widget.pages.length - 1) {
        Show.error("已经是最后一页了~");
      }
      _snapBack();
      return;
    }
    if (_t > 0.28) {
      _animateT(1, _commit);
    } else {
      _snapBack();
    }
  }

  void _handleTap(Offset pos) {
    final size = context.size;
    if (size == null) return;
    final inCenter = pos.dy > size.height / 3 &&
        pos.dy < size.height / 3 * 2 &&
        pos.dx > size.width / 3 &&
        pos.dx < size.width / 3 * 2;
    if (inCenter) {
      widget.onMenu();
      return;
    }
    if (pos.dx > size.width / 3 * 2) {
      _play(true);
    } else if (pos.dx < size.width / 3) {
      _play(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paper = Theme.of(context).colorScheme.surface;
    final index = _index();
    final painting = _showCurl && _canPaint;
    final sheet = _toNext ? _currentImg : _prevImg;
    final base = _toNext ? _nextImg : _currentImg;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (index > 0) _live(index - 1, _prevKey, paper),
          if (index + 1 < widget.pages.length)
            _live(index + 1, _nextKey, paper),
          if (widget.pages.isNotEmpty) _live(index, _currentKey, paper),
          if (painting && sheet != null && base != null)
            CustomPaint(
              painter: _SheetPainter(
                t: _t,
                toNext: _toNext,
                sheet: sheet,
                base: base,
              ),
              child: const SizedBox.expand(),
            ),
        ],
      ),
    );
  }

  Widget _live(int index, GlobalKey key, Color paper) {
    return RepaintBoundary(
      key: key,
      child: ColoredBox(
        color: paper,
        child: widget.pages[index],
      ),
    );
  }
}

class _SheetPainter extends CustomPainter {
  _SheetPainter({
    required this.t,
    required this.toNext,
    required this.sheet,
    required this.base,
  });

  final double t;
  final bool toNext;
  final ui.Image sheet;
  final ui.Image base;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 1 || size.height < 1) return;
    // turned 是已经翻过去的宽度。折线在 fold，纸背贴在折线内侧，宽度和 turned 相同。
    // 下一页：折线从右缘往左，纸背是折线右侧那一截（最右边）左右对调后盖住左侧。
    // 翻到一半时折线在正中，左半边被本页右半边盖住，纸背只含右半边。
    final turned = t.clamp(0.0, 1.0) * size.width;
    final fold = toNext ? size.width - turned : turned;
    final flapLeft = 2 * fold - size.width;

    _drawFull(canvas, base, size);
    if (flapLeft > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(
          0, 0, math.min(flapLeft, size.width), size.height));
      _drawFull(canvas, sheet, size);
      canvas.restore();
    }
    if (fold > 0 && fold < size.width) {
      final shadow = Rect.fromLTWH(fold, 0, 32, size.height);
      canvas.drawRect(
        shadow,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(fold, 0),
            Offset(fold + 32, 0),
            const [Color(0x38000000), Color(0x00000000)],
          ),
      );
    }
    _drawFlap(canvas, size, sheet, fold, flapLeft);
  }

  void _drawFlap(
    Canvas canvas,
    Size size,
    ui.Image image,
    double fold,
    double flapLeft,
  ) {
    final flapWidth = fold - flapLeft;
    if (flapWidth < 1 || fold <= 0) return;
    final bow = math.min(14.0, flapWidth * 0.06);
    final path = Path()
      ..moveTo(fold, 0)
      ..quadraticBezierTo(fold - bow, size.height * 0.5, fold, size.height)
      ..lineTo(flapLeft, size.height)
      ..lineTo(flapLeft, 0)
      ..close();

    final imgW = image.width.toDouble();
    final srcL = fold / size.width * imgW;
    final srcW = imgW - srcL;
    if (srcW < 1) return;

    canvas.save();
    canvas.clipPath(path);
    // 折线处的字留在折线上，纸的外缘对调到翻起部分的另一边。
    canvas.translate(fold, 0);
    canvas.scale(-1, 1);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(srcL, 0, srcW, image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width - fold, size.height),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(flapLeft, 0, flapWidth, size.height),
      Paint()..color = const Color(0x14000000),
    );
    final bendWidth = math.min(28.0, flapWidth * 0.22);
    if (bendWidth > 1) {
      final bendLeft = fold - bendWidth;
      canvas.drawRect(
        Rect.fromLTWH(bendLeft, 0, bendWidth, size.height),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(fold, 0),
            Offset(bendLeft, 0),
            const [Color(0x4C000000), Color(0x00000000)],
          ),
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(fold, 0)
        ..quadraticBezierTo(fold - bow, size.height * 0.5, fold, size.height),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x33FFFFFF),
    );
    canvas.restore();

    if (flapLeft > 0 && flapLeft < size.width) {
      final edge = Rect.fromLTWH(flapLeft - 16, 0, 16, size.height);
      canvas.drawRect(
        edge,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(flapLeft, 0),
            Offset(flapLeft - 16, 0),
            const [Color(0x28000000), Color(0x00000000)],
          ),
      );
    }
  }

  void _drawFull(Canvas canvas, ui.Image image, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant _SheetPainter oldDelegate) => true;
}
