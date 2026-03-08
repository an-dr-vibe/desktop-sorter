import 'dart:async';
import 'dart:collection';
import 'dart:io';

import '../models/app_config.dart';
import '../models/sort_outcome.dart';
import 'fullscreen_detector.dart';
import 'sorter.dart';

typedef ConfigProvider = AppConfig Function();
typedef OutcomeCallback = Future<void> Function(SortOutcome outcome);
typedef MessageCallback = Future<void> Function(String message);

class DesktopMonitor {
  DesktopMonitor({
    required this.getConfig,
    required this.onOutcome,
    required this.onMessage,
  });

  final ConfigProvider getConfig;
  final OutcomeCallback onOutcome;
  final MessageCallback onMessage;

  static const Duration _baseDebounce = Duration(milliseconds: 1300);
  static const Duration _tick = Duration(milliseconds: 250);

  StreamSubscription<FileSystemEvent>? _watchSub;
  Timer? _tickTimer;
  final Map<String, DateTime> _pending = HashMap();
  bool _processing = false;

  String? _desktopPath;

  bool get isActive => _watchSub != null;

  Future<void> start() async {
    final config = getConfig();
    final path = config.desktopPath;
    await Directory(path).create(recursive: true);

    await stop();

    _desktopPath = path;
    _watchSub = Directory(path)
        .watch(events: FileSystemEvent.create | FileSystemEvent.modify)
        .listen(_onEvent, onError: (Object error) async {
      await onMessage('Watch error: $error');
    });

    _tickTimer = Timer.periodic(_tick, (_) {
      if (_processing) {
        return;
      }
      _processing = true;
      _drainDue().whenComplete(() => _processing = false);
    });
  }

  Future<void> stop() async {
    await _watchSub?.cancel();
    _watchSub = null;
    _tickTimer?.cancel();
    _tickTimer = null;
    _pending.clear();
  }

  Future<void> restartIfNeeded() async {
    final config = getConfig();
    if (!config.monitoringEnabled) {
      await stop();
      return;
    }

    if (!isActive || _desktopPath != config.desktopPath) {
      await start();
    }
  }

  void _onEvent(FileSystemEvent event) {
    final delay = _processingDelay(getConfig());
    _pending[event.path] = DateTime.now().add(delay);
  }

  Duration _processingDelay(AppConfig config) {
    final minAge = Duration(seconds: config.minFileAgeSeconds);
    return minAge > _baseDebounce ? minAge : _baseDebounce;
  }

  Future<void> _drainDue() async {
    final config = getConfig();
    if (!config.monitoringEnabled) {
      _pending.clear();
      return;
    }

    final now = DateTime.now();
    final due = _pending.entries
        .where((entry) => !entry.value.isAfter(now))
        .map((entry) => entry.key)
        .toList(growable: false);

    for (final path in due) {
      _pending.remove(path);

      final currentConfig = getConfig();
      final pause = currentConfig.pauseWhenFullscreen && FullscreenDetector.isFullscreenActive();
      if (pause) {
        _pending[path] = DateTime.now().add(const Duration(seconds: 10));
        continue;
      }

      await _processWhenStable(path, currentConfig);
    }
  }

  Future<void> _processWhenStable(String path, AppConfig config) async {
    final stable = await _waitUntilStable(path);
    if (!stable) {
      await onMessage('Skipped $path (still changing)');
      return;
    }

    final outcome = await Sorter.processFile(path, config);
    await onOutcome(outcome);
  }

  Future<bool> _waitUntilStable(String path) async {
    int? previousSize;
    DateTime? previousModified;

    for (var i = 0; i < 6; i++) {
      final file = File(path);
      if (!await file.exists()) {
        return false;
      }

      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) {
        return false;
      }

      final currentSize = stat.size;
      final currentModified = stat.modified;

      if (previousSize == currentSize && previousModified == currentModified) {
        return true;
      }

      previousSize = currentSize;
      previousModified = currentModified;
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    return false;
  }
}