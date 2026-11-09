import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/remote/viewport_geometry.dart';
import 'package:flutter_hbb/raatik/toolbar/remote_toolbar_bar.dart';

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
    final wide =
        fitRemoteViewport(const Size(1000, 600), const Size(1920, 1080))!;
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

    final tall =
        fitRemoteViewport(const Size(600, 1000), const Size(1920, 1080))!;
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

    final same =
        fitRemoteViewport(const Size(1280, 720), const Size(1280, 720))!;
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
    expect(fitRemoteViewport(const Size(double.nan, 10), const Size(10, 10)),
        isNull);
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

  test('cross-window move maps through the destination image origin', () {
    const scale = 1000 / 1920;
    const offset = Offset(0, 18.75);
    const remote = Size(1920, 1080);
    const imageOrigin = Offset(0, 48);
    const windowPoint = Offset(500, 348);
    final mapped = mapRetargetedWindowPoint(
      windowPoint: windowPoint,
      imageOrigin: imageOrigin,
      imageOverflow: false,
      scrollStyle: 'scrollauto',
      scale: scale,
      remoteOrigin: Offset.zero,
      remoteSize: remote,
      canvasX: offset.dx,
      canvasY: offset.dy,
    );
    _expectRemote(mapped.remote, const Offset(960, 540));

    final ignoredInset = mapMeasuredAbsolutePointer(
      imageOverflow: false,
      scrollStyle: 'scrollauto',
      localPosition: windowPoint,
      scale: scale,
      remoteOrigin: Offset.zero,
      remoteSize: remote,
      canvasX: offset.dx,
      canvasY: offset.dy,
    );
    expect(ignoredInset.remote, isNotNull);
    expect(ignoredInset.remote!.dy, isNot(closeTo(540, 1)));

    final onToolbar = mapRetargetedWindowPoint(
      windowPoint: const Offset(500, 24),
      imageOrigin: imageOrigin,
      imageOverflow: false,
      scrollStyle: 'scrollauto',
      scale: scale,
      remoteOrigin: Offset.zero,
      remoteSize: remote,
      canvasX: offset.dx,
      canvasY: offset.dy,
    );
    expect(onToolbar.remote, isNull);
  });

  test('overflow handoff maps the viewport point back to image content', () {
    const imageOrigin = Offset(0, 48);
    const windowPoint = Offset(210, 98);
    const viewportPoint = Offset(210, 50);
    const viewport = Size(800, 400);
    const remote = Size(400, 800);
    const canvasInset = Offset(200, -200);
    final mapped = mapRetargetedWindowPoint(
      windowPoint: windowPoint,
      imageOrigin: imageOrigin,
      imageOverflow: true,
      scrollStyle: 'scrolledge',
      scale: 1,
      remoteOrigin: Offset.zero,
      remoteSize: remote,
      canvasX: canvasInset.dx,
      canvasY: canvasInset.dy,
      viewportSize: viewport,
      scrollX: 0,
      scrollY: 0.125,
    );
    _expectRemote(mapped.remote, const Offset(10, 150));
    expect(mapped.viewportPosition, viewportPoint);
    expect(windowPoint - imageOrigin, viewportPoint);

    final treatedAsContent = mapMeasuredAbsolutePointer(
      imageOverflow: true,
      scrollStyle: 'scrolledge',
      localPosition: viewportPoint,
      scale: 1,
      remoteOrigin: Offset.zero,
      remoteSize: remote,
      canvasX: canvasInset.dx,
      canvasY: canvasInset.dy,
      viewportSize: viewport,
      scrollX: 0,
      scrollY: 0.125,
    );
    _expectRemote(treatedAsContent.remote, viewportPoint);
    expect(treatedAsContent.remote!.dx, isNot(closeTo(10, 1e-6)));
    expect(treatedAsContent.remote!.dy, isNot(closeTo(150, 1e-6)));

    final scrollAuto = mapRetargetedWindowPoint(
      windowPoint: windowPoint,
      imageOrigin: imageOrigin,
      imageOverflow: true,
      scrollStyle: 'scrollauto',
      scale: 1,
      remoteOrigin: Offset.zero,
      remoteSize: remote,
      canvasX: canvasInset.dx,
      canvasY: canvasInset.dy,
      viewportSize: viewport,
      scrollX: 0,
      scrollY: 0.125,
    );
    _expectRemote(scrollAuto.remote, viewportPoint - canvasInset);
    expect(scrollAuto.remote!.dy, isNot(closeTo(150, 1)));

    final toolbarBand = mapRetargetedWindowPoint(
      windowPoint: const Offset(210, 10),
      imageOrigin: imageOrigin,
      imageOverflow: true,
      scrollStyle: 'scrolledge',
      scale: 1,
      remoteOrigin: Offset.zero,
      remoteSize: remote,
      canvasX: canvasInset.dx,
      canvasY: canvasInset.dy,
      viewportSize: viewport,
      scrollX: 0,
      scrollY: 0.125,
    );
    expect(toolbarBand.remote, isNull);
    expect(toolbarBand.viewportPosition.dy, lessThan(0));
    expect(toolbarBand.viewportPosition.dy, closeTo(10 - 48, 1e-6));
    expect(toolbarBand.remote?.dy, isNot(closeTo(10 + 800 * 0.125, 1e-6)));
    expect(toolbarBand.remote?.dy, isNot(closeTo(800 * 0.125, 1e-6)));
  });

  test('menu storage and trackpad origin follow the toolbar inset', () {
    const scale = 1000 / 1920;
    const offset = Offset(0, 18.75);
    const remote = Size(1920, 1080);
    Offset contractRemote(Offset local) {
      return mapMeasuredAbsolutePointer(
        imageOverflow: false,
        scrollStyle: 'scrollauto',
        localPosition: local,
        scale: scale,
        remoteOrigin: Offset.zero,
        remoteSize: remote,
        canvasX: offset.dx,
        canvasY: offset.dy,
      ).remote!;
    }

    final shown = raatikToolbarImageInset(
      edge: RaatikToolbarEdge.top,
      toolbarShown: true,
      fullscreen: false,
    );
    expect(shown.top, 48);
    final shownOrigin = raatikRemoteImageOrigin(
      windowChrome: Offset.zero,
      toolbarInset: Offset(shown.left, shown.top),
    );
    final shownLocal = raatikMenuStoredPoint(
      windowPosition: const Offset(500, 348),
      imageOrigin: shownOrigin,
      viewportMeasured: true,
    );
    expect(shownLocal, const Offset(500, 300));
    _expectRemote(contractRemote(shownLocal), const Offset(960, 540));
    expect(
      raatikMenuStoredPoint(
        windowPosition: const Offset(500, 348),
        imageOrigin: shownOrigin,
        viewportMeasured: false,
      ),
      const Offset(500, 348),
    );

    final hidden = raatikToolbarImageInset(
      edge: RaatikToolbarEdge.top,
      toolbarShown: false,
      fullscreen: false,
    );
    expect(hidden.top, 20);
    final hiddenOrigin = raatikRemoteImageOrigin(
      windowChrome: Offset.zero,
      toolbarInset: Offset(hidden.left, hidden.top),
    );
    final hiddenLocal = raatikMenuStoredPoint(
      windowPosition: const Offset(500, 320),
      imageOrigin: hiddenOrigin,
      viewportMeasured: true,
    );
    expect(hiddenLocal, const Offset(500, 300));
    _expectRemote(contractRemote(hiddenLocal), const Offset(960, 540));
    final always48 = const Offset(500, 320) - const Offset(0, 48);
    expect(always48, isNot(hiddenLocal));
    expect(contractRemote(always48).dy, isNot(closeTo(540, 1)));

    final overflow = mapRetargetedWindowPoint(
      windowPoint: const Offset(210, 98),
      imageOrigin: shownOrigin,
      imageOverflow: true,
      scrollStyle: 'scrolledge',
      scale: 1,
      remoteOrigin: Offset.zero,
      remoteSize: const Size(400, 800),
      canvasX: 200,
      canvasY: -200,
      viewportSize: const Size(800, 400),
      scrollX: 0,
      scrollY: 0.125,
    );
    _expectRemote(overflow.remote, const Offset(10, 150));

    final toolbarBand = mapRetargetedWindowPoint(
      windowPoint: const Offset(210, 10),
      imageOrigin: shownOrigin,
      imageOverflow: true,
      scrollStyle: 'scrolledge',
      scale: 1,
      remoteOrigin: Offset.zero,
      remoteSize: const Size(400, 800),
      canvasX: 200,
      canvasY: -200,
      viewportSize: const Size(800, 400),
      scrollX: 0,
      scrollY: 0.125,
    );
    expect(toolbarBand.remote, isNull);
    expect(toolbarBand.viewportPosition.dy, lessThan(0));
    expect(
      toolbarBand.remote?.dy,
      isNot(closeTo(10 + 800 * 0.125, 1e-6)),
    );
    expect(toolbarBand.remote?.dy, isNot(closeTo(800 * 0.125, 1e-6)));
  });

  test('first measurement refresh maps a stored window point', () {
    const scale = 1000 / 1920;
    const offset = Offset(0, 18.75);
    const remote = Size(1920, 1080);
    const origin = Offset(0, 48);
    const windowPoint = Offset(500, 348);
    const imageLocal = Offset(500, 300);

    RaatikMeasurementRefresh decide({
      required Offset storedPoint,
      required bool windowSpace,
      bool viewportMeasured = true,
    }) {
      return decideRaatikMeasurementRefresh(
        storedPoint: storedPoint,
        windowSpace: windowSpace,
        viewportMeasured: viewportMeasured,
        imageOrigin: origin,
        imageOverflow: false,
        scrollStyle: 'scrollauto',
        scale: scale,
        remoteOrigin: Offset.zero,
        remoteSize: remote,
        canvasX: offset.dx,
        canvasY: offset.dy,
      );
    }

    final fromWindow = decide(storedPoint: windowPoint, windowSpace: true);
    expect(fromWindow.mapWindowPoint, isTrue);
    expect(fromWindow.viewportLocal, isFalse);
    _expectRemote(fromWindow.remote, const Offset(960, 540));

    final treatedAsImage = decide(storedPoint: windowPoint, windowSpace: false);
    expect(treatedAsImage.viewportLocal, isTrue);
    expect(treatedAsImage.mapWindowPoint, isFalse);
    expect(treatedAsImage.remote, isNotNull);
    expect(treatedAsImage.remote!.dy, isNot(closeTo(540, 1)));

    final fromImage = decide(storedPoint: imageLocal, windowSpace: false);
    expect(fromImage.viewportLocal, isTrue);
    expect(fromImage.mapWindowPoint, isFalse);
    _expectRemote(fromImage.remote, const Offset(960, 540));

    final subtractedAgain = decide(storedPoint: imageLocal, windowSpace: true);
    expect(subtractedAgain.remote, isNotNull);
    expect(subtractedAgain.remote!.dy, isNot(closeTo(540, 1)));

    final unmeasured = decide(
      storedPoint: windowPoint,
      windowSpace: true,
      viewportMeasured: false,
    );
    expect(unmeasured.viewportLocal, isFalse);
    expect(unmeasured.mapWindowPoint, isFalse);
    expect(unmeasured.remote, isNull);
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

  test('pointer exit waits for measured input', () {
    const local = Offset(120, 80);
    const window = Offset(500, 348);

    final off = decideRaatikPointerExit(
      measuredInput: false,
      localPosition: local,
      windowPosition: window,
    );
    expect(off.point, window);
    expect(off.viewportLocal, isFalse);
    expect(off.windowPosition, isNull);

    final on = decideRaatikPointerExit(
      measuredInput: true,
      localPosition: local,
      windowPosition: window,
    );
    expect(on.point, local);
    expect(on.viewportLocal, isTrue);
    expect(on.windowPosition, window);
  });

  test('measured input waits until the fit for that size is committed', () {
    const stored = Size(640, 672);
    expect(
      measuredInputReady(storedViewport: stored, fitCommittedFor: null),
      isFalse,
    );
    expect(
      measuredInputReady(storedViewport: stored, fitCommittedFor: stored),
      isTrue,
    );
    expect(
      measuredInputReady(storedViewport: null, fitCommittedFor: null),
      isFalse,
    );
    expect(
      measuredInputReady(storedViewport: null, fitCommittedFor: stored),
      isFalse,
    );
    expect(
      measuredInputReady(
        storedViewport: const Size(800, 600),
        fitCommittedFor: stored,
      ),
      isFalse,
    );
  });

  test('absolute input holds until the stored fit is committed', () {
    const stored = Size(640, 672);
    const other = Size(800, 600);

    expect(
      holdAbsoluteInputUntilFitCommit(
        desktopOrWebDesktop: true,
        storedViewport: null,
        fitCommittedFor: null,
      ),
      isFalse,
    );
    expect(
      holdAbsoluteInputUntilFitCommit(
        desktopOrWebDesktop: true,
        storedViewport: stored,
        fitCommittedFor: null,
      ),
      isTrue,
    );
    expect(
      holdAbsoluteInputUntilFitCommit(
        desktopOrWebDesktop: true,
        storedViewport: stored,
        fitCommittedFor: other,
      ),
      isTrue,
    );
    expect(
      holdAbsoluteInputUntilFitCommit(
        desktopOrWebDesktop: true,
        storedViewport: stored,
        fitCommittedFor: stored,
      ),
      isFalse,
    );
    expect(
      holdAbsoluteInputUntilFitCommit(
        desktopOrWebDesktop: false,
        storedViewport: stored,
        fitCommittedFor: null,
      ),
      isFalse,
    );
  });

  test('handlePointerDevicePos returns null before chrome subtraction', () {
    final file = File('lib/models/input_model.dart');
    expect(file.existsSync(), isTrue, reason: 'run from flutter/ directory');
    final src = file.readAsStringSync();
    final start = src.indexOf('Point? handlePointerDevicePos(');
    final end = src.indexOf('Point? _handlePointerDevicePos(');
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final body = src.substring(start, end).replaceAll('\r\n', '\n');
    final retarget = body.indexOf('decision.retarget != null');
    final hold = body.indexOf('holdAbsoluteInputUntilFitCommit(');
    final chrome = body.indexOf('y -= CanvasModel.topToEdge');
    expect(retarget, greaterThanOrEqualTo(0));
    expect(hold, greaterThan(retarget));
    expect(chrome, greaterThan(hold));
    final held = body.indexOf('return null;', hold);
    expect(held, greaterThan(hold));
    expect(held, lessThan(chrome));
    expect(body.contains('desktopOrWebDesktop: isDesktop || isWebDesktop'), isTrue);
    expect(body.contains('canvasModel.measuredViewport'), isTrue);
    expect(body.contains('canvasModel.measuredFitCommittedFor'), isTrue);
    expect(body.contains('y -= CanvasModel.topToEdge;\n      x -= CanvasModel.leftToEdge;'), isTrue);
  });

  test('unmounted view style skips refresh', () async {
    final log = <String>[];
    var mounted = true;
    await applyMeasuredViewportSize(
      size: const Size(640, 672),
      updateImageWidgetSize: (_) => log.add('image'),
      updateViewportSize: (_) => log.add('viewport'),
      updateViewStyle: () async {
        log.add('style');
        mounted = false;
      },
      stillMounted: () => mounted,
      refresh: () => log.add('refresh'),
      onChangeResolution: () => log.add('resolution'),
      onChangeQuality: () => log.add('quality'),
    );
    expect(log, ['image', 'viewport', 'style']);
  });

  test('superseded fit decision follows the captured size', () {
    const captured = Size(640, 672);
    const newer = Size(900, 700);

    RaatikSupersededFitDecision decide({
      bool mounted = true,
      Size? latest,
      Size? measuredViewport,
      Size? fitCommittedFor,
    }) {
      return decideSupersededMeasuredFit(
        mounted: mounted,
        captured: captured,
        latest: latest,
        measuredViewport: measuredViewport,
        fitCommittedFor: fitCommittedFor,
      );
    }

    final same = decide(
      latest: captured,
      measuredViewport: captured,
      fitCommittedFor: captured,
    );
    expect(same.refresh, isTrue);
    expect(same.drop, RaatikSupersededFitDrop.none);

    final notStoredYet = decide(
      latest: newer,
      measuredViewport: captured,
      fitCommittedFor: captured,
    );
    expect(notStoredYet.refresh, isFalse);
    expect(
      notStoredYet.drop,
      RaatikSupersededFitDrop.clearViewportAndCommit,
    );

    final commitOnly = decide(
      latest: newer,
      measuredViewport: newer,
      fitCommittedFor: captured,
    );
    expect(commitOnly.refresh, isFalse);
    expect(commitOnly.drop, RaatikSupersededFitDrop.clearCommitOnly);

    final alreadyReplaced = decide(
      latest: newer,
      measuredViewport: newer,
      fitCommittedFor: newer,
    );
    expect(alreadyReplaced.refresh, isFalse);
    expect(alreadyReplaced.drop, RaatikSupersededFitDrop.none);

    final unmounted = decide(
      mounted: false,
      latest: newer,
      measuredViewport: captured,
      fitCommittedFor: captured,
    );
    expect(unmounted.refresh, isFalse);
    expect(unmounted.drop, RaatikSupersededFitDrop.none);

    final kept = applySupersededMeasuredFitDrop(
      viewport: captured,
      committed: captured,
      drop: RaatikSupersededFitDrop.none,
    );
    expect(kept.viewport, captured);
    expect(kept.committed, captured);
    final cleared = applySupersededMeasuredFitDrop(
      viewport: captured,
      committed: captured,
      drop: RaatikSupersededFitDrop.clearViewportAndCommit,
    );
    expect(cleared.viewport, isNull);
    expect(cleared.committed, isNull);
    final commitCleared = applySupersededMeasuredFitDrop(
      viewport: newer,
      committed: captured,
      drop: RaatikSupersededFitDrop.clearCommitOnly,
    );
    expect(commitCleared.viewport, newer);
    expect(commitCleared.committed, isNull);
  });

  test('superseded measurement drops only the captured fit', () async {
    const captured = Size(640, 672);
    const newer = Size(900, 700);

    Future<void> check({
      required bool mounted,
      required Size? latest,
      required Size? viewportAfterStyle,
      required Size? committedAfterStyle,
      required bool refresh,
      required RaatikSupersededFitDrop? drop,
      required Size? viewport,
      required Size? committed,
    }) async {
      final log = <String>[];
      final drops = <RaatikSupersededFitDrop>[];
      Size? stored = captured;
      Size? fit;
      var resolutions = 0;
      var qualities = 0;
      await applyMeasuredViewportSize(
        size: captured,
        updateImageWidgetSize: (_) => log.add('image'),
        updateViewportSize: (size) {
          log.add('viewport');
          stored = size;
          fit = null;
        },
        updateViewStyle: () async {
          log.add('style');
          stored = viewportAfterStyle;
          fit = committedAfterStyle;
        },
        stillMounted: () => mounted,
        latestSize: () => latest,
        measuredViewport: () => stored,
        fitCommittedFor: () => fit,
        dropSupersededFit: (action) {
          log.add('drop');
          drops.add(action);
          final next = applySupersededMeasuredFitDrop(
            viewport: stored,
            committed: fit,
            drop: action,
          );
          stored = next.viewport;
          fit = next.committed;
        },
        refresh: () => log.add('refresh'),
        onChangeResolution: () => resolutions += 1,
        onChangeQuality: () => qualities += 1,
      );
      expect(resolutions, 0);
      expect(qualities, 0);
      expect(log, [
        'image',
        'viewport',
        'style',
        if (drop != null) 'drop',
        if (refresh) 'refresh',
      ]);
      expect(drops, drop == null ? isEmpty : [drop]);
      expect(stored, viewport);
      expect(fit, committed);
    }

    var ignored = false;
    await applyMeasuredViewportSize(
      size: Size.zero,
      updateImageWidgetSize: (_) => ignored = true,
      updateViewportSize: (_) => ignored = true,
      updateViewStyle: () async => ignored = true,
      refresh: () => ignored = true,
      latestSize: () => newer,
      dropSupersededFit: (_) => ignored = true,
    );
    expect(ignored, isFalse);

    await check(
      mounted: true,
      latest: captured,
      viewportAfterStyle: captured,
      committedAfterStyle: captured,
      refresh: true,
      drop: null,
      viewport: captured,
      committed: captured,
    );
    await check(
      mounted: true,
      latest: newer,
      viewportAfterStyle: captured,
      committedAfterStyle: captured,
      refresh: false,
      drop: RaatikSupersededFitDrop.clearViewportAndCommit,
      viewport: null,
      committed: null,
    );
    await check(
      mounted: true,
      latest: newer,
      viewportAfterStyle: newer,
      committedAfterStyle: captured,
      refresh: false,
      drop: RaatikSupersededFitDrop.clearCommitOnly,
      viewport: newer,
      committed: null,
    );
    await check(
      mounted: true,
      latest: newer,
      viewportAfterStyle: newer,
      committedAfterStyle: newer,
      refresh: false,
      drop: null,
      viewport: newer,
      committed: newer,
    );
    await check(
      mounted: false,
      latest: newer,
      viewportAfterStyle: captured,
      committedAfterStyle: captured,
      refresh: false,
      drop: null,
      viewport: captured,
      committed: captured,
    );
  });
}
