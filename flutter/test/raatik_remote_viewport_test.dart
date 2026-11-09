import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/remote/viewport_geometry.dart';
import 'package:flutter_hbb/raatik/toolbar/remote_toolbar_bar.dart';

const _remote = Size(1920, 1080);
const _window = Size(640, 720);

class _InputSpy {
  final List<String> log = [];
  final List<Offset> absolute = [];
  final List<Size> imageSizes = [];
  final List<Offset> relative = [];
  final List<Offset> wheels = [];
  int resolution = 0;
  int quality = 0;

  void image(Size size) {
    log.add('image');
    imageSizes.add(size);
  }

  void viewport(Size size) => log.add('viewport');

  Future<void> style() async {
    log.add('style');
    final hook = duringStyle;
    if (hook != null) {
      await hook();
    }
  }

  void refresh() => log.add('refresh');

  final List<RaatikSupersededFitDrop> drops = [];
  Size? measuredViewport;
  Size? fitCommittedFor;
  Future<void> Function()? duringStyle;

  void changeResolution() => resolution += 1;

  void changeQuality() => quality += 1;
}

class _ImageProbe extends StatefulWidget {
  const _ImageProbe({
    required this.spy,
    required this.remoteSize,
    required this.remoteOrigin,
    required this.viewStyle,
    this.customScale = 1,
    this.relativeMouse = false,
  });

  final _InputSpy spy;
  final Size remoteSize;
  final Offset remoteOrigin;
  final String viewStyle;
  final double customScale;
  final bool relativeMouse;

  @override
  State<_ImageProbe> createState() => _ImageProbeState();
}

class _MeasuredFit {
  Size? viewport;
  Size? committed;
  Size? pending;

  void store(Size size) {
    pending = size;
    if (viewport != size) {
      committed = null;
    }
    viewport = size;
  }

  void commitPending() {
    if (viewport != null && viewport == pending) {
      committed = pending;
    }
  }

  void applyDrop(RaatikSupersededFitDrop drop) {
    final next = applySupersededMeasuredFitDrop(
      viewport: viewport,
      committed: committed,
      drop: drop,
    );
    viewport = next.viewport;
    committed = next.committed;
  }
}

class _ImageProbeState extends State<_ImageProbe> {
  final _MeasuredFit _fit = _MeasuredFit();

  void _publish() {
    widget.spy.measuredViewport = _fit.viewport;
    widget.spy.fitCommittedFor = _fit.committed;
  }

  @override
  Widget build(BuildContext context) {
    return RaatikViewStyleUpdater(
      updateImageWidgetSize: widget.spy.image,
      updateViewportSize: (size) {
        widget.spy.viewport(size);
        _fit.store(size);
        _publish();
      },
      updateViewStyle: () async {
        await widget.spy.style();
        _fit.commitPending();
        _publish();
      },
      measuredViewport: () => _fit.viewport,
      fitCommittedFor: () => _fit.committed,
      dropSupersededFit: (drop) {
        widget.spy.drops.add(drop);
        _fit.applyDrop(drop);
        _publish();
      },
      refresh: widget.spy.refresh,
      onChangeResolution: widget.spy.changeResolution,
      onChangeQuality: widget.spy.changeQuality,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final geometry = geometryForViewStyle(
            style: widget.viewStyle,
            viewport: size,
            remote: widget.remoteSize,
            customScale: widget.customScale,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          );
          return SizedBox.expand(
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  widget.spy.wheels.add(event.scrollDelta);
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  if (widget.relativeMouse) {
                    widget.spy.relative.add(details.localPosition);
                    return;
                  }
                  if (geometry == null) return;
                  final point = remotePointFromViewport(
                    localPosition: details.localPosition,
                    imageOffset: geometry.offset,
                    scale: geometry.scale,
                    remoteOrigin: widget.remoteOrigin,
                    remoteSize: widget.remoteSize,
                  );
                  if (point != null) widget.spy.absolute.add(point);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (geometry != null)
                      Positioned(
                        left: geometry.offset.dx,
                        top: geometry.offset.dy,
                        width: widget.remoteSize.width * geometry.scale,
                        height: widget.remoteSize.height * geometry.scale,
                        child: const ColoredBox(
                          key: Key('raatik-fitted-image'),
                          color: Color(0xFF0284C7),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required _InputSpy spy,
  required Size window,
  double devicePixelRatio = 1,
  RaatikToolbarEdge edge = RaatikToolbarEdge.top,
  RaatikToolbarEdge? previewEdge,
  bool toolbarShown = true,
  bool fullscreen = false,
  bool relativeMouse = false,
  String viewStyle = 'adaptive',
  double customScale = 1,
  Offset remoteOrigin = Offset.zero,
  Widget toolbar = const SizedBox.expand(),
}) async {
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.view.physicalSize = Size(
    window.width * devicePixelRatio,
    window.height * devicePixelRatio,
  );
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: window, devicePixelRatio: devicePixelRatio),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: window.width,
          height: window.height,
          child: RaatikRemoteViewportLayout(
            edge: edge,
            previewEdge: previewEdge,
            toolbarShown: toolbarShown,
            fullscreen: fullscreen,
            relativeMouse: relativeMouse,
            toolbar: toolbar,
            image: _ImageProbe(
              spy: spy,
              remoteSize: _remote,
              remoteOrigin: remoteOrigin,
              viewStyle: viewStyle,
              customScale: customScale,
              relativeMouse: relativeMouse,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _expectInside(Rect outer, Rect inner) {
  expect(inner.left, greaterThanOrEqualTo(outer.left - 0.01));
  expect(inner.top, greaterThanOrEqualTo(outer.top - 0.01));
  expect(inner.right, lessThanOrEqualTo(outer.right + 0.01));
  expect(inner.bottom, lessThanOrEqualTo(outer.bottom + 0.01));
}

void _expectNear(Offset actual, Offset edge) {
  expect((actual.dx - edge.dx).abs(), lessThanOrEqualTo(1));
  expect((actual.dy - edge.dy).abs(), lessThanOrEqualTo(1));
}

void main() {
  testWidgets('640x720 reserves the toolbar and keeps image corners inside',
      (tester) async {
    final spy = _InputSpy();
    await _pump(tester, spy: spy, window: _window);

    final viewport = tester.getRect(
      find.byKey(RaatikRemoteViewportLayout.imageViewportKey),
    );
    expect(viewport.size.width, closeTo(640, 0.01));
    expect(viewport.size.height,
        closeTo(720 - RaatikRemoteToolbarBar.barHeight, 0.01));
    expect(spy.resolution, 0);
    expect(spy.quality, 0);
    expect(spy.log.take(4).toList(), ['image', 'viewport', 'style', 'refresh']);
    expect(spy.imageSizes.single, viewport.size);

    final image = tester.getRect(find.byKey(const Key('raatik-fitted-image')));
    _expectInside(viewport, image);

    const inset = 0.2;
    final taps = <Offset>[
      image.topLeft + const Offset(inset, inset),
      Offset(image.right - inset, image.top + inset),
      Offset(image.left + inset, image.bottom - inset),
      image.bottomRight - const Offset(inset, inset),
    ];
    for (final point in taps) {
      await tester.tapAt(point);
      await tester.pump();
    }
    expect(spy.absolute, hasLength(4));
    _expectNear(spy.absolute[0], Offset.zero);
    _expectNear(spy.absolute[1], const Offset(1920, 0));
    _expectNear(spy.absolute[2], const Offset(0, 1080));
    _expectNear(spy.absolute[3], const Offset(1920, 1080));

    final before = spy.absolute.length;
    await tester.tapAt(viewport.topLeft + const Offset(8, 8));
    await tester.pump();
    expect(spy.absolute, hasLength(before));
    expect(spy.resolution, 0);
    expect(spy.quality, 0);
  });

  testWidgets('hidden toolbar reserves only the collapse hitbox',
      (tester) async {
    final spy = _InputSpy();
    await _pump(tester, spy: spy, window: _window, toolbarShown: false);
    final viewport = tester.getSize(
      find.byKey(RaatikRemoteViewportLayout.imageViewportKey),
    );
    expect(viewport.width, closeTo(640, 0.01));
    expect(
      viewport.height,
      closeTo(720 - RaatikRemoteToolbarBar.collapseExtent, 0.01),
    );
    final collapse = tester.getSize(
      find.byKey(RaatikRemoteViewportLayout.collapseSlotKey),
    );
    expect(collapse.height, RaatikRemoteToolbarBar.collapseExtent);
    expect(find.byKey(RaatikRemoteViewportLayout.toolbarSlotKey), findsNothing);
  });

  testWidgets('fullscreen measures the real viewport', (tester) async {
    final spy = _InputSpy();
    await _pump(tester, spy: spy, window: _window, fullscreen: true);
    final viewport = tester.getSize(
      find.byKey(RaatikRemoteViewportLayout.imageViewportKey),
    );
    expect(viewport, _window);
  });

  testWidgets('left dock reserves width and a drag preview does not',
      (tester) async {
    final shown = _InputSpy();
    await _pump(
      tester,
      spy: shown,
      window: _window,
      edge: RaatikToolbarEdge.left,
      previewEdge: RaatikToolbarEdge.bottom,
    );
    final viewport = tester.getSize(
      find.byKey(RaatikRemoteViewportLayout.imageViewportKey),
    );
    expect(
        viewport.width, closeTo(640 - RaatikRemoteToolbarBar.barHeight, 0.01));
    expect(viewport.height, closeTo(720, 0.01));
    expect(shown.resolution, 0);
    expect(shown.quality, 0);
  });

  testWidgets('resize does not change resolution or quality', (tester) async {
    final spy = _InputSpy();
    await _pump(tester, spy: spy, window: _window);
    await _pump(tester, spy: spy, window: const Size(900, 700));
    expect(spy.resolution, 0);
    expect(spy.quality, 0);
    expect(spy.imageSizes, isNotEmpty);
    expect(spy.log, contains('image'));
    expect(spy.log.where((entry) => entry == 'image').length, 2);
  });

  testWidgets('DPR 100 to 200 percent keeps one adaptive remote point',
      (tester) async {
    final points = <Offset>[];
    for (final dpr in <double>[1, 1.25, 1.5, 2]) {
      final spy = _InputSpy();
      await _pump(
        tester,
        spy: spy,
        window: _window,
        devicePixelRatio: dpr,
      );
      final image =
          tester.getRect(find.byKey(const Key('raatik-fitted-image')));
      await tester.tapAt(image.center);
      await tester.pump();
      expect(spy.absolute, hasLength(1));
      points.add(spy.absolute.single);
      expect(spy.resolution, 0);
      expect(spy.quality, 0);
    }
    for (final point in points.skip(1)) {
      expect(point.dx, closeTo(points.first.dx, 1e-6));
      expect(point.dy, closeTo(points.first.dy, 1e-6));
    }
    expect(points.first.dx, closeTo(960, 1e-6));
    expect(points.first.dy, closeTo(540, 1e-6));
  });

  testWidgets('negative remote origin maps the image center', (tester) async {
    final spy = _InputSpy();
    await _pump(
      tester,
      spy: spy,
      window: _window,
      remoteOrigin: const Offset(-1920, 0),
    );
    final image = tester.getRect(find.byKey(const Key('raatik-fitted-image')));
    await tester.tapAt(image.center);
    await tester.pump();
    expect(spy.absolute.single.dx, closeTo(-960, 1e-6));
    expect(spy.absolute.single.dy, closeTo(540, 1e-6));
  });

  testWidgets('original and custom do not use adaptive fit', (tester) async {
    final original = _InputSpy();
    await _pump(
      tester,
      spy: original,
      window: _window,
      viewStyle: 'original',
      devicePixelRatio: 2,
    );
    final viewport = tester.getTopLeft(
      find.byKey(RaatikRemoteViewportLayout.imageViewportKey),
    );
    await tester.tapAt(viewport + const Offset(0, 66));
    await tester.pump();
    expect(original.absolute, hasLength(1));
    expect(original.absolute.single.dx, closeTo(320, 1));
    expect(original.absolute.single.dy, closeTo(0, 1));

    final custom = _InputSpy();
    await _pump(
      tester,
      spy: custom,
      window: _window,
      viewStyle: 'custom',
      customScale: 2,
    );
    final customOrigin = tester.getTopLeft(
      find.byKey(RaatikRemoteViewportLayout.imageViewportKey),
    );
    await tester.tapAt(customOrigin);
    await tester.pump();
    expect(custom.absolute.single.dx, closeTo(800, 1));
    expect(custom.absolute.single.dy, closeTo(372, 1));
  });

  testWidgets('scrolled scrollbar image maps the content point',
      (tester) async {
    const remote = Size(400, 800);
    final points = <Offset?>[];
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: SingleChildScrollView(
            controller: controller,
            child: GestureDetector(
              onTapDown: (details) {
                final metrics = controller.position;
                final total = metrics.extentBefore +
                    metrics.extentInside +
                    metrics.extentAfter;
                final scrollY = total == 0 ? 0.0 : metrics.extentBefore / total;
                points.add(
                  remotePointFromScrollbarImage(
                    localPosition: details.localPosition,
                    scale: 1,
                    remoteOrigin: Offset.zero,
                    remoteSize: remote,
                    scrollX: 0,
                    scrollY: scrollY,
                  ),
                );
              },
              child: const ColoredBox(
                color: Color(0xFF0284C7),
                child: SizedBox(width: 400, height: 800),
              ),
            ),
          ),
        ),
      ),
    );
    controller.jumpTo(120);
    await tester.pump();
    final viewportTopLeft =
        tester.getTopLeft(find.byType(SingleChildScrollView));
    await tester.tapAt(viewportTopLeft + const Offset(10, 10));
    await tester.pump();

    expect(points, hasLength(1));
    final scrollY = controller.offset / remote.height;
    _expectNear(points.single!, Offset(10, 10 + controller.offset));
    expect(
      points.single!.dy,
      isNot(closeTo(10 + controller.offset + remote.height * scrollY, 0.5)),
    );
  });

  testWidgets('scrolledge image maps the content point', (tester) async {
    const remote = Size(400, 800);
    final points = <Offset?>[];
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: SingleChildScrollView(
            controller: controller,
            child: GestureDetector(
              onTapDown: (details) {
                final metrics = controller.position;
                final total = metrics.extentBefore +
                    metrics.extentInside +
                    metrics.extentAfter;
                final scrollY = total == 0 ? 0.0 : metrics.extentBefore / total;
                points.add(
                  remotePointFromMeasuredScrollImage(
                    scrollStyle: 'scrolledge',
                    localPosition: details.localPosition,
                    scale: 1,
                    remoteOrigin: Offset.zero,
                    remoteSize: remote,
                    scrollX: 0,
                    scrollY: scrollY,
                    canvasX: 0,
                    canvasY: 0,
                    canvasSize: const Size(400, 300),
                  ),
                );
              },
              child: const ColoredBox(
                key: Key('raatik-scrolledge-image'),
                color: Color(0xFF0284C7),
                child: SizedBox(width: 400, height: 800),
              ),
            ),
          ),
        ),
      ),
    );
    controller.jumpTo(120);
    await tester.pump();
    final viewportTopLeft =
        tester.getTopLeft(find.byType(SingleChildScrollView));
    await tester.tapAt(viewportTopLeft + const Offset(10, 10));
    await tester.pump();

    expect(points, hasLength(1));
    final scrollY = controller.offset / remote.height;
    _expectNear(points.single!, Offset(10, 10 + controller.offset));
    expect(
      points.single!.dy,
      isNot(closeTo(10 + controller.offset + remote.height * scrollY, 0.5)),
    );
  });

  testWidgets('scrollbar at scroll offset zero stays on the image point',
      (tester) async {
    const remote = Size(400, 300);
    const canvas = Size(800, 600);
    final points = <Offset?>[];
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: canvas.width,
          height: canvas.height,
          child: SingleChildScrollView(
            controller: controller,
            child: SizedBox(
              width: canvas.width,
              height: canvas.height,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  (canvas.width - remote.width) / 2,
                  (canvas.height - remote.height) / 2,
                  (canvas.width - remote.width) / 2,
                  (canvas.height - remote.height) / 2,
                ),
                child: GestureDetector(
                  onTapDown: (details) {
                    points.add(
                      remotePointFromMeasuredScrollImage(
                        scrollStyle: 'scrollbar',
                        localPosition: details.localPosition,
                        scale: 1,
                        remoteOrigin: Offset.zero,
                        remoteSize: remote,
                        scrollX: 0,
                        scrollY: 0,
                        canvasX: 0,
                        canvasY: 0,
                        canvasSize: canvas,
                      ),
                    );
                  },
                  child: const ColoredBox(
                    key: Key('raatik-scrollbar-zero-image'),
                    color: Color(0xFF0284C7),
                    child: SizedBox(width: 400, height: 300),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(controller.offset, 0);
    final image =
        tester.getTopLeft(find.byKey(const Key('raatik-scrollbar-zero-image')));
    await tester.tapAt(image + const Offset(10, 10));
    await tester.pump();

    expect(points, hasLength(1));
    _expectNear(points.single!, const Offset(10, 10));
    expect(points.single!.dx,
        isNot(closeTo(10 - (canvas.width - remote.width) / 2, 0.5)));
    expect(points.single!.dy,
        isNot(closeTo(10 - (canvas.height - remote.height) / 2, 0.5)));
  });

  testWidgets('hidden toolbar slot can show the bar again', (tester) async {
    final spy = _InputSpy();
    var shown = false;
    await _pump(
      tester,
      spy: spy,
      window: _window,
      toolbarShown: false,
      toolbar: TextButton(
        key: const Key('raatik-toolbar-show'),
        style: TextButton.styleFrom(
          minimumSize: const Size(20, 20),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => shown = true,
        child: const Text('Show'),
      ),
    );
    final viewport = tester.getSize(
      find.byKey(RaatikRemoteViewportLayout.imageViewportKey),
    );
    expect(
      viewport.height,
      closeTo(720 - RaatikRemoteToolbarBar.collapseExtent, 0.01),
    );
    expect(viewport.height,
        isNot(closeTo(720 - RaatikRemoteToolbarBar.barHeight, 0.01)));
    final slot = find.byKey(RaatikRemoteViewportLayout.collapseSlotKey);
    expect(
      find.descendant(
          of: slot, matching: find.byKey(const Key('raatik-toolbar-show'))),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('raatik-toolbar-show')));
    await tester.pump();
    expect(shown, isTrue);
  });

  testWidgets('relative mode and wheel skip absolute mapping', (tester) async {
    final spy = _InputSpy();
    await _pump(tester, spy: spy, window: _window, relativeMouse: true);
    final viewport = tester.getRect(
      find.byKey(RaatikRemoteViewportLayout.imageViewportKey),
    );
    expect(viewport.size, _window);
    await tester.tapAt(viewport.center);
    await tester.pump();
    expect(spy.absolute, isEmpty);
    expect(spy.relative, isNotEmpty);

    final center = viewport.center;
    await tester.sendEventToBinding(PointerScrollEvent(
      position: center,
      scrollDelta: const Offset(0, -12),
      kind: PointerDeviceKind.mouse,
    ));
    await tester.pump();
    expect(spy.wheels, isNotEmpty);
    expect(spy.wheels.single.dy, -12);
    expect(spy.absolute, isEmpty);
    expect(spy.resolution, 0);
    expect(spy.quality, 0);
  });

  testWidgets('superseded layout drops the captured fit before refresh',
      (tester) async {
    final spy = _InputSpy();
    final hostKey = GlobalKey<_ViewportSizeHostState>();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    spy.duringStyle = () async {
      final host = tester.element(find.byKey(hostKey));
      hostKey.currentState!.resize(const Size(900, 700));
      tester.binding.buildOwner!.buildScope(host);
      tester.renderObject(find.byKey(hostKey)).owner!.flushLayout();
    };

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1200, 900), devicePixelRatio: 1),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: _ViewportSizeHost(
              key: hostKey,
              size: const Size(640, 672),
              child: _ImageProbe(
                spy: spy,
                remoteSize: _remote,
                remoteOrigin: Offset.zero,
                viewStyle: 'adaptive',
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(hostKey)), const Size(900, 700));
    expect(spy.log, ['image', 'viewport', 'style']);
    expect(spy.imageSizes, [const Size(640, 672)]);
    expect(spy.drops, [RaatikSupersededFitDrop.clearViewportAndCommit]);
    expect(spy.measuredViewport, isNull);
    expect(spy.fitCommittedFor, isNull);
    expect(spy.resolution, 0);
    expect(spy.quality, 0);

    spy.duringStyle = null;
    await tester.pump();

    expect(spy.log, [
      'image',
      'viewport',
      'style',
      'image',
      'viewport',
      'style',
      'refresh',
    ]);
    expect(spy.imageSizes, [const Size(640, 672), const Size(900, 700)]);
    expect(spy.drops, [RaatikSupersededFitDrop.clearViewportAndCommit]);
    expect(spy.measuredViewport, const Size(900, 700));
    expect(spy.fitCommittedFor, const Size(900, 700));
    expect(spy.resolution, 0);
    expect(spy.quality, 0);
  });
}

class _ViewportSizeHost extends StatefulWidget {
  const _ViewportSizeHost({
    super.key,
    required this.size,
    required this.child,
  });

  final Size size;
  final Widget child;

  @override
  State<_ViewportSizeHost> createState() => _ViewportSizeHostState();
}

class _ViewportSizeHostState extends State<_ViewportSizeHost> {
  late Size _size = widget.size;

  void resize(Size size) => setState(() => _size = size);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size.width,
      height: _size.height,
      child: widget.child,
    );
  }
}
