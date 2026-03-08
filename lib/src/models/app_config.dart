import 'package:path/path.dart' as p;

import '../core/path_utils.dart';

enum SortMode { move, pattern, trash, keep }

extension SortModeX on SortMode {
  String get label {
    switch (this) {
      case SortMode.move:
        return 'Move as-is';
      case SortMode.pattern:
        return 'Pattern';
      case SortMode.trash:
        return 'Move to trash';
      case SortMode.keep:
        return 'Keep on desktop';
    }
  }

  bool get needsTarget => this == SortMode.move || this == SortMode.pattern;

  bool get needsPattern => this == SortMode.pattern;

  String get tomlValue {
    switch (this) {
      case SortMode.move:
        return 'move';
      case SortMode.pattern:
        return 'pattern';
      case SortMode.trash:
        return 'trash';
      case SortMode.keep:
        return 'keep';
    }
  }

  static SortMode fromToml(dynamic value) {
    final raw = (value ?? '').toString().toLowerCase().trim();
    switch (raw) {
      case 'pattern':
        return SortMode.pattern;
      case 'trash':
        return SortMode.trash;
      case 'keep':
        return SortMode.keep;
      case 'move':
      default:
        return SortMode.move;
    }
  }
}

class AppConfig {
  AppConfig({
    required this.desktopPath,
    required this.monitoringEnabled,
    required this.autostartEnabled,
    required this.minFileAgeSeconds,
    required this.pauseWhenFullscreen,
    required this.rules,
  });

  final String desktopPath;
  final bool monitoringEnabled;
  final bool autostartEnabled;
  final int minFileAgeSeconds;
  final bool pauseWhenFullscreen;
  final List<SortRule> rules;

  factory AppConfig.defaults() {
    return AppConfig(
      desktopPath: AppPaths.defaultDesktopPath(),
      monitoringEnabled: true,
      autostartEnabled: false,
      minFileAgeSeconds: 20,
      pauseWhenFullscreen: false,
      rules: const [],
    );
  }

  AppConfig normalized() {
    final currentDir = p.normalize(p.absolute('.'));
    final normalizedPath = desktopPath.trim().isEmpty
        ? AppPaths.defaultDesktopPath()
        : AppPaths.resolveUserPath(desktopPath, currentDir);

    final normalizedRules = rules
        .map((rule) => rule.normalized())
        .where((rule) => rule.isUsable)
        .toList(growable: false);

    final clampedAge = minFileAgeSeconds.clamp(0, 86400);

    return copyWith(
      desktopPath: normalizedPath,
      minFileAgeSeconds: clampedAge,
      rules: normalizedRules,
    );
  }

  AppConfig copyWith({
    String? desktopPath,
    bool? monitoringEnabled,
    bool? autostartEnabled,
    int? minFileAgeSeconds,
    bool? pauseWhenFullscreen,
    List<SortRule>? rules,
  }) {
    return AppConfig(
      desktopPath: desktopPath ?? this.desktopPath,
      monitoringEnabled: monitoringEnabled ?? this.monitoringEnabled,
      autostartEnabled: autostartEnabled ?? this.autostartEnabled,
      minFileAgeSeconds: minFileAgeSeconds ?? this.minFileAgeSeconds,
      pauseWhenFullscreen: pauseWhenFullscreen ?? this.pauseWhenFullscreen,
      rules: rules ?? this.rules,
    );
  }

  factory AppConfig.fromTomlMap(Map<String, dynamic> map) {
    final rawRules = map['rules'];
    final parsedRules = <SortRule>[];
    if (rawRules is List) {
      for (final item in rawRules) {
        if (item is Map) {
          parsedRules.add(SortRule.fromTomlMap(item.cast<String, dynamic>()));
        }
      }
    }

    return AppConfig(
      desktopPath: (map['desktop_path'] ?? AppPaths.defaultDesktopPath()).toString(),
      monitoringEnabled: _asBool(map['monitoring_enabled'], true),
      autostartEnabled: _asBool(map['autostart_enabled'], false),
      minFileAgeSeconds: _asInt(map['min_file_age_seconds'], 20),
      pauseWhenFullscreen: _asBool(map['pause_when_fullscreen'], false),
      rules: parsedRules,
    ).normalized();
  }
}

class SortRule {
  const SortRule({
    required this.name,
    required this.enabled,
    required this.extensions,
    required this.fileNamePatterns,
    required this.excludePatterns,
    required this.mode,
    required this.targetFolder,
    required this.targetPattern,
    required this.stopAfterMatch,
  });

  final String name;
  final bool enabled;
  final List<String> extensions;
  final List<String> fileNamePatterns;
  final List<String> excludePatterns;
  final SortMode mode;
  final String targetFolder;
  final String targetPattern;
  final bool stopAfterMatch;

  factory SortRule.defaults() {
    return const SortRule(
      name: '',
      enabled: true,
      extensions: [],
      fileNamePatterns: [],
      excludePatterns: [],
      mode: SortMode.move,
      targetFolder: '',
      targetPattern: '{yyyy}/{MM}/{name}.{ext}',
      stopAfterMatch: true,
    );
  }

  factory SortRule.fromTomlMap(Map<String, dynamic> map) {
    List<String> readList(String key) {
      final v = map[key];
      if (v is List) {
        return v.map((e) => e.toString()).toList(growable: false);
      }
      return const [];
    }

    return SortRule(
      name: (map['name'] ?? '').toString(),
      enabled: _asBool(map['enabled'], true),
      extensions: readList('extensions'),
      fileNamePatterns: readList('file_name_patterns'),
      excludePatterns: readList('exclude_patterns'),
      mode: SortModeX.fromToml(map['mode']),
      targetFolder: (map['target_folder'] ?? '').toString(),
      targetPattern: (map['target_pattern'] ?? '{yyyy}/{MM}/{name}.{ext}').toString(),
      stopAfterMatch: _asBool(map['stop_after_match'], true),
    ).normalized();
  }

  SortRule copyWith({
    String? name,
    bool? enabled,
    List<String>? extensions,
    List<String>? fileNamePatterns,
    List<String>? excludePatterns,
    SortMode? mode,
    String? targetFolder,
    String? targetPattern,
    bool? stopAfterMatch,
  }) {
    return SortRule(
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      extensions: extensions ?? this.extensions,
      fileNamePatterns: fileNamePatterns ?? this.fileNamePatterns,
      excludePatterns: excludePatterns ?? this.excludePatterns,
      mode: mode ?? this.mode,
      targetFolder: targetFolder ?? this.targetFolder,
      targetPattern: targetPattern ?? this.targetPattern,
      stopAfterMatch: stopAfterMatch ?? this.stopAfterMatch,
    );
  }

  SortRule normalized() {
    final normalizedPattern = targetPattern.trim().isEmpty
        ? '{yyyy}/{MM}/{name}.{ext}'
        : targetPattern.trim();

    return copyWith(
      name: name.trim(),
      targetFolder: targetFolder.trim(),
      targetPattern: normalizedPattern,
      extensions: _normalizeList(extensions, normalizeExtension: true),
      fileNamePatterns: _normalizeList(fileNamePatterns, normalizeExtension: false),
      excludePatterns: _normalizeList(excludePatterns, normalizeExtension: false),
    );
  }

  bool get isUsable {
    return name.trim().isNotEmpty &&
        (extensions.isNotEmpty || fileNamePatterns.isNotEmpty) &&
        (!mode.needsTarget || targetFolder.trim().isNotEmpty);
  }

  bool matchesFile(String fileName, String? ext) {
    if (!enabled) {
      return false;
    }

    if (extensions.isNotEmpty) {
      if (ext == null) {
        return false;
      }
      if (!extensions.contains(ext)) {
        return false;
      }
    }

    if (fileNamePatterns.isNotEmpty &&
        !fileNamePatterns.any((pattern) => wildcardMatches(pattern, fileName))) {
      return false;
    }

    if (excludePatterns.any((pattern) => wildcardMatches(pattern, fileName))) {
      return false;
    }

    return true;
  }

  String get extensionsCsv => extensions.join(', ');
  String get fileNamePatternsCsv => fileNamePatterns.join(', ');
  String get excludePatternsCsv => excludePatterns.join(', ');

  static List<String> fromCsv(String csv, {required bool normalizeExtension}) {
    return _normalizeList(csv.split(',').toList(), normalizeExtension: normalizeExtension);
  }

  static bool wildcardMatches(String pattern, String candidate) {
    final pChars = pattern.toLowerCase().split('');
    final sChars = candidate.toLowerCase().split('');

    var pi = 0;
    var si = 0;
    int? starPi;
    var starSi = 0;

    while (si < sChars.length) {
      if (pi < pChars.length && (pChars[pi] == '?' || pChars[pi] == sChars[si])) {
        pi++;
        si++;
      } else if (pi < pChars.length && pChars[pi] == '*') {
        starPi = pi;
        pi++;
        starSi = si;
      } else if (starPi != null) {
        pi = starPi + 1;
        starSi++;
        si = starSi;
      } else {
        return false;
      }
    }

    while (pi < pChars.length && pChars[pi] == '*') {
      pi++;
    }

    return pi == pChars.length;
  }
}

List<String> _normalizeList(
  List<String> values, {
  required bool normalizeExtension,
}) {
  final result = <String>[];
  for (final raw in values) {
    var value = raw.trim();
    if (normalizeExtension) {
      value = value.replaceFirst(RegExp(r'^\.+'), '').toLowerCase();
    }
    if (value.isEmpty || result.contains(value)) {
      continue;
    }
    result.add(value);
  }
  return result;
}

bool _asBool(dynamic raw, bool fallback) {
  if (raw is bool) {
    return raw;
  }
  if (raw is num) {
    return raw != 0;
  }
  if (raw is String) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return fallback;
}

int _asInt(dynamic raw, int fallback) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  if (raw is String) {
    return int.tryParse(raw.trim()) ?? fallback;
  }
  return fallback;
}