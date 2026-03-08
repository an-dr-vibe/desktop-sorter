import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class FullscreenDetector {
  static bool isFullscreenActive() {
    if (!Platform.isWindows) {
      return false;
    }

    final hwnd = GetForegroundWindow();
    if (hwnd == 0) {
      return false;
    }

    if (IsIconic(hwnd) != 0 || IsWindowVisible(hwnd) == 0) {
      return false;
    }

    final monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    if (monitor == 0) {
      return false;
    }

    final monitorInfo = calloc.allocate<MONITORINFO>(sizeOf<MONITORINFO>());
    final windowRect = calloc.allocate<RECT>(sizeOf<RECT>());
    monitorInfo.ref.cbSize = sizeOf<MONITORINFO>();

    try {
      if (GetMonitorInfo(monitor, monitorInfo.cast()) == 0) {
        return false;
      }

      if (GetWindowRect(hwnd, windowRect) == 0) {
        return false;
      }

      final mon = monitorInfo.ref.rcMonitor;
      final win = windowRect.ref;

      const tolerance = 2;

      final fullWidth = (win.right - win.left) >= (mon.right - mon.left - tolerance);
      final fullHeight = (win.bottom - win.top) >= (mon.bottom - mon.top - tolerance);
      final alignedLeft = win.left <= mon.left + tolerance;
      final alignedTop = win.top <= mon.top + tolerance;
      final alignedRight = win.right >= mon.right - tolerance;
      final alignedBottom = win.bottom >= mon.bottom - tolerance;

      return fullWidth &&
          fullHeight &&
          alignedLeft &&
          alignedTop &&
          alignedRight &&
          alignedBottom;
    } finally {
      calloc.free(windowRect);
      calloc.free(monitorInfo);
    }
  }
}