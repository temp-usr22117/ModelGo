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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ModelProvider>(create: (_) => ModelProvider()),
        ChangeNotifierProvider<DownloadService>.value(value: _downloadService),
      ],
      child: MaterialApp(
        title: 'ModelGo',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const DashboardScreen(),
      ),
    );
  }
}
