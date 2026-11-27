# VibePlay - Standard Offline Music Player

Native Android app built with **Flutter + Dart** (no WebView, no HTML, no PWA).
Plays the music already stored on your phone. No internet, no login, no ads.

## Build the APK

```bash
flutter pub get
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```

Requirements: Flutter 3.27 or newer (stable), JDK 17. For Codemagic / Replit, use a recent
stable Flutter and run the two commands above. The release APK is signed with the debug key so it
installs directly; add your own keystore in `android/app/build.gradle` for Play Store releases.

If the builder says the `android/gradle/wrapper/gradle-wrapper.jar` or `gradlew` is missing, that is
fine: `flutter build apk` creates them automatically.

## Features

| Feature | How it is done |
|---|---|
| Scan storage | Kotlin `MediaStore.Audio.Media` query in `MainActivity.kt` (mp3, m4a, wav, aac, flac). **Rescan** also asks Android's media scanner to index new files under `/storage/emulated/0` |
| Permissions | `READ_MEDIA_AUDIO` on Android 13+, `READ_EXTERNAL_STORAGE` on Android 12 and below, `POST_NOTIFICATIONS`. Denied -> dialog with **Grant Permission**; permanently denied -> **Open Settings** |
| Songs list | Artwork, title, artist, duration; live search by title/artist; sort by Title / Artist / Date added |
| Mini player | Artwork, title, artist, play/pause, next; tap to open full player |
| Full player | Seek bar (draggable), shuffle, previous, play/pause, next, repeat (Off / All / One), favourite heart |
| Favourites + playlists | Hive local database (`lib/services/storage_service.dart`). Long-press any song to favourite it or add it to a playlist |
| Background play | `just_audio_background` (MediaSession + foreground service + media notification with controls) |
| Sleep timer | Settings -> Off / 15 / 30 / 60 min (short fade-out, then pause) |
| Theme | Dark only: `#121212` background, `#1E1E1E` cards, `#1DB954` accent, Material 3 |

## Project structure

```
pubspec.yaml
lib/
  main.dart                      app entry, providers, background audio init
  theme/app_theme.dart           colors + Material 3 dark theme
  models/                        Song, Playlist
  services/
    media_store_service.dart     Flutter <-> Kotlin MediaStore bridge
    permission_service.dart      runtime permissions
    library_service.dart         scan, search, sort
    player_service.dart          just_audio player, queue, shuffle, repeat, sleep timer
    storage_service.dart         Hive: favourites + playlists
  screens/                       permission gate, home (tabs), songs, favourites, playlists,
                                 playlist detail, now playing, settings
  widgets/                       artwork, song tile, mini player, song actions, empty state
android/
  build.gradle, settings.gradle, gradle.properties
  gradle/wrapper/gradle-wrapper.properties
  app/build.gradle               minSdk 21, targetSdk 34
  app/src/main/AndroidManifest.xml
  app/src/main/kotlin/com/vibeplay/app/MainActivity.kt
  app/src/main/res/...           icons, styles, notification icon
```

## Notes

- If a builder reports that a library requires a higher `minSdk` than 21 (newer Flutter versions
  may raise their own minimum), change `minSdk = 21` to `minSdk = 24` in `android/app/build.gradle`.
- Scanning uses MediaStore directly, so it only lists files Android has indexed. Folders containing a
  `.nomedia` file are skipped, as in every other music player.
