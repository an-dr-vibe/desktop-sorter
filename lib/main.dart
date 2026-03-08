import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app/app_controller.dart';
import 'src/app/cli_options.dart';
import 'src/ui/home_page.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final options = CliOptions.parse(args);
  if (options.help) {
    _printHelp();
    return;
  }

  final configPath = resolveConfigPath(options);

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    title: 'Desktop Sorter',
    size: Size(980, 760),
    minimumSize: Size(760, 560),
    center: true,
    backgroundColor: Colors.transparent,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (!options.hidden) {
      await windowManager.show();
      await windowManager.focus();
    }
  });

  final controller = AppController(
    configPath: configPath,
    startHidden: options.hidden,
  );

  await controller.initialize();

  runApp(DesktopSorterApp(controller: controller));
}

class DesktopSorterApp extends StatefulWidget {
  const DesktopSorterApp({
    super.key,
    required this.controller,
  });

  final AppController controller;

  @override
  State<DesktopSorterApp> createState() => _DesktopSorterAppState();
}

class _DesktopSorterAppState extends State<DesktopSorterApp> {
  @override
  void dispose() {
    widget.controller.disposeServices();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Desktop Sorter',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF41A6FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121417),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: HomePage(controller: widget.controller),
    );
  }
}

void _printHelp() {
  const message = 'Desktop Sorter (Flutter)\n\n'
      'Usage:\n'
      '  desktop_sorter [--config <path>] [--hidden] [--help]\n\n'
      'Options:\n'
      '  --config <path>   Use a config file outside the default location\n'
      '  --hidden          Start hidden and rely on the tray icon\n'
      '  --help            Show this help\n\n'
      'Environment:\n'
      '  DESKTOP_SORTER_CONFIG   Override the config path\n';

  // ignore: avoid_print
  print(message);
}