# VibePlay — Standard Offline Music Player

Native Android application built with Flutter/Dart UI and Kotlin Android platform integration. This is not a web app, PWA, WebView, or browser-based player.

## Features in this source
- MediaStore audio scan on-device for MP3, M4A, WAV, AAC and FLAC indexed audio.
- Runtime audio permission request, denial handling, and App Settings route for permanently denied permission.
- Song library, live search (title/artist/album), sorting (title/artist/date added), and manual rescan.
- Album artwork loaded from Android MediaStore album-art content URIs, with fallback artwork.
- Playback queue, seek, shuffle, repeat off/all/one, previous/next, play/pause.
- AudioService foreground playback notification and Android media controls.
- Mini player and full now-playing screen.
- Local Hive persistence for favourites and playlists.
- Playlist creation/deletion, add songs by long press, remove tracks from playlists.
- Sleep timer off/15/30/60 minutes.
- Dark-only Material 3 design.

## Build with a Flutter Android builder
Use Flutter stable with Android SDK 34 and Java 17. The builder must support Flutter plugins and native Android Gradle builds.

```bash
flutter pub get
flutter build apk --release
```

This archive includes the Android Gradle configuration and wrapper properties. If your build service requires the Gradle wrapper launcher scripts/JAR and they are absent from its checkout, generate the standard wrapper using the Flutter SDK (`flutter create --platforms=android --project-name=vibeplay --org=com.vibeplay .`) and then re-apply this archive's custom `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/vibeplay/vibeplay/MainActivity.kt`, and `android/app/build.gradle` before building. Do not replace those custom files with the default Flutter template.

APK output:
`build/app/outputs/flutter-apk/app-release.apk`

If using an existing generated Flutter scaffold, preserve this project's `lib/`, `pubspec.yaml`, Android manifest, Kotlin MainActivity and app Gradle configuration. The `flutter create` command generates standard wrapper files and launcher resources for the builder. Confirm that it does not overwrite the custom manifest or Kotlin source.

## Android details
- Minimum SDK 21; target SDK 34.
- Audio access: READ_MEDIA_AUDIO on Android 13+ and READ_EXTERNAL_STORAGE through Android 12.
- POST_NOTIFICATIONS is declared and requested on Android 13+.
- Foreground media playback service permissions and service declaration are included.
- MediaStore is Android's indexed shared-media API. It does not bypass scoped-storage restrictions or recursively read arbitrary private app folders.
- Music remains on-device; no accounts, streaming, Firebase, ads, network APIs, or upload.
- Hive data is local to the app sandbox.

## Release checklist before publishing
1. Build on the target builder and resolve any environment-specific Gradle/SDK mismatch.
2. Test permission grant, deny, permanently deny, and App Settings return on Android 12 and Android 13+.
3. Test playback while app is backgrounded and device is locked, notification controls, Bluetooth/headset controls, audio focus interruptions, and Android battery restrictions on multiple OEM devices.
4. Test a library containing each supported format and files with missing metadata/artwork.
5. Test playlist/favourite persistence after force-stop and reboot.
6. Sign the release APK with the intended production signing key. Do not distribute an unsigned or debug build.
