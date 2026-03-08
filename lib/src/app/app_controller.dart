import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../config/config_store.dart';
import '../core/autostart_service.dart';
import '../core/desktop_monitor.dart';
import '../core/tray_service.dart';
import '../models/app_config.dart';
import '../models/sort_outcome.dart';
import '../core/sorter.dart';
import 'runtime_state.dart';

class AppController extends ChangeNotifier with WindowListener {
  AppController({
    required this.configPath,
    required this.startHidden,
  }) {
    _state = RuntimeState(
      config: AppConfig.defaults(),
      configPath: configPath,
      monitoringActive: false,
      trayAvailable: false,
      autostartActive: false,
      statusLine: 'Idle',
      recentEvents: const [],
      revision: 1,
    );
  }

  final String configPath;
  final bool startHidden;

  late RuntimeState _state;
  RuntimeState get state => _state;

  DesktopMonitor? _monitor;
  TrayService? _tray;
  bool _allowExit = false;
  bool _disposed = false;

  Future<void> initialize() async {
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);

    AppConfig loadedConfig;
    try {
      loadedConfig = await ConfigStore.loadFromPath(configPath);
      _pushEvent('Loaded config $configPath');
    } catch (e) {
      loadedConfig = AppConfig.defaults();
      _pushEvent('Using defaults: $e');
    }

    _setState(_state.copyWith(config: loadedConfig, configPath: configPath));

    _monitor = DesktopMonitor(
      getConfig: () => _state.config,
      onOutcome: (outcome) async => _recordOutcome(outcome),
      onMessage: (message) async => _recordMessage(message),
    );

    await _refreshRuntimeState();

    final tray = TrayService(onAction: _handleTrayAction);
    try {
      await tray.init(monitoringEnabled: _state.config.monitoringEnabled);
      _tray = tray;
      _setState(_state.copyWith(trayAvailable: true));
      _pushEvent('Tray initialized');
    } catch (e) {
      _pushEvent('Tray startup failed: $e');
      _setState(_state.copyWith(trayAvailable: false));
      if (startHidden) {
        _pushEvent('Ignoring --hidden: tray unavailable');
      }
    }

    if (startHidden && _state.trayAvailable) {
      await hideToTray();
    } else {
      await showWindow();
    }
  }

  Future<void> saveConfig(AppConfig config) async {
    final normalized = config.normalized();

    try {
      await ConfigStore.saveToPath(normalized, configPath);
      _setState(_state.copyWith(config: normalized));
      _pushEvent('Saved config $configPath');
      _setStatus('Config saved');
    } catch (e) {
      _pushEvent('Save failed: $e');
      _setStatus('Save failed');
      return;
    }

    await _refreshRuntimeState();
  }

  Future<void> reloadConfig() async {
    try {
      final loaded = await ConfigStore.loadFromPath(configPath);
      _setState(_state.copyWith(config: loaded));
      _pushEvent('Reloaded config $configPath');
      _setStatus('Config reloaded');
      await _refreshRuntimeState();
    } catch (e) {
      _pushEvent('Reload failed: $e');
      _setStatus('Reload failed');
    }
  }

  Future<void> sortNow() async {
    final config = _state.config;
    final dir = Directory(config.desktopPath);

    if (!await dir.exists()) {
      _pushEvent('Sort failed for ${config.desktopPath}: folder not found');
      _setStatus('Sort failed');
      return;
    }

    try {
      await for (final entry in dir.list(recursive: false, followLinks: false)) {
        if (entry is File) {
          final outcome = await Sorter.processFile(entry.path, config);
          await _recordOutcome(outcome);
        }
      }
      _setStatus('Sort completed');
    } catch (e) {
      _pushEvent('Sort failed for ${config.desktopPath}: $e');
      _setStatus('Sort failed');
    }
  }

  Future<void> toggleMonitoring() async {
    final updated = _state.config.copyWith(
      monitoringEnabled: !_state.config.monitoringEnabled,
    );
    await saveConfig(updated);
  }

  Future<void> hideToTray() async {
    await windowManager.setSkipTaskbar(true);
    await windowManager.hide();
  }

  Future<void> showWindow() async {
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> shutdownAndExit() async {
    _allowExit = true;
    await _monitor?.stop();
    await _tray?.destroy();
    _tray = null;
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  Future<void> disposeServices() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    windowManager.removeListener(this);
    await _monitor?.stop();
    await _tray?.destroy();
    _tray = null;
  }

  @override
  void onWindowClose() {
    if (_allowExit) {
      return;
    }
    unawaited(hideToTray());
  }

  Future<void> _refreshRuntimeState() async {
    try {
      await AutostartService.setEnabled(
        enabled: _state.config.autostartEnabled,
        configPath: configPath,
      );
      _setState(_state.copyWith(autostartActive: _state.config.autostartEnabled));
    } catch (e) {
      final active = await AutostartService.isEnabled();
      _setState(_state.copyWith(autostartActive: active));
      _pushEvent('Autostart update failed: $e');
    }

    if (_state.config.monitoringEnabled) {
      try {
        await _monitor?.restartIfNeeded();
        _setState(_state.copyWith(monitoringActive: true));
        _setStatus('Monitoring enabled');
      } catch (e) {
        _setState(_state.copyWith(monitoringActive: false));
        _pushEvent('Monitoring failed: $e');
        _setStatus('Monitoring failed');
      }
    } else {
      await _monitor?.stop();
      _setState(_state.copyWith(monitoringActive: false));
      _setStatus('Monitoring disabled');
    }

    await _tray?.setMonitoringEnabled(_state.config.monitoringEnabled);
  }

  Future<void> _handleTrayAction(TrayAction action) async {
    switch (action) {
      case TrayAction.open:
        await showWindow();
        return;
      case TrayAction.sort:
        await sortNow();
        return;
      case TrayAction.toggleMonitoring:
        await toggleMonitoring();
        return;
      case TrayAction.exit:
        await shutdownAndExit();
        return;
    }
  }

  Future<void> _recordOutcome(SortOutcome outcome) async {
    _pushEvent(outcome.message);
    switch (outcome.type) {
      case SortOutcomeType.failed:
        _setStatus('Last action failed');
        break;
      case SortOutcomeType.moved:
        _setStatus('File moved');
        break;
      case SortOutcomeType.trashed:
        _setStatus('File moved to trash');
        break;
      case SortOutcomeType.kept:
        _setStatus('File kept on desktop');
        break;
      case SortOutcomeType.skipped:
        _touch();
        break;
    }
  }

  Future<void> _recordMessage(String message) async {
    _pushEvent(message);
  }

  void _setStatus(String status) {
    _setState(_state.copyWith(statusLine: status));
  }

  void _pushEvent(String message) {
    final events = <String>[message, ..._state.recentEvents];
    if (events.length > 200) {
      events.removeRange(200, events.length);
    }
    _setState(_state.copyWith(recentEvents: events));
  }

  void _touch() {
    _setState(_state);
  }

  void _setState(RuntimeState newState) {
    _state = newState.copyWith(revision: _state.revision + 1);
    if (!_disposed) {
      notifyListeners();
    }
  }
}