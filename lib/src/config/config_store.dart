import 'dart:io';

import 'package:toml/toml.dart';

import '../core/path_utils.dart';
import '../models/app_config.dart';

class ConfigStore {
  static Future<AppConfig> loadFromPath(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return AppConfig.defaults();
    }

    final text = await file.readAsString();
    final parsed = TomlDocument.parse(text).toMap();
    return AppConfig.fromTomlMap(parsed.cast<String, dynamic>());
  }

  static Future<void> saveToPath(AppConfig config, String path) async {
    await AppPaths.ensureParentDir(path);
    final buffer = StringBuffer();
    buffer.writeln('desktop_path = ${_quote(config.desktopPath)}');
    buffer.writeln('monitoring_enabled = ${config.monitoringEnabled}');
    buffer.writeln('autostart_enabled = ${config.autostartEnabled}');
    buffer.writeln('min_file_age_seconds = ${config.minFileAgeSeconds}');
    buffer.writeln('pause_when_fullscreen = ${config.pauseWhenFullscreen}');
    buffer.writeln();

    for (final rule in config.rules) {
      buffer.writeln('[[rules]]');
      buffer.writeln('name = ${_quote(rule.name)}');
      buffer.writeln('enabled = ${rule.enabled}');
      buffer.writeln('extensions = ${_array(rule.extensions)}');
      buffer.writeln('file_name_patterns = ${_array(rule.fileNamePatterns)}');
      buffer.writeln('exclude_patterns = ${_array(rule.excludePatterns)}');
      buffer.writeln('mode = ${_quote(rule.mode.tomlValue)}');
      buffer.writeln('target_folder = ${_quote(rule.targetFolder)}');
      buffer.writeln('target_pattern = ${_quote(rule.targetPattern)}');
      buffer.writeln('stop_after_match = ${rule.stopAfterMatch}');
      buffer.writeln();
    }

    await File(path).writeAsString(buffer.toString());
  }

  static String _array(List<String> values) {
    return '[${values.map(_quote).join(', ')}]';
  }

  static String _quote(String value) {
    final escaped = value
        .replaceAll('\\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
    return '"$escaped"';
  }
}