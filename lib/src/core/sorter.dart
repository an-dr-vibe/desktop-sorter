import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/app_config.dart';
import '../models/sort_outcome.dart';
import 'path_utils.dart';
import 'recycle_bin.dart';

class Sorter {
  static Future<SortOutcome> processFile(String filePath, AppConfig config) async {
    final file = File(filePath);

    if (!await file.exists()) {
      return SortOutcome(
        type: SortOutcomeType.skipped,
        file: filePath,
        message: 'Skipped $filePath (file disappeared)',
      );
    }

    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) {
      return SortOutcome(
        type: SortOutcomeType.skipped,
        file: filePath,
        message: 'Skipped $filePath (not a regular file)',
      );
    }

    final fileName = p.basename(file.path);
    if (fileName.startsWith('.')) {
      return SortOutcome(
        type: SortOutcomeType.skipped,
        file: filePath,
        message: 'Skipped $filePath (hidden file)',
      );
    }

    final ext = _extensionOf(fileName);
    String? keepMatch;

    for (final rule in config.rules) {
      if (!rule.matchesFile(fileName, ext)) {
        continue;
      }

      switch (rule.mode) {
        case SortMode.keep:
          if (rule.stopAfterMatch) {
            return SortOutcome(
              type: SortOutcomeType.kept,
              file: filePath,
              message: 'Kept on desktop $filePath (${rule.name})',
            );
          }
          keepMatch = rule.name;
          continue;

        case SortMode.trash:
          try {
            await RecycleBin.moveToTrash(file.path);
            return SortOutcome(
              type: SortOutcomeType.trashed,
              file: filePath,
              message: 'Moved to trash $filePath (${rule.name})',
            );
          } catch (e) {
            return SortOutcome(
              type: SortOutcomeType.failed,
              file: filePath,
              message: 'Failed $filePath (trash failed: $e)',
            );
          }

        case SortMode.move:
        case SortMode.pattern:
          return _moveByRule(file, config, rule);
      }
    }

    if (keepMatch != null) {
      return SortOutcome(
        type: SortOutcomeType.kept,
        file: filePath,
        message: 'Kept on desktop $filePath ($keepMatch)',
      );
    }

    return SortOutcome(
      type: SortOutcomeType.skipped,
      file: filePath,
      message: 'Skipped $filePath (no rule matched)',
    );
  }

  static Future<SortOutcome> _moveByRule(
    File file,
    AppConfig config,
    SortRule rule,
  ) async {
    final source = file.path;

    try {
      var destination = await _resolveDestination(file, config, rule);
      destination = await _uniqueDestination(destination);

      if (_normalizePath(source) == _normalizePath(destination)) {
        return SortOutcome(
          type: SortOutcomeType.skipped,
          file: source,
          message: 'Skipped $source (source equals destination)',
        );
      }

      await AppPaths.ensureParentDir(destination);

      await _moveFile(source, destination);

      return SortOutcome(
        type: SortOutcomeType.moved,
        file: source,
        message: 'Moved $source -> $destination (${rule.name})',
      );
    } catch (e) {
      return SortOutcome(
        type: SortOutcomeType.failed,
        file: source,
        message: 'Failed $source ($e)',
      );
    }
  }

  static Future<String> _resolveDestination(
    File file,
    AppConfig config,
    SortRule rule,
  ) async {
    final baseTarget = AppPaths.resolveUserPath(rule.targetFolder, config.desktopPath);

    switch (rule.mode) {
      case SortMode.move:
        return p.join(baseTarget, p.basename(file.path));
      case SortMode.pattern:
        final relative = await _applyPattern(rule.targetPattern, file.path);
        return p.join(baseTarget, relative);
      case SortMode.trash:
      case SortMode.keep:
        throw StateError('This rule mode does not move files');
    }
  }

  static Future<String> _applyPattern(String pattern, String filePath) async {
    final name = p.basenameWithoutExtension(filePath);
    final ext = _extensionOf(p.basename(filePath)) ?? '';
    final stat = await File(filePath).stat();
    final modified = stat.modified;

    final yyyy = modified.year.toString().padLeft(4, '0');
    final mm = modified.month.toString().padLeft(2, '0');
    final dd = modified.day.toString().padLeft(2, '0');
    final hh = modified.hour.toString().padLeft(2, '0');
    final min = modified.minute.toString().padLeft(2, '0');
    final ss = modified.second.toString().padLeft(2, '0');

    return pattern
        .replaceAll('{name}', _sanitizeSegment(name))
        .replaceAll('{ext}', ext)
        .replaceAll('{yyyy}', yyyy)
        .replaceAll('{MM}', mm)
        .replaceAll('{dd}', dd)
        .replaceAll('{HH}', hh)
        .replaceAll('{mm}', min)
        .replaceAll('{ss}', ss);
  }

  static String _sanitizeSegment(String value) {
    return value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  static String? _extensionOf(String fileName) {
    final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
    return ext.isEmpty ? null : ext;
  }

  static Future<String> _uniqueDestination(String destination) async {
    if (!await File(destination).exists()) {
      return destination;
    }

    final parent = p.dirname(destination);
    final stem = p.basenameWithoutExtension(destination);
    final extension = p.extension(destination);

    var index = 2;
    while (true) {
      final candidate = p.join(parent, '$stem ($index)$extension');
      if (!await File(candidate).exists()) {
        return candidate;
      }
      index++;
    }
  }

  static Future<void> _moveFile(String source, String destination) async {
    final src = File(source);
    try {
      await src.rename(destination);
      return;
    } catch (_) {
      if (await File(destination).exists()) {
        rethrow;
      }
      await src.copy(destination);
      await src.delete();
    }
  }

  static String _normalizePath(String path) {
    try {
      return File(path).resolveSymbolicLinksSync();
    } catch (_) {
      return p.normalize(path);
    }
  }
}