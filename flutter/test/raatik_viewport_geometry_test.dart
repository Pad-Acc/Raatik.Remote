import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/remote/viewport_geometry.dart';

void _expectRemote(Offset? actual, Offset expected) {
  expect(actual, isNotNull);
  expect(actual!.dx, closeTo(expected.dx, 1e-6));
  expect(actual.dy, closeTo(expected.dy, 1e-6));
}

void main() {
  test('adaptive fit matches the 1000x600 example', () {
    final g = fitRemoteViewport(const Size(1000, 600), const Size(1920, 1080))!;
    expect(g.scale, closeTo(1000 / 1920, 1e-9));
    expect(g.offset.dx, 0);
    expect(g.offset.dy, closeTo(18.75, 1e-9));
    expect(fitRemoteViewport(Size.zero, const Size(1920, 1080)), isNull);
  });

  test('fit table and pointer samples', () {
    final wide = fitRemoteViewport(const Size(1000, 600), const Size(1920, 1080))!;
    _expectRemote(
      remotePointFromViewport(
        localPosition: const Offset(500, 300),
        imageOffset: wide.offset,
        scale: wide.scale,
        remoteOrigin: Offset.zero,
        remoteSize: const Size(1920, 1080),
      ),
      const Offset(960, 540),
    );

    final tall = fitRemoteViewport(const Size(600, 1000), const Size(1920, 1080))!;
    expect(tall.scale, closeTo(0.3125, 1e-9));
    expect(tall.offset.dx, 0);
    expect(tall.offset.dy, closeTo(331.25, 1e-9));
    _expectRemote(
      remotePointFromViewport(
        localPosition: const Offset(300, 500),
        imageOffset: tall.offset,
        scale: tall.scale,
        remoteOrigin: Offset.zero,
        remoteSize: const Size(1920, 1080),
      ),
      const Offset(960, 540),
    );

    final same = fitRemoteViewport(const Size(1280, 720), const Size(1280, 720))!;
    expect(same.scale, 1);
    expect(same.offset, Offset.zero);
    _expectRemote(
      remotePointFromViewport(
        localPosition: const Offset(640, 360),
        imageOffset: same.offset,
        scale: same.scale,
        remoteOrigin: Offset.zero,
        remoteSize: const Size(1280, 720),
      ),
      const Offset(640, 360),
    );

    _expectRemote(
      remotePointFromViewport(
        localPosition: const Offset(500, 300),
        imageOffset: wide.offset,
        scale: wide.scale,
        remoteOrigin: const Offset(-1920, 0),
        remoteSize: const Size(1920, 1080),
      ),
      const Offset(-960, 540),
    );
  });

  test('adaptive scale may be greater than 1', () {
    final g = fitRemoteViewport(const Size(200, 100), const Size(50, 40))!;
    expect(g.scale, closeTo(2.5, 1e-9));
    expect(g.offset.dx, closeTo(37.5, 1e-9));
    expect(g.offset.dy, 0);
    _expectRemote(
      remotePointFromViewport(
        localPosition: const Offset(50, 50),
        imageOffset: g.offset,
        scale: g.scale,
        remoteOrigin: Offset.zero,
        remoteSize: const Size(50, 40),
      ),
      const Offset(5, 20),
    );
  });

  test('nonfinite or nonpositive dimensions are rejected', () {
    expect(fitRemoteViewport(const Size(double.nan, 10), const Size(10, 10)), isNull);
    expect(
      fitRemoteViewport(const Size(double.infinity, 10), const Size(10, 10)),
      isNull,
    );
    expect(fitRemoteViewport(const Size(-5, 10), const Size(10, 10)), isNull);
    expect(fitRemoteViewport(const Size(10, 10), Size.zero), isNull);
    expect(isUsableViewportSize(Size.zero), isFalse);
    expect(isUsableViewportSize(const Size(double.nan, 10)), isFalse);
    expect(isUsableViewportSize(const Size(double.infinity, 8)), isFalse);
    expect(isUsableViewportSize(const Size(8, 8)), isTrue);
  });

  test('letterbox clicks are outside the image', () {
    final g = fitRemoteViewport(const Size(1000, 600), const Size(1920, 1080))!;
    expect(
      remotePointFromViewport(
        localPosition: const Offset(10, 1),
        imageOffset: g.offset,
        scale: g.scale,
        remoteOrigin: Offset.zero,
        remoteSize: const Size(1920, 1080),
      ),
      isNull,
    );
  });

  test('DPR is not part of adaptive fit', () {
    final a = geometryForViewStyle(
      style: 'adaptive',
      viewport: const Size(1000, 600),
      remote: const Size(1920, 1080),
      devicePixelRatio: 1,
    )!;
    final b = geometryForViewStyle(
      style: 'adaptive',
      viewport: const Size(1000, 600),
      remote: const Size(1920, 1080),
      devicePixelRatio: 2,
    )!;
    expect(a.scale, b.scale);
    expect(a.offset, b.offset);
  });

  test('original and custom keep their scale rules', () {
    final original = geometryForViewStyle(
      style: 'original',
      viewport: const Size(640, 672),
      remote: const Size(1920, 1080),
      devicePixelRatio: 1,
    )!;
    expect(original.scale, 1);
    expect(original.offset.dx, closeTo(-640, 1e-9));
    expect(original.offset.dy, closeTo(-204, 1e-9));

    final originalHiDpi = geometryForViewStyle(
      style: 'original',
      viewport: const Size(640, 672),
      remote: const Size(1920, 1080),
      devicePixelRatio: 2,
    )!;
    expect(originalHiDpi.scale, closeTo(0.5, 1e-9));
    expect(originalHiDpi.offset.dx, closeTo(-160, 1e-9));
    expect(originalHiDpi.offset.dy, closeTo(66, 1e-9));

    final custom = geometryForViewStyle(
      style: 'custom',
      viewport: const Size(640, 672),
      remote: const Size(1920, 1080),
      customScale: 2,
      devicePixelRatio: 1,
    )!;
    expect(custom.scale, closeTo(2, 1e-9));
    expect(custom.offset.dx, closeTo(-1600, 1e-9));
    expect(custom.offset.dy, closeTo(-744, 1e-9));
    _expectRemote(
      remotePointFromViewport(
        localPosition: Offset.zero,
        imageOffset: custom.offset,
        scale: custom.scale,
        remoteOrigin: Offset.zero,
        remoteSize: const Size(1920, 1080),
      ),
      const Offset(800, 372),
    );
  });

  test('scrollbar image scroll is not applied a second time', () {
    const remote = Size(400, 800);
    const local = Offset(10, 130);
    const scrollY = 120 / 800;
    final point = remotePointFromScrollbarImage(
      localPosition: local,
      scale: 1,
      remoteOrigin: Offset.zero,
      remoteSize: remote,
      scrollX: 0,
      scrollY: scrollY,
    );
    _expectRemote(point, local);
    expect(point!.dy, isNot(closeTo(local.dy + remote.height * scrollY, 1e-6)));
    expect(
      remotePointFromScrollbarImage(
        localPosition: const Offset(-1, 10),
        scale: 1,
        remoteOrigin: Offset.zero,
        remoteSize: remote,
        scrollX: 0.25,
        scrollY: scrollY,
      ),
      isNull,
    );
    expect(
      remotePointFromScrollbarImage(
        localPosition: const Offset(10, 801),
        scale: 1,
        remoteOrigin: Offset.zero,
        remoteSize: remote,
        scrollX: 0,
        scrollY: scrollY,
      ),
      isNull,
    );
  });

  test('fitted original and custom use the viewport listener', () {
    const remote = Size(400, 300);
    const origin = Offset(1920, 0);
    const originalOffset = Offset(200, 150);
    final original = mapMeasuredAbsolutePointer(
      imageOverflow: false,
      scrollStyle: 'scrollbar',
      localPosition: originalOffset,
      scale: 1,
      remoteOrigin: origin,
      remoteSize: remote,
      canvasX: originalOffset.dx,
      canvasY: originalOffset.dy,
    );
    _expectRemote(original.remote, origin);
    expect(original.viewportPosition, originalOffset);
    expect(
      mapMeasuredAbsolutePointer(
        imageOverflow: false,
        scrollStyle: 'scrolledge',
        localPosition: Offset.zero,
        scale: 1,
        remoteOrigin: origin,
        remoteSize: remote,
        canvasX: originalOffset.dx,
        canvasY: originalOffset.dy,
      ).remote,
      isNull,
    );

    const customOffset = Offset(300, 225);
    final custom = mapMeasuredAbsolutePointer(
      imageOverflow: false,
      scrollStyle: 'scrollbar',
      localPosition: customOffset,
      scale: 0.5,
      remoteOrigin: origin,
      remoteSize: remote,
      canvasX: customOffset.dx,
      canvasY: customOffset.dy,
    );
    _expectRemote(custom.remote, origin);
    expect(custom.viewportPosition, customOffset);
    expect(
      mapMeasuredAbsolutePointer(
        imageOverflow: false,
        scrollStyle: 'scrolledge',
        localPosition: const Offset(10, 10),
        scale: 0.5,
        remoteOrigin: origin,
        remoteSize: remote,
        canvasX: customOffset.dx,
        canvasY: customOffset.dy,
      ).remote,
      isNull,
    );
  });

  test('overflow image listener pans from the scroll position', () {
    const origin = Offset(1920, 0);
    const wideLocal = Offset(150, 20);
    const wideViewport = Size(400, 300);
    const wideImage = Size(800, 300);
    final bar = mapMeasuredAbsolutePointer(
      imageOverflow: true,
      scrollStyle: 'scrollbar',
      localPosition: wideLocal,
      scale: 1,
      remoteOrigin: origin,
      remoteSize: wideImage,
      canvasX: (wideViewport.width - wideImage.width) / 2,
      canvasY: (wideViewport.height - wideImage.height) / 2,
      viewportSize: wideViewport,
      scrollX: 0.125,
      scrollY: 0,
    );
    _expectRemote(bar.remote, origin + wideLocal);
    expect(bar.viewportPosition, const Offset(50, 20));
    expect(bar.viewportPosition.dx, inInclusiveRange(0, wideViewport.width));
    expect(bar.viewportPosition.dy, inInclusiveRange(0, wideViewport.height));

    const tallLocal = Offset(10, 150);
    const tallViewport = Size(800, 400);
    const tallImage = Size(400, 800);
    final edge = mapMeasuredAbsolutePointer(
      imageOverflow: true,
      scrollStyle: 'scrolledge',
      localPosition: tallLocal,
      scale: 1,
      remoteOrigin: origin,
      remoteSize: tallImage,
      canvasX: (tallViewport.width - tallImage.width) / 2,
      canvasY: (tallViewport.height - tallImage.height) / 2,
      viewportSize: tallViewport,
      scrollX: 0,
      scrollY: 0.125,
    );
    _expectRemote(edge.remote, origin + tallLocal);
    expect(edge.viewportPosition, const Offset(210, 50));
    expect(edge.viewportPosition.dx, inInclusiveRange(0, tallViewport.width));
    expect(edge.viewportPosition.dy, inInclusiveRange(0, tallViewport.height));
    expect(
      mapMeasuredAbsolutePointer(
        imageOverflow: true,
        scrollStyle: 'scrolledge',
        localPosition: const Offset(10, 801),
        scale: 1,
        remoteOrigin: Offset.zero,
        remoteSize: tallImage,
        canvasX: 0,
        canvasY: -200,
        viewportSize: tallViewport,
        scrollX: 0,
        scrollY: 0,
      ).remote,
      isNull,
    );
  });

  test('scroll-auto measured samples stay on the viewport contract', () {
    final wide =
        fitRemoteViewport(const Size(1000, 600), const Size(1920, 1080))!;
    const local = Offset(500, 300);
    final center = mapMeasuredAbsolutePointer(
      imageOverflow: false,
      scrollStyle: 'scrollauto',
      localPosition: local,
      scale: wide.scale,
      remoteOrigin: Offset.zero,
      remoteSize: const Size(1920, 1080),
      canvasX: wide.offset.dx,
      canvasY: wide.offset.dy,
    );
    _expectRemote(center.remote, const Offset(960, 540));
    expect(center.viewportPosition, local);

    final origin = mapMeasuredAbsolutePointer(
      imageOverflow: false,
      scrollStyle: 'scrollauto',
      localPosition: local,
      scale: wide.scale,
      remoteOrigin: const Offset(-1920, 0),
      remoteSize: const Size(1920, 1080),
      canvasX: wide.offset.dx,
      canvasY: wide.offset.dy,
    );
    _expectRemote(origin.remote, const Offset(-960, 540));
    expect(origin.viewportPosition, local);

    final overflowAuto = mapMeasuredAbsolutePointer(
      imageOverflow: true,
      scrollStyle: 'scrollauto',
      localPosition: Offset.zero,
      scale: 1,
      remoteOrigin: Offset.zero,
      remoteSize: const Size(1920, 1080),
      canvasX: -640,
      canvasY: -204,
    );
    _expectRemote(overflowAuto.remote, const Offset(640, 204));
    expect(overflowAuto.viewportPosition, Offset.zero);
  });

  test('scrollbar at canvas offset zero stays image-local', () {
    const remote = Size(400, 300);
    const local = Offset(10, 10);
    const canvas = Size(800, 600);
    const origin = Offset(1920, 0);
    final point = remotePointFromMeasuredScrollImage(
      scrollStyle: 'scrollbar',
      localPosition: local,
      scale: 1,
      remoteOrigin: origin,
      remoteSize: remote,
      scrollX: 0,
      scrollY: 0,
      canvasX: 0,
      canvasY: 0,
      canvasSize: canvas,
    );
    _expectRemote(point, origin + local);
    expect(point!.dx, isNot(closeTo(origin.dx + local.dx - 200, 1e-6)));
    expect(point.dy, isNot(closeTo(origin.dy + local.dy - 150, 1e-6)));
    expect(
      remotePointFromMeasuredScrollImage(
        scrollStyle: 'scrollbar',
        localPosition: const Offset(-1, 10),
        scale: 1,
        remoteOrigin: origin,
        remoteSize: remote,
        canvasX: 0,
        canvasY: 0,
        canvasSize: canvas,
      ),
      isNull,
    );
  });

  test('measured move retargets another window without toolbar inset', () {
    const others = [
      MeasuredWindowSpan(
        relativeOffset: Offset(800, 0),
        size: Size(800, 600),
      ),
    ];
    final hit = retargetMeasuredPointer(
      isMove: true,
      x: 900,
      y: 40,
      currentWindow: const Size(800, 600),
      others: others,
      devicePixelRatio: 1,
      windowsPhysicalOffsets: false,
    );
    expect(hit, isNotNull);
    expect(hit!.index, 0);
    expect(hit.x, closeTo(100, 1e-9));
    expect(hit.y, closeTo(40, 1e-9));

    expect(
      retargetMeasuredPointer(
        isMove: true,
        x: 100,
        y: 40,
        currentWindow: const Size(800, 600),
        others: others,
        devicePixelRatio: 1,
        windowsPhysicalOffsets: false,
      ),
      isNull,
    );
    expect(
      retargetMeasuredPointer(
        isMove: false,
        x: 900,
        y: 40,
        currentWindow: const Size(800, 600),
        others: others,
        devicePixelRatio: 1,
        windowsPhysicalOffsets: false,
      ),
      isNull,
    );

    final windows = retargetMeasuredPointer(
      isMove: true,
      x: 900,
      y: 40,
      currentWindow: const Size(800, 600),
      others: const [
        MeasuredWindowSpan(
          relativeOffset: Offset(1600, 0),
          size: Size(1600, 1200),
        ),
      ],
      devicePixelRatio: 2,
      windowsPhysicalOffsets: true,
    );
    expect(windows, isNotNull);
    expect(windows!.x, closeTo(100, 1e-9));
    expect(windows.y, closeTo(40, 1e-9));
  });

  test('measured input retargets from the window position', () {
    const others = [
      MeasuredWindowSpan(
        relativeOffset: Offset(800, 0),
        size: Size(800, 600),
      ),
    ];
    const window = Size(800, 600);
    const measuredLocal = Offset(12, 34);

    MeasuredPointerDecision decide({
      required bool viewportLocal,
      required double windowX,
      required double windowY,
      bool hasWindowPosition = true,
      bool isMove = true,
    }) {
      return decideMeasuredPointer(
        viewportLocal: viewportLocal,
        isMove: isMove,
        hasWindowPosition: hasWindowPosition,
        windowX: windowX,
        windowY: windowY,
        measuredLocal: measuredLocal,
        currentWindow: window,
        others: others,
        devicePixelRatio: 1,
        windowsPhysicalOffsets: false,
      );
    }

    final outside = decide(viewportLocal: true, windowX: 900, windowY: 40);
    expect(outside.retarget, isNotNull);
    expect(outside.retarget!.index, 0);
    expect(outside.useMeasuredLocal, isFalse);
    expect(outside.x, closeTo(100, 1e-9));
    expect(outside.y, closeTo(40, 1e-9));
    expect(outside.x, isNot(measuredLocal.dx));
    expect(outside.y, isNot(measuredLocal.dy));

    final inside = decide(viewportLocal: true, windowX: 100, windowY: 40);
    expect(inside.retarget, isNull);
    expect(inside.useMeasuredLocal, isTrue);
    expect(inside.x, measuredLocal.dx);
    expect(inside.y, measuredLocal.dy);

    final unmeasured = decide(viewportLocal: false, windowX: 100, windowY: 40);
    expect(unmeasured.retarget, isNull);
    expect(unmeasured.useMeasuredLocal, isFalse);
    expect(unmeasured.x, 100);
    expect(unmeasured.y, 40);
    expect(unmeasured.x, isNot(measuredLocal.dx));

    final refresh = decide(
      viewportLocal: true,
      windowX: 900,
      windowY: 40,
      hasWindowPosition: false,
    );
    expect(refresh.retarget, isNull);
    expect(refresh.useMeasuredLocal, isTrue);
    expect(refresh.x, measuredLocal.dx);
    expect(refresh.y, measuredLocal.dy);
  });

  test('measurement apply order ignores unusable sizes', () async {
    final log = <String>[];
    Future<void> apply(Size size) {
      return applyMeasuredViewportSize(
        size: size,
        updateImageWidgetSize: (_) => log.add('image'),
        updateViewportSize: (_) => log.add('viewport'),
        updateViewStyle: () async => log.add('style'),
        refresh: () => log.add('refresh'),
      );
    }

    await apply(Size.zero);
    await apply(const Size(double.nan, 10));
    await apply(const Size(double.infinity, 10));
    expect(log, isEmpty);

    await apply(const Size(640, 672));
    expect(log, ['image', 'viewport', 'style', 'refresh']);
  });
}
