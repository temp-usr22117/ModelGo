# ModelGo

<p align="center">
  <img src="assets/icon/modelgo.png" alt="ModelGo icon" width="180">
</p>

ModelGo is a Flutter application for downloading and running quantized GGUF language models directly on Android devices. Inference runs locally through `llama.cpp`, so prompts and generated responses do not need to be sent to a remote inference service.

## Features

- Local GGUF inference powered by [`llama.cpp`](https://github.com/ggml-org/llama.cpp)
- Support for Android 10 and newer (`minSdk 29`)
- ARM64 (`arm64-v8a`) builds for modern physical Android devices
- Curated quantized model catalogue focused on practical Q4 models
- In-app model download progress
- Android download-progress notifications
- Automatic discovery of downloaded `.gguf` files
- Chat screen for each downloaded model
- Conversation reset and model unload controls
- Launcher icons and startup branding for Android, iOS, Web, macOS, Windows, and Linux

## Current platform support

Local model inference is currently implemented for **64-bit ARM Android devices**. The project includes generated branding and Flutter platform scaffolding for other platforms, but the native inference bridge is Android-specific.

Minimum Android version: **Android 10 (API 29)**.

## How it works

```text
Flutter UI
   |
   | MethodChannel
   v
Android Kotlin bridge
   |
   | JNI
   v
native-lib.cpp
   |
   v
llama.cpp -> GGUF model
```

Flutter manages navigation, downloads, model selection, progress, and chat presentation. Kotlin moves inference work off the UI thread, while the JNI/C++ layer loads the selected GGUF file and generates responses with `llama.cpp`.

## Project structure

```text
lib/
  main.dart
  screens/
    dashboard.dart
    download_models.dart
    my_models.dart
    chat.dart
  services/
    download_service.dart
    providers/
      model_provider.dart

android/app/src/main/
  kotlin/com/example/modelgo/MainActivity.kt
  cpp/
    CMakeLists.txt
    native-lib.cpp
    llama.cpp/
```

## Model downloads

The download screen intentionally shows a small curated selection rather than every available GGUF file. The listed models use quantization levels intended to be practical on mobile hardware, starting with devices that have approximately 4 GB of RAM.

Downloaded models are stored in the application's external files directory:

```text
Android/data/com.example.modelgo/files/Documents/models/
```

Model files can be large. Ensure the device has enough free storage before starting a download.

## Getting started

### Requirements

- Flutter SDK compatible with the version declared in `pubspec.yaml`
- Android SDK
- Android NDK and CMake
- Git submodule/vendor contents for `android/app/src/main/cpp/llama.cpp`
- A 64-bit ARM Android device running Android 10 or newer

### Install dependencies

```bash
flutter pub get
```

### Run static checks

```bash
flutter analyze
flutter test
```

### Build the Android release APK

```bash
flutter build apk --release
```

The APK is written to:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Run on a connected device

Enable USB debugging, connect the device, and verify that Flutter can see it:

```bash
flutter devices
flutter run
```

Release builds provide substantially better native inference performance than debug builds.

## Performance expectations

Generation speed depends on the model, quantization, prompt length, device CPU, available RAM, thermal limits, and requested output length. The current chat bridge returns a response after native generation completes; it does not stream individual tokens to the Flutter UI yet.

Smaller Q4 models are recommended for devices with 4 GB of RAM. Larger models may load slowly, trigger memory pressure, or fail on lower-memory devices.

## Known limitations

- Android inference currently targets `arm64-v8a` only.
- Generated text is returned as one completed response rather than streamed token by token.
- Chat history exists for the active in-memory session and is not persisted as a conversation database.
- Model quality and instruction-following vary significantly between GGUF models.
- iOS and desktop inference bridges are not implemented yet.
- The release build currently uses debug signing and must use a private release keystore before store distribution.

## Branding assets

The source icon is stored at `assets/icon/modelgo.png`. Platform-specific icon packs are generated with `icons_launcher`, while Android, iOS, and Web startup screens are generated with `flutter_native_splash`.

To regenerate them:

```bash
dart run icons_launcher:create
dart run flutter_native_splash:create
```

## Privacy

Model inference runs locally. Network access is still required when downloading models, and download hosts receive the normal connection metadata associated with those requests.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
