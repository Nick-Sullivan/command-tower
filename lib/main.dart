import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'game/game.dart';
import 'game/game_store.dart';
import 'settings/app_settings.dart';
import 'widgets/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The phone lies flat with panels facing each seat, so the screen must not
  // rotate, and system bars would only invite accidental swipes.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await WakelockPlus.enable();
  final store = await GameStore.open();
  final game = store.load();
  store.autosave(game);
  final settings = await AppSettings.open();
  runApp(MyApp(game: game, settings: settings));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.game, required this.settings});

  final Game game;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Command Tower',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        body: GameScreen(game: game, settings: settings),
      ),
    );
  }
}
