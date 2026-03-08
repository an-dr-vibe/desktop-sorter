import '../models/app_config.dart';

class EditableConfig {
  EditableConfig({
    required this.desktopPath,
    required this.monitoringEnabled,
    required this.autostartEnabled,
    required this.pauseWhenFullscreen,
    required this.minFileAgeSeconds,
    required this.rules,
  });

  String desktopPath;
  bool monitoringEnabled;
  bool autostartEnabled;
  bool pauseWhenFullscreen;
  int minFileAgeSeconds;
  List<EditableRule> rules;

  factory EditableConfig.fromConfig(AppConfig config) {
    return EditableConfig(
      desktopPath: config.desktopPath,
      monitoringEnabled: config.monitoringEnabled,
      autostartEnabled: config.autostartEnabled,
      pauseWhenFullscreen: config.pauseWhenFullscreen,
      minFileAgeSeconds: config.minFileAgeSeconds,
      rules: config.rules.map(EditableRule.fromRule).toList(growable: true),
    );
  }

  AppConfig toConfig() {
    return AppConfig(
      desktopPath: desktopPath,
      monitoringEnabled: monitoringEnabled,
      autostartEnabled: autostartEnabled,
      pauseWhenFullscreen: pauseWhenFullscreen,
      minFileAgeSeconds: minFileAgeSeconds,
      rules: rules.map((rule) => rule.toRule()).toList(growable: false),
    ).normalized();
  }
}

class EditableRule {
  EditableRule({
    required this.name,
    required this.enabled,
    required this.extensionsCsv,
    required this.fileNamePatternsCsv,
    required this.excludePatternsCsv,
    required this.mode,
    required this.targetFolder,
    required this.targetPattern,
    required this.stopAfterMatch,
  });

  String name;
  bool enabled;
  String extensionsCsv;
  String fileNamePatternsCsv;
  String excludePatternsCsv;
  SortMode mode;
  String targetFolder;
  String targetPattern;
  bool stopAfterMatch;

  factory EditableRule.defaults() {
    return EditableRule(
      name: '',
      enabled: true,
      extensionsCsv: '',
      fileNamePatternsCsv: '',
      excludePatternsCsv: '',
      mode: SortMode.move,
      targetFolder: '',
      targetPattern: '{yyyy}/{MM}/{name}.{ext}',
      stopAfterMatch: true,
    );
  }

  factory EditableRule.fromRule(SortRule rule) {
    return EditableRule(
      name: rule.name,
      enabled: rule.enabled,
      extensionsCsv: rule.extensionsCsv,
      fileNamePatternsCsv: rule.fileNamePatternsCsv,
      excludePatternsCsv: rule.excludePatternsCsv,
      mode: rule.mode,
      targetFolder: rule.targetFolder,
      targetPattern: rule.targetPattern,
      stopAfterMatch: rule.stopAfterMatch,
    );
  }

  SortRule toRule() {
    return SortRule(
      name: name,
      enabled: enabled,
      extensions: SortRule.fromCsv(extensionsCsv, normalizeExtension: true),
      fileNamePatterns: SortRule.fromCsv(fileNamePatternsCsv, normalizeExtension: false),
      excludePatterns: SortRule.fromCsv(excludePatternsCsv, normalizeExtension: false),
      mode: mode,
      targetFolder: targetFolder,
      targetPattern: targetPattern,
      stopAfterMatch: stopAfterMatch,
    ).normalized();
  }
}