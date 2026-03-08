import 'dart:io';

import 'package:path/path.dart' as p;

class AppPaths {
  static String homeDir() {
    final env = Platform.environment;
    final home = env['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      return home;
    }
    final userProfile = env['USERPROFILE'];
    if (userProfile != null && userProfile.trim().isNotEmpty) {
      return userProfile;
    }
    return Directory.current.path;
  }

  static String defaultDesktopPath() {
    return p.join(homeDir(), 'Desktop');
  }

  static String defaultConfigPath() {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.trim().isNotEmpty) {
        return p.join(appData, 'an-dr', 'DesktopSorter', 'config.toml');
      }
      return p.join(
        homeDir(),
        'AppData',
        'Roaming',
        'an-dr',
        'DesktopSorter',
        'config.toml',
      );
    }

    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.trim().isNotEmpty) {
      return p.join(xdg, 'desktop_sorter', 'config.toml');
    }
    return p.join(homeDir(), '.config', 'desktop_sorter', 'config.toml');
  }

  static String expandHome(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed == '~') {
      return homeDir();
    }
    if (trimmed.startsWith('~/') || trimmed.startsWith('~\\')) {
      return p.join(homeDir(), trimmed.substring(2));
    }
    return trimmed;
  }

  static String resolveUserPath(String rawPath, String baseDir) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      return p.normalize(baseDir);
    }

    final expanded = expandHome(trimmed);
    if (p.isAbsolute(expanded)) {
      return p.normalize(expanded);
    }
    return p.normalize(p.join(baseDir, expanded));
  }

  static Future<void> ensureParentDir(String filePath) async {
    final parent = Directory(p.dirname(filePath));
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
  }
}