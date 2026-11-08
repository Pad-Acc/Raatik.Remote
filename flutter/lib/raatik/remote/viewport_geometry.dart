import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Fitted remote image inside one measured viewport.
class RemoteViewportGeometry {
  const RemoteViewportGeometry({
    required this.scale,
    required this.offset,
  });

  final double scale;
  final Offset offset;
}

/// True when both axes are finite and strictly positive.
bool isUsableViewportSize(Size size) {
  return size.width.isFinite &&
      size.height.isFinite &&
      size.width > 0 &&
      size.height > 0;
}

/// Adaptive fit. Null when either size is nonfinite or nonpositive.
/// Scale is the minimum of the two ratios, including values above 1.
RemoteViewportGeometry? fitRemoteViewport(Size viewport, Size remote) {
  if (!isUsableViewportSize(viewport) || !isUsableViewportSize(remote)) {
    return null;
  }
  final widthRatio = viewport.width / remote.width;
  final heightRatio = viewport.height / remote.height;
  final scale = math.min(widthRatio, heightRatio);
  if (!scale.isFinite || scale <= 0) return null;
  final renderedWidth = remote.width * scale;
  final renderedHeight = remote.height * scale;
  // The limiting axis is flush with the viewport. Multiplying the ratio back
  // can leave a sub-ulp gap, which would disagree with an exact 0 offset.
  var dx = (viewport.width - renderedWidth) / 2;
  var dy = (viewport.height - renderedHeight) / 2;
  if (widthRatio <= heightRatio) {
    dx = 0;
  } else {
    dy = 0;
  }
  return RemoteViewportGeometry(
    scale: scale,
    offset: Offset(dx, dy),
  );
}

/// Adaptive uses [fitRemoteViewport]. Original and custom keep the current
/// canvas rules: scale 1 or the session factor, divided by DPR when DPI is ignored.
RemoteViewportGeometry? geometryForViewStyle({
  required String style,
  required Size viewport,
  required Size remote,
  double customScale = 1,
  double devicePixelRatio = 1,
  bool ignoreDpi = true,
}) {
  if (style == 'adaptive') {
    return fitRemoteViewport(viewport, remote);
  }
  if (!isUsableViewportSize(viewport) || !isUsableViewportSize(remote)) {
    return null;
  }
  var scale = style == 'custom' ? customScale : 1.0;
  if (ignoreDpi &&
      devicePixelRatio.isFinite &&
      devicePixelRatio > 0 &&
      scale != 0 &&
      (style == 'original' || style == 'custom')) {
    scale /= devicePixelRatio;
  }
  if (!scale.isFinite || scale <= 0) return null;
  return RemoteViewportGeometry(
    scale: scale,
    offset: Offset(
      (viewport.width - remote.width * scale) / 2,
      (viewport.height - remote.height * scale) / 2,
    ),
  );
}

/// Absolute pointer mapping: `remoteOrigin + (localPosition - offset) / scale`.
/// Returns null when the point is outside the fitted image. DPR is not applied.
Offset? remotePointFromViewport({
  required Offset localPosition,
  required Offset imageOffset,
  required double scale,
  required Offset remoteOrigin,
  required Size remoteSize,
}) {
  if (!scale.isFinite || scale <= 0) return null;
  if (!localPosition.dx.isFinite || !localPosition.dy.isFinite) return null;
  if (!isUsableViewportSize(remoteSize)) return null;
  final width = remoteSize.width * scale;
  final height = remoteSize.height * scale;
  if (!width.isFinite || !height.isFinite) return null;
  final left = imageOffset.dx;
  final top = imageOffset.dy;
  final right = left + width;
  final bottom = top + height;
  if (localPosition.dx < left ||
      localPosition.dy < top ||
      localPosition.dx > right ||
      localPosition.dy > bottom) {
    return null;
  }
  return remoteOrigin + (localPosition - imageOffset) / scale;
}

/// Scrollbar overflow listens on the image, so [localPosition] is already
/// content space. [scrollX] and [scrollY] are not added again. A point outside
/// the image returns null.
Offset? remotePointFromScrollbarImage({
  required Offset localPosition,
  required double scale,
  required Offset remoteOrigin,
  required Size remoteSize,
  double scrollX = 0,
  double scrollY = 0,
}) {
  if (!scrollX.isFinite || !scrollY.isFinite) return null;
  return remotePointFromViewport(
    localPosition: localPosition,
    imageOffset: Offset.zero,
    scale: scale,
    remoteOrigin: remoteOrigin,
    remoteSize: remoteSize,
  );
}

/// Measured scrollbar and scrolledge pointers are image-local, including a
/// scrollbar session whose canvas offset is still zero. [scrollX], [scrollY],
/// [canvasX], [canvasY], and [canvasSize] do not move the point. A centering
/// inset is not applied. A point outside the image returns null.
Offset? remotePointFromMeasuredScrollImage({
  required String scrollStyle,
  required Offset localPosition,
  required double scale,
  required Offset remoteOrigin,
  required Size remoteSize,
  double scrollX = 0,
  double scrollY = 0,
  double canvasX = 0,
  double canvasY = 0,
  Size canvasSize = Size.zero,
}) {
  if (scrollStyle != 'scrollbar' && scrollStyle != 'scrolledge') return null;
  if (!canvasX.isFinite || !canvasY.isFinite) return null;
  if (!canvasSize.width.isFinite || !canvasSize.height.isFinite) return null;
  return remotePointFromScrollbarImage(
    localPosition: localPosition,
    scale: scale,
    remoteOrigin: remoteOrigin,
    remoteSize: remoteSize,
    scrollX: scrollX,
    scrollY: scrollY,
  );
}

/// Remote point and the viewport-space position for edge scroll and canvas pan.
class MeasuredAbsolutePointer {
  const MeasuredAbsolutePointer({
    required this.remote,
    required this.viewportPosition,
    required this.unbounded,
  });

  /// Null when the point is outside the image or the inputs cannot be mapped.
  final Offset? remote;

  /// Viewport space (`0..size`) for edge scroll and canvas pan.
  /// Image-listener content converted from the scroll fraction or the integer
  /// spacer. Every other listener uses the viewport-local point.
  final Offset viewportPosition;

  /// Same mapping as [remote], including a point outside the image.
  /// Null only when the scale or positions are unusable.
  final Offset? unbounded;
}

/// Visible point of one image-listener axis.
///
/// A scrolled axis subtracts `imageExtent * scrollFraction`. An unfilled axis
/// adds the integer spacer `((viewportExtent - imageExtent) ~/ 2)`.
/// The centering inset is not an input.
double viewportAxisFromImageListener({
  required double local,
  required double viewportExtent,
  required double imageExtent,
  required double scrollFraction,
}) {
  if (!local.isFinite ||
      !viewportExtent.isFinite ||
      !imageExtent.isFinite ||
      imageExtent < 0) {
    return local;
  }
  if (viewportExtent < imageExtent) {
    final fraction = scrollFraction.isFinite ? scrollFraction : 0.0;
    return local - imageExtent * fraction;
  }
  final spacer = ((viewportExtent - imageExtent) ~/ 2).toDouble();
  return local + spacer;
}

/// Image-listener content of one axis from a viewport-space point.
///
/// Inverse of [viewportAxisFromImageListener]. A scrolled axis adds
/// `imageExtent * scrollFraction`. An unfilled axis subtracts the integer
/// spacer `((viewportExtent - imageExtent) ~/ 2)`. The centering inset is
/// not an input. Used only by [mapRetargetedWindowPoint].
double imageListenerAxisFromViewport({
  required double viewport,
  required double viewportExtent,
  required double imageExtent,
  required double scrollFraction,
}) {
  if (!viewport.isFinite ||
      !viewportExtent.isFinite ||
      !imageExtent.isFinite ||
      imageExtent < 0) {
    return viewport;
  }
  if (viewportExtent < imageExtent) {
    final fraction = scrollFraction.isFinite ? scrollFraction : 0.0;
    return viewport + imageExtent * fraction;
  }
  final spacer = ((viewportExtent - imageExtent) ~/ 2).toDouble();
  return viewport - spacer;
}

/// Maps one measured absolute pointer in the listener's coordinate space.
///
/// The listener is the scrolled image only when [imageOverflow] is true and
/// [scrollStyle] is not `scrollauto`. That path maps
/// `remoteOrigin + local / scale` and converts the visible point with
/// [viewportAxisFromImageListener]. Every other measured pointer, including
/// scroll-auto, is viewport-local and keeps [canvasX] / [canvasY] as the image offset.
MeasuredAbsolutePointer mapMeasuredAbsolutePointer({
  required bool imageOverflow,
  required String scrollStyle,
  required Offset localPosition,
  required double scale,
  required Offset remoteOrigin,
  required Size remoteSize,
  required double canvasX,
  required double canvasY,
  Size viewportSize = Size.zero,
  double scrollX = 0,
  double scrollY = 0,
}) {
  final imageListener = imageOverflow && scrollStyle != 'scrollauto';
  final canvasOffset = Offset(canvasX, canvasY);
  final imageOffset = imageListener ? Offset.zero : canvasOffset;
  final imageExtent = Size(remoteSize.width * scale, remoteSize.height * scale);
  final viewportPosition = imageListener
      ? Offset(
          viewportAxisFromImageListener(
            local: localPosition.dx,
            viewportExtent: viewportSize.width,
            imageExtent: imageExtent.width,
            scrollFraction: scrollX,
          ),
          viewportAxisFromImageListener(
            local: localPosition.dy,
            viewportExtent: viewportSize.height,
            imageExtent: imageExtent.height,
            scrollFraction: scrollY,
          ),
        )
      : localPosition;
  if (!canvasX.isFinite || !canvasY.isFinite) {
    return MeasuredAbsolutePointer(
      remote: null,
      viewportPosition: viewportPosition,
      unbounded: null,
    );
  }
  return MeasuredAbsolutePointer(
    remote: remotePointFromViewport(
      localPosition: localPosition,
      imageOffset: imageOffset,
      scale: scale,
      remoteOrigin: remoteOrigin,
      remoteSize: remoteSize,
    ),
    viewportPosition: viewportPosition,
    unbounded: _unboundedRemotePoint(
      localPosition: localPosition,
      imageOffset: imageOffset,
      scale: scale,
      remoteOrigin: remoteOrigin,
      remoteSize: remoteSize,
    ),
  );
}

/// Maps a point already in the destination window through that window's image.
///
/// The image-viewport point is `windowPoint - imageOrigin`. A viewport listener
/// (scroll-auto or fitted) then maps
/// `remoteOrigin + (windowPoint - imageOrigin - offset) / scale`.
/// An overflow image listener converts that viewport point with
/// [imageListenerAxisFromViewport] before [mapMeasuredAbsolutePointer].
/// [canvasX] and [canvasY] are not that scroll translation. A point outside
/// the destination image leaves [MeasuredAbsolutePointer.remote] null.
MeasuredAbsolutePointer mapRetargetedWindowPoint({
  required Offset windowPoint,
  required Offset imageOrigin,
  required bool imageOverflow,
  required String scrollStyle,
  required double scale,
  required Offset remoteOrigin,
  required Size remoteSize,
  required double canvasX,
  required double canvasY,
  Size viewportSize = Size.zero,
  double scrollX = 0,
  double scrollY = 0,
}) {
  final viewportPoint = windowPoint - imageOrigin;
  final imageListener = imageOverflow && scrollStyle != 'scrollauto';
  final imageExtent = Size(remoteSize.width * scale, remoteSize.height * scale);
  final localPosition = imageListener
      ? Offset(
          imageListenerAxisFromViewport(
            viewport: viewportPoint.dx,
            viewportExtent: viewportSize.width,
            imageExtent: imageExtent.width,
            scrollFraction: scrollX,
          ),
          imageListenerAxisFromViewport(
            viewport: viewportPoint.dy,
            viewportExtent: viewportSize.height,
            imageExtent: imageExtent.height,
            scrollFraction: scrollY,
          ),
        )
      : viewportPoint;
  return mapMeasuredAbsolutePointer(
    imageOverflow: imageOverflow,
    scrollStyle: scrollStyle,
    localPosition: localPosition,
    scale: scale,
    remoteOrigin: remoteOrigin,
    remoteSize: remoteSize,
    canvasX: canvasX,
    canvasY: canvasY,
    viewportSize: viewportSize,
    scrollX: scrollX,
    scrollY: scrollY,
  );
}

Offset? _unboundedRemotePoint({
  required Offset localPosition,
  required Offset imageOffset,
  required double scale,
  required Offset remoteOrigin,
  required Size remoteSize,
}) {
  if (!scale.isFinite || scale <= 0) return null;
  if (!localPosition.dx.isFinite || !localPosition.dy.isFinite) return null;
  if (!imageOffset.dx.isFinite || !imageOffset.dy.isFinite) return null;
  if (!remoteOrigin.dx.isFinite || !remoteOrigin.dy.isFinite) return null;
  if (!remoteSize.width.isFinite ||
      !remoteSize.height.isFinite ||
      remoteSize.width <= 0 ||
      remoteSize.height <= 0) {
    return null;
  }
  return remoteOrigin + (localPosition - imageOffset) / scale;
}

/// Another remote window, in the same coordinate space as the pointer probe.
class MeasuredWindowSpan {
  const MeasuredWindowSpan({
    required this.relativeOffset,
    required this.size,
  });

  final Offset relativeOffset;
  final Size size;
}

/// Pointer moved from the current window into [index] without toolbar inset.
class MeasuredPointerRetarget {
  const MeasuredPointerRetarget({
    required this.x,
    required this.y,
    required this.index,
  });

  final double x;
  final double y;
  final int index;
}

/// Retarget a captured move that has left the current window.
/// Coordinates stay in the caller's space. Toolbar chrome is not subtracted.
MeasuredPointerRetarget? retargetMeasuredPointer({
  required bool isMove,
  required double x,
  required double y,
  required Size currentWindow,
  required List<MeasuredWindowSpan> others,
  required double devicePixelRatio,
  required bool windowsPhysicalOffsets,
}) {
  if (!isMove || others.isEmpty) return null;
  if (!x.isFinite || !y.isFinite) return null;
  if (x >= 0 &&
      y >= 0 &&
      x <= currentWindow.width &&
      y <= currentWindow.height) {
    return null;
  }
  final scalePhysical = windowsPhysicalOffsets &&
      devicePixelRatio.isFinite &&
      devicePixelRatio > 0;
  final scale = scalePhysical ? devicePixelRatio : 1.0;
  final px = scalePhysical ? x * scale : x;
  final py = scalePhysical ? y * scale : y;
  for (var i = 0; i < others.length; i++) {
    final window = others[i];
    final right = window.relativeOffset.dx + window.size.width;
    final bottom = window.relativeOffset.dy + window.size.height;
    if (px >= window.relativeOffset.dx &&
        py >= window.relativeOffset.dy &&
        px <= right &&
        py <= bottom) {
      return MeasuredPointerRetarget(
        x: x - window.relativeOffset.dx / scale,
        y: y - window.relativeOffset.dy / scale,
        index: i,
      );
    }
  }
  return null;
}

/// Which coordinates a measured absolute pointer should follow.
class MeasuredPointerDecision {
  const MeasuredPointerDecision({
    required this.useMeasuredLocal,
    required this.x,
    required this.y,
    this.retarget,
  });

  /// True when [x] and [y] are the in-window measured local point.
  final bool useMeasuredLocal;

  /// Measured local point, or window coordinates for the non-measured path.
  final double x;
  final double y;

  /// Another session window hit by the window position.
  final MeasuredPointerRetarget? retarget;
}

/// Retarget from the window position before measured mapping.
///
/// A hit on another session wins, including when [viewportLocal] is true, and
/// [useMeasuredLocal] is then false. A window position still inside this
/// window uses [measuredLocal] only when [viewportLocal] is true. Refresh has
/// no pointer event: [hasWindowPosition] is false, so this does not retarget.
MeasuredPointerDecision decideMeasuredPointer({
  required bool viewportLocal,
  required bool isMove,
  required bool hasWindowPosition,
  required double windowX,
  required double windowY,
  required Offset measuredLocal,
  required Size currentWindow,
  required List<MeasuredWindowSpan> others,
  required double devicePixelRatio,
  required bool windowsPhysicalOffsets,
}) {
  if (!hasWindowPosition || !windowX.isFinite || !windowY.isFinite) {
    return MeasuredPointerDecision(
      useMeasuredLocal: viewportLocal,
      x: viewportLocal ? measuredLocal.dx : windowX,
      y: viewportLocal ? measuredLocal.dy : windowY,
    );
  }
  final retarget = retargetMeasuredPointer(
    isMove: isMove,
    x: windowX,
    y: windowY,
    currentWindow: currentWindow,
    others: others,
    devicePixelRatio: devicePixelRatio,
    windowsPhysicalOffsets: windowsPhysicalOffsets,
  );
  if (retarget != null) {
    return MeasuredPointerDecision(
      useMeasuredLocal: false,
      x: retarget.x,
      y: retarget.y,
      retarget: retarget,
    );
  }
  final inside = windowX >= 0 &&
      windowY >= 0 &&
      windowX <= currentWindow.width &&
      windowY <= currentWindow.height;
  if (viewportLocal && inside) {
    return MeasuredPointerDecision(
      useMeasuredLocal: true,
      x: measuredLocal.dx,
      y: measuredLocal.dy,
    );
  }
  return MeasuredPointerDecision(
    useMeasuredLocal: false,
    x: windowX,
    y: windowY,
  );
}

/// Applies one changed measurement. Unusable sizes are ignored.
/// Call order is image size, viewport size, view style, then one refresh.
/// [onChangeResolution] and [onChangeQuality] are not called.
Future<void> applyMeasuredViewportSize({
  required Size size,
  required void Function(Size size) updateImageWidgetSize,
  required void Function(Size size) updateViewportSize,
  required Future<void> Function() updateViewStyle,
  required void Function() refresh,
  VoidCallback? onChangeResolution,
  VoidCallback? onChangeQuality,
}) async {
  if (!isUsableViewportSize(size)) return;
  updateImageWidgetSize(size);
  updateViewportSize(size);
  await updateViewStyle();
  refresh();
}
