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
