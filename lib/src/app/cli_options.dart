import 'dart:io';

import 'package:args/args.dart';

import '../core/path_utils.dart';

class CliOptions {
  CliOptions({
    this.configOverride,
    required this.hidden,
    required this.help,
  });

  final String? configOverride;
  final bool hidden;
  final bool help;

  static CliOptions parse(List<String> args) {
    final parser = ArgParser()
      ..addOption('config')
      ..addFlag('hidden', negatable: false)
      ..addFlag('help', abbr: 'h', negatable: false);

    final parsed = parser.parse(args);
    final configArg = parsed['config'] as String?;

    return CliOptions(
      configOverride: configArg == null ? null : AppPaths.expandHome(configArg),
      hidden: parsed['hidden'] as bool,
      help: parsed['help'] as bool,
    );
  }
}

String resolveConfigPath(CliOptions options) {
  final envPath = Platform.environment['DESKTOP_SORTER_CONFIG'];
  if (envPath != null && envPath.trim().isNotEmpty) {
    return AppPaths.resolveUserPath(envPath.trim(), Directory.current.path);
  }

  if (options.configOverride != null && options.configOverride!.trim().isNotEmpty) {
    return AppPaths.resolveUserPath(options.configOverride!, Directory.current.path);
  }

  return AppPaths.defaultConfigPath();
}