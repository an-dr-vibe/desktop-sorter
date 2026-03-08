import 'dart:io';

import 'package:path/path.dart' as p;

import 'path_utils.dart';

class AutostartService {
  static String startupFilePath() {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.trim().isNotEmpty) {
        return p.join(
          appData,
          'Microsoft',
          'Windows',
          'Start Menu',
          'Programs',
          'Startup',
          'Desktop Sorter.cmd',
        );
      }

      return p.join(
        AppPaths.homeDir(),
        'AppData',
        'Roaming',
        'Microsoft',
        'Windows',
        'Start Menu',
        'Programs',
        'Startup',
        'Desktop Sorter.cmd',
      );
    }

    final xdgConfig = Platform.environment['XDG_CONFIG_HOME'];
    final base = (xdgConfig != null && xdgConfig.trim().isNotEmpty)
        ? xdgConfig
        : p.join(AppPaths.homeDir(), '.config');
    return p.join(base, 'autostart', 'desktop-sorter.desktop');
  }

  static Future<bool> isEnabled() async {
    return File(startupFilePath()).exists();
  }

  static Future<void> setEnabled({
    required bool enabled,
    required String configPath,
  }) async {
    final startupPath = startupFilePath();
    final startupFile = File(startupPath);

    if (!enabled) {
      if (await startupFile.exists()) {
        await startupFile.delete();
      }
      return;
    }

    await AppPaths.ensureParentDir(startupPath);

    if (Platform.isWindows) {
      final exe = Platform.resolvedExecutable;
      final args = ['--config', configPath, '--hidden'];
      final command = _quoteWindowsCommand(exe, args);
      final content = '@echo off\r\nstart "" /min $command\r\n';
      await startupFile.writeAsString(content);
      return;
    }

    final exe = Platform.resolvedExecutable;
    final command = _quotePosixCommand(exe, ['--config', configPath, '--hidden']);
    final content = '[Desktop Entry]\n'
        'Type=Application\n'
        'Version=1.0\n'
        'Name=Desktop Sorter\n'
        'Comment=Sort desktop files automatically\n'
        'Exec=$command\n'
        'Terminal=false\n'
        'X-GNOME-Autostart-enabled=true\n';
    await startupFile.writeAsString(content);
  }

  static String _quoteWindowsCommand(String exe, List<String> args) {
    final parts = <String>[exe, ...args];
    return parts.map((part) {
      if (part.contains(' ') || part.contains('\t')) {
        return '"${part.replaceAll('"', r'\"')}"';
      }
      return part;
    }).join(' ');
  }

  static String _quotePosixCommand(String exe, List<String> args) {
    final parts = <String>[exe, ...args];
    return parts.map(_shellQuote).join(' ');
  }

  static String _shellQuote(String value) {
    final safe = RegExp(r'^[a-zA-Z0-9/._-]+$');
    if (safe.hasMatch(value)) {
      return value;
    }
    return "'${value.replaceAll("'", "'\"'\"'")}'";
  }
}