import 'dart:math' as math;
import 'dart:ui';

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

/// Applies one changed measurement. Unusable sizes are ignored.
/// Call order is image size, viewport size, view style, then one refresh.
Future<void> applyMeasuredViewportSize({
  required Size size,
  required void Function(Size size) updateImageWidgetSize,
  required void Function(Size size) updateViewportSize,
  required Future<void> Function() updateViewStyle,
  required void Function() refresh,
}) async {
  if (!isUsableViewportSize(size)) return;
  updateImageWidgetSize(size);
  updateViewportSize(size);
  await updateViewStyle();
  refresh();
}
