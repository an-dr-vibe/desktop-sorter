import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:system_tray/system_tray.dart';

enum TrayAction { open, sort, toggleMonitoring, exit }

class TrayService {
  TrayService({
    required this.onAction,
  });

  final Future<void> Function(TrayAction action) onAction;

  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  bool _initialized = false;

  Future<void> init({required bool monitoringEnabled}) async {
    final iconPath = await _materializeIcon();
    await _systemTray.initSystemTray(
      title: 'Desktop Sorter',
      iconPath: iconPath,
      toolTip: 'Desktop Sorter',
    );

    await _rebuildMenu(monitoringEnabled: monitoringEnabled);

    _systemTray.registerSystemTrayEventHandler((eventName) async {
      if (eventName == kSystemTrayEventClick ||
          eventName == kSystemTrayEventDoubleClick) {
        await onAction(TrayAction.open);
        return;
      }
      if (eventName == kSystemTrayEventRightClick) {
        await _systemTray.popUpContextMenu();
      }
    });

    _initialized = true;
  }

  Future<void> setMonitoringEnabled(bool enabled) async {
    if (!_initialized) {
      return;
    }
    await _rebuildMenu(monitoringEnabled: enabled);
  }

  Future<void> destroy() async {
    if (!_initialized) {
      return;
    }
    await _systemTray.destroy();
    _initialized = false;
  }

  Future<void> _rebuildMenu({required bool monitoringEnabled}) async {
    final toggleLabel = monitoringEnabled ? 'Disable monitoring' : 'Enable monitoring';

    await _menu.buildFrom([
      MenuItemLabel(
        label: 'Open settings',
        onClicked: (_) => onAction(TrayAction.open),
      ),
      MenuItemLabel(
        label: 'Sort now',
        onClicked: (_) => onAction(TrayAction.sort),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: toggleLabel,
        onClicked: (_) => onAction(TrayAction.toggleMonitoring),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Exit',
        onClicked: (_) => onAction(TrayAction.exit),
      ),
    ]);

    await _systemTray.setContextMenu(_menu);
  }

  Future<String> _materializeIcon() async {
    final iconData = await rootBundle.load('assets/app_icon.png');
    final output = File(p.join(Directory.systemTemp.path, 'desktop_sorter_tray_icon.png'));
    await output.writeAsBytes(iconData.buffer.asUint8List(), flush: true);
    return output.path;
  }
}