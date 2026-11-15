import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'game/game.dart';
import 'game/game_store.dart';
import 'settings/app_settings.dart';
import 'sound/device_sound_files.dart';
import 'sound/sounds.dart';
import 'widgets/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The phone lies flat with panels facing each seat, so the screen must not
  // rotate, and system bars would only invite accidental swipes.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final store = await GameStore.open();
  final game = store.load();
  store.autosave(game);
  final settings = await AppSettings.open();
  // Keep the screen on while the setting says so, following any change.
  void applyKeepScreenOn() =>
      WakelockPlus.toggle(enable: settings.keepScreenOn);
  applyKeepScreenOn();
  settings.addListener(applyKeepScreenOn);
  final soundFiles = await DeviceSoundFiles.open();
  runApp(
    MyApp(
      game: game,
      settings: settings,
      sounds: AudioSoundPlayer(soundFiles),
      soundFiles: soundFiles,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.game,
    required this.settings,
    required this.sounds,
    required this.soundFiles,
  });

  final Game game;
  final AppSettings settings;
  final SoundPlayer sounds;
  final SoundFiles soundFiles;

  @override
  Widget build(BuildContext context) {
    // Above the MaterialApp, so dialogs can play sounds too.
    return SoundScope(
      settings: settings,
      player: sounds,
      files: soundFiles,
      child: _app(),
    );
  }

  Widget _app() {
    return MaterialApp(
      title: 'Command Tower',
      debugShowCheckedModeBanner: false,
      // Always dark: the table is dark, and a bright menu over it is
      // jarring, especially in a dim room.
      themeMode: ThemeMode.dark,
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
