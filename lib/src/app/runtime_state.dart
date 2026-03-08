import '../models/app_config.dart';

class RuntimeState {
  RuntimeState({
    required this.config,
    required this.configPath,
    required this.monitoringActive,
    required this.trayAvailable,
    required this.autostartActive,
    required this.statusLine,
    required this.recentEvents,
    required this.revision,
  });

  final AppConfig config;
  final String configPath;
  final bool monitoringActive;
  final bool trayAvailable;
  final bool autostartActive;
  final String statusLine;
  final List<String> recentEvents;
  final int revision;

  RuntimeState copyWith({
    AppConfig? config,
    String? configPath,
    bool? monitoringActive,
    bool? trayAvailable,
    bool? autostartActive,
    String? statusLine,
    List<String>? recentEvents,
    int? revision,
  }) {
    return RuntimeState(
      config: config ?? this.config,
      configPath: configPath ?? this.configPath,
      monitoringActive: monitoringActive ?? this.monitoringActive,
      trayAvailable: trayAvailable ?? this.trayAvailable,
      autostartActive: autostartActive ?? this.autostartActive,
      statusLine: statusLine ?? this.statusLine,
      recentEvents: recentEvents ?? this.recentEvents,
      revision: revision ?? this.revision,
    );
  }
}