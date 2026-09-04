import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:provider/provider.dart';

import 'services/providers/model_provider.dart';
import 'screens/dashboard.dart';

import 'services/download_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterDownloader.initialize(debug: true);

  await FlutterDownloader.registerCallback(downloadCallback, step: 1);

  final downloadService = DownloadService();
  await downloadService.initialize();

  runApp(MyApp(downloadService: downloadService));
}

class MyApp extends StatelessWidget {
  MyApp({super.key, DownloadService? downloadService})
    : _downloadService = downloadService ?? DownloadService();

  final DownloadService _downloadService;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6677FF),
      brightness: Brightness.dark,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ModelProvider>(create: (_) => ModelProvider()),
        ChangeNotifierProvider<DownloadService>.value(value: _downloadService),
      ],
      child: MaterialApp(
        title: 'ModelGo',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: colorScheme,
          scaffoldBackgroundColor: const Color(0xFF111318),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF111318),
            surfaceTintColor: Colors.transparent,
          ),
          cardColor: const Color(0xFF1A1D24),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Color(0xFF1A1D24),
            border: OutlineInputBorder(),
          ),
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}
