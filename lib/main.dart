import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'screens/permission_gate.dart';
import 'services/library_service.dart';
import 'services/player_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sets up the MediaSession + foreground service + media notification.
  // Must run before any AudioPlayer is created.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.vibeplay.app.playback',
    androidNotificationChannelName: 'VibePlay playback',
    androidNotificationIcon: 'drawable/ic_notification',
    notificationColor: AppColors.accent,
  );

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final StorageService storage = await StorageService.create();
  runApp(VibePlayApp(storage: storage));
}

class VibePlayApp extends StatelessWidget {
  const VibePlayApp({super.key, required this.storage});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<StorageService>.value(value: storage),
        ChangeNotifierProvider<LibraryService>(create: (BuildContext _) => LibraryService()),
        ChangeNotifierProvider<PlayerService>(create: (BuildContext _) => PlayerService()),
      ],
      child: MaterialApp(
        title: 'VibePlay',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const PermissionGate(),
      ),
    );
  }
}
