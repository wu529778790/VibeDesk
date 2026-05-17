import 'dart:ui';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CoordinateScaler {
  int hostScreenWidth;
  int hostScreenHeight;
  Size widgetSize;

  CoordinateScaler({
    this.hostScreenWidth = 1920,
    this.hostScreenHeight = 1080,
    this.widgetSize = Size.zero,
  });

  (double, double) scale(
    double widgetX,
    double widgetY,
    RTCVideoRenderer renderer,
  ) {
    if (widgetSize == Size.zero) return (widgetX, widgetY);

    final videoWidth = renderer.videoWidth.toDouble();
    final videoHeight = renderer.videoHeight.toDouble();
    if (videoWidth <= 0 || videoHeight <= 0) return (widgetX, widgetY);

    final widgetW = widgetSize.width;
    final widgetH = widgetSize.height;

    final videoAspect = videoWidth / videoHeight;
    final widgetAspect = widgetW / widgetH;

    double renderW, renderH, offsetX, offsetY;
    if (videoAspect > widgetAspect) {
      renderW = widgetW;
      renderH = widgetW / videoAspect;
      offsetX = 0;
      offsetY = (widgetH - renderH) / 2;
    } else {
      renderH = widgetH;
      renderW = widgetH * videoAspect;
      offsetX = (widgetW - renderW) / 2;
      offsetY = 0;
    }

    var clampedX = widgetX.clamp(offsetX, offsetX + renderW);
    var clampedY = widgetY.clamp(offsetY, offsetY + renderH);

    final videoX = (clampedX - offsetX) / renderW * videoWidth;
    final videoY = (clampedY - offsetY) / renderH * videoHeight;

    final hostX = videoX / videoWidth * hostScreenWidth;
    final hostY = videoY / videoHeight * hostScreenHeight;

    return (hostX, hostY);
  }
}
