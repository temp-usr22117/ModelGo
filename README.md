# ModelGo

ModelGo is a Flutter-based Android application for working with local GGUF language models on a mobile device.

The project combines a Flutter UI and application layer with a native C/C++ inference layer built around [`llama.cpp`](https://github.com/ggml-org/llama.cpp). The intended architecture is to let the Flutter side handle the user interface, model management, and application state while native code handles the computationally intensive LLM work.

> **Project status:** ModelGo is an active development project. Some parts of the application are still skeletal or experimental. In particular, the current model-download service contains a simulated download implementation, and the chat UI currently uses placeholder message data rather than a persistent chat-history implementation.

---

## Contents

- [What is ModelGo?](#what-is-modelgo)
- [How it works](#how-it-works)
- [Architecture](#architecture)
- [Project structure](#project-structure)
- [Technology stack](#technology-stack)
- [Model format and storage](#model-format-and-storage)
- [Native inference layer](#native-inference-layer)
- [Flutter application layer](#flutter-application-layer)
- [State management](#state-management)
- [Model management](#model-management)
- [Chat and inference flow](#chat-and-inference-flow)
- [Android build configuration](#android-build-configuration)
- [Getting started](#getting-started)
- [Development workflow](#development-workflow)
- [Building the Android application](#building-the-android-application)
- [Important implementation notes](#important-implementation-notes)
- [Current limitations](#current-limitations)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## What is ModelGo?

ModelGo is intended to be a **local LLM client for Android**.

Instead of relying on a remote inference API, the project embeds `llama.cpp` into the Android application. Models are represented as GGUF files and are intended to be stored locally on the device.

The application has three major responsibilities:

1. **Flutter UI**
   - Screens and navigation
   - User input
   - Model listing
   - Application state
   - Error/loading states

2. **Model management**
   - Locate the application's model directory
   - Discover downloaded `.gguf` files
   - Expose available models to the UI
   - Track model-related state

3. **Native inference**
   - Build `llama.cpp` as part of the Android application
   - Link the application's native library against the `llama` library
   - Provide a Flutter-to-native bridge for inference

The Android native build is configured through CMake. The application's CMake project adds the vendored `llama.cpp` source tree and builds a `native-lib` shared library linked against `llama`.

---

## How it works

At a high level:

```text
                         ModelGo
                            │
             ┌──────────────┴──────────────┐
             │                             │
       Flutter/Dart                    Android Native
             │                             │
     ┌───────┴────────┐             ┌──────┴─────────┐
     │                │             │                │
   Screens        Providers      native-lib       llama.cpp
     │                │             │                │
     │          Model state        C/C++          GGML/GGUF
     │                │             │                │
     └───────────────┬┘             └───────┬────────┘
                     │                      │
                     └──── MethodChannel ───┘
                            inference
```

A typical inference request is designed to follow this path:

```text
User enters prompt
        │
        ▼
Flutter ChatScreen
        │
        ▼
MethodChannel
"com.example.llmclient/native"
        │
        ▼
Native Android/C++ layer
        │
        ▼
llama.cpp
        │
        ▼
GGUF model
        │
        ▼
Generated response
        │
        ▼
Native → Flutter
```

The current chat screen already contains the Flutter side of this bridge: it sends the prompt through a `MethodChannel` using the method name `infer`.

---

# Architecture

## 1. Flutter layer

The Flutter layer is responsible for the application-facing functionality.

Important components include:

- `main.dart`
- screens
- model provider
- model storage service
- download service

The application uses Flutter's `Material` widgets and the `provider` package for state management.

The root application creates a `ModelProvider` using `ChangeNotifierProvider` and starts the application at the dashboard/home screen.

---

## 2. Android layer

The Android application is located under:

```text
android/
```

The application module is:

```text
android/app/
```

The Android module uses:

- Android Gradle Plugin
- Kotlin DSL Gradle configuration
- Java 17 compatibility
- Kotlin JVM target 17
- Flutter's Gradle plugin
- CMake external native build

The application module points CMake at:

```text
android/app/src/main/cpp/CMakeLists.txt
```

---

## 3. Native C/C++ layer

The native code lives under:

```text
android/app/src/main/cpp/
```

The project's native CMake file:

```text
android/app/src/main/cpp/CMakeLists.txt
```

does the following:

- Creates the `modelgo_native` CMake project.
- Disables llama.cpp components that are not required by the application.
- Adds the vendored `llama.cpp` source tree.
- Builds `native-lib` as a shared library.
- Adds llama.cpp headers to the native target.
- Links `native-lib` against `llama` and Android's `log` library.

The relevant CMake targets are therefore conceptually:

```text
native-lib
    │
    └── llama
          │
          └── ggml / ggml-cpu / related llama.cpp components
```

---

# Project structure

A simplified view of the project is:

```text
modelgo/
│
├── android/
│   ├── app/
│   │   ├── build.gradle.kts
│   │   │
│   │   └── src/
│   │       └── main/
│   │           └── cpp/
│   │               ├── CMakeLists.txt
│   │               ├── native-lib.cpp
│   │               │
│   │               └── llama.cpp/
│   │                   ├── include/
│   │                   ├── src/
│   │                   ├── ggml/
│   │                   ├── common/
│   │                   ├── examples/
│   │                   ├── tools/
│   │                   ├── tests/
│   │                   └── vendor/
│   │
│   └── ... Android project files
│
├── lib/
│   ├── main.dart
│   │
│   ├── screens/
│   │   ├── dashboard.dart
│   │   ├── chat.dart
│   │   └── my_models.dart
│   │
│   └── services/
│       ├── download_service.dart
│       ├── model_storage_service.dart
│       └── providers/
│           └── model_provider.dart
│
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

The exact contents of `lib/` may evolve as development continues. The structure above describes the application components currently represented in the project sources.

---

# Technology stack

## Frontend / application

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform UI/application framework |
| Dart | Application programming language |
| Material Design | Flutter UI components |
| Provider | Application state management |
| `flutter_downloader` | Download-related dependency |
| `cupertino_icons` | Cupertino icon set |
| `path_provider` | Device filesystem/storage location access |

The project currently targets Dart SDK `^3.12.2`.

---

## Android / native

| Technology | Purpose |
|---|---|
| Android | Mobile platform |
| Gradle | Android build system |
| Kotlin DSL | Gradle configuration |
| Java 17 | Android compile/runtime language compatibility |
| Kotlin JVM 17 | Kotlin compiler target |
| CMake | Native build configuration |
| Ninja | Native build execution |
| Android NDK | Native Android toolchain |
| C/C++ | Native inference integration |

---

## LLM / inference

| Component | Purpose |
|---|---|
| `llama.cpp` | Local LLM inference engine |
| GGUF | Model file format used by the application |
| GGML/ggml-cpu | Low-level tensor/CPU components used by llama.cpp |

The repository contains a vendored copy of `llama.cpp` under:

```text
android/app/src/main/cpp/llama.cpp/
```

---

# Model format and storage

ModelGo works with **GGUF model files**.

The model storage service creates/uses a directory named:

```text
models
```

inside the application's external documents storage location.

Conceptually:

```text
<app-specific external documents directory>/
└── models/
    ├── model-a.gguf
    ├── model-b.gguf
    └── model-c.gguf
```

The storage service:

1. Locates the application's external documents directory.
2. Creates the `models` directory if it does not exist.
3. Lists files in that directory.
4. Filters the results to `.gguf` files.
5. Returns those files to the application.

This means the application does not treat every file in the directory as a model; the current discovery logic specifically looks for files whose names end in `.gguf`.

---

# Native inference layer

The native build is deliberately configured to avoid building unnecessary llama.cpp components.

The application's CMake configuration disables:

```text
LLAMA_BUILD_COMMON
LLAMA_BUILD_TESTS
LLAMA_BUILD_TOOLS
LLAMA_BUILD_EXAMPLES
LLAMA_BUILD_SERVER
LLAMA_BUILD_APP
LLAMA_BUILD_UI
LLAMA_BUILD_MTMD
```

and also disables:

```text
GGML_OPENMP
GGML_NATIVE
```

The main llama.cpp source tree is then included with:

```cmake
add_subdirectory(llama.cpp)
```

The application also creates:

```cmake
add_library(native-lib SHARED native-lib.cpp)
```

and links it against:

```text
llama
log
```

This keeps the Android application's native layer focused on the functionality it needs rather than building the complete llama.cpp collection of examples, tools, tests, and optional components.

---

# Flutter application layer

## Application entry point

The application starts from:

```text
lib/main.dart
```

The root widget creates a `ModelProvider` and provides it to the widget tree through:

```text
ChangeNotifierProvider<ModelProvider>
```

The application then creates a `MaterialApp` and opens the main dashboard/home screen.

---

## Screens

### Dashboard

The dashboard is the main application entry point.

It provides the high-level UI from which the user can access the application's functionality.

### Chat

The chat screen provides the initial UI for sending prompts to the native inference layer.

The current implementation:

- Uses a `TextEditingController`.
- Reads the user's prompt.
- Sends it through a Flutter `MethodChannel`.
- Calls the native method named `infer`.
- Receives a string response.
- Logs the user prompt and assistant response.

The channel currently used by the Flutter code is:

```text
com.example.llmclient/native
```

and the method is:

```text
infer
```

The request payload currently has the form:

```text
{
    "prompt": "<user prompt>"
}
```

### My Models

The My Models screen reads available GGUF files through `ModelStorageService`.

It handles:

- Loading state
- Error state
- Empty model directory
- Refreshing the model list
- Displaying model filenames

Another version of the screen also displays the model's approximate file size in MB.

---

# State management

Model-related application state is handled through `ModelProvider`.

The provider follows Flutter's `ChangeNotifier` pattern.

The application creates it near the root of the widget tree:

```text
ChangeNotifierProvider<ModelProvider>
```

This allows screens and services to react to model-state changes without requiring all state to be passed manually through widget constructors.

The download service also accepts a `ModelProvider` and notifies it when its download workflow reports completion.

---

# Model management

Model management is split into two concepts.

## Storage

`ModelStorageService` is responsible for filesystem operations.

Its responsibilities include:

```text
getModelsDirectory()
getDownloadedModels()
getModelPath()
```

The service filters discovered files to `.gguf`.

## Download state

`DownloadService` is intended to manage model downloads and notify `ModelProvider` when a download completes.

However, the current implementation contains:

```dart
_simulateDownload(...)
```

which waits for five seconds instead of downloading the supplied URL.

Therefore, **the current `DownloadService` should be regarded as a placeholder/prototype rather than a production download implementation**.

A production implementation will need to:

1. Perform the actual HTTP download.
2. Save the file to the models directory.
3. Report progress.
4. Handle cancellation.
5. Handle network failures.
6. Verify the resulting file.
7. Notify the model provider after successful completion.

---

# Chat and inference flow

The intended inference flow is:

```text
                  Flutter
                    │
                    │ prompt
                    ▼
              ChatScreen
                    │
                    │ MethodChannel
                    │ "infer"
                    ▼
             Native Android
                    │
                    │ C/C++
                    ▼
                llama.cpp
                    │
                    ▼
                GGUF model
                    │
                    ▼
             generated text
                    │
                    ▼
              Native Android
                    │
                    │ String response
                    ▼
              ChatScreen
```

The current Flutter chat implementation establishes the first half of this architecture.

The UI currently does not implement a complete persistent conversation model. The source explicitly indicates that chat history is planned for later implementation.

---

# Android build configuration

The Android application module is configured in:

```text
android/app/build.gradle.kts
```

Important settings include:

```text
namespace       = com.example.modelgo
applicationId   = com.example.modelgo
compileSdk      = Flutter-provided compile SDK
minSdk          = Flutter-provided minimum SDK
targetSdk       = Flutter-provided target SDK
```

Java compatibility is set to:

```text
Java 17
```

and Kotlin targets:

```text
JVM 17
```

The Android application also uses CMake:

```text
android/app/src/main/cpp/CMakeLists.txt
```

for the native build.

The current application Gradle configuration explicitly declares:

```text
arm64-v8a
```

as its ABI filter.

---

# Getting started

## Prerequisites

You will need an Android/Flutter development environment capable of building the project.

At minimum, the project expects:

- Flutter
- Dart SDK compatible with the project's `pubspec.yaml`
- Android SDK
- Android NDK
- CMake
- Ninja
- Java 17-compatible Android build environment

Because the application contains a native `llama.cpp` integration, the Android NDK/CMake portion of the environment is especially important.

---

## Clone the project

```bash
git clone <repository-url>
cd modelgo
```

Replace `<repository-url>` with the repository's actual Git URL.

---

## Install Flutter dependencies

Run:

```bash
flutter pub get
```

---

## Check the environment

Run:

```bash
flutter doctor -v
```

Resolve any Android SDK, NDK, Java, or Flutter configuration problems reported by the command.

---

## Connect an Android device

Enable USB debugging on a development device and verify that Flutter can see it:

```bash
flutter devices
```

Then:

```bash
flutter run
```

---

# Building the Android application

For a debug build:

```bash
flutter build apk --debug
```

For a release build:

```bash
flutter build apk --release
```

The exact ABI/build behavior depends on the Flutter and Android Gradle configuration currently used by the project.

Because the project includes native C++ code, a failed build may originate from:

- Gradle
- CMake
- Ninja
- Android NDK
- llama.cpp
- GGML
- ABI-specific native compilation

When diagnosing a native build problem, inspect the first C/C++ compiler error rather than only the final Gradle exception.

---

# Development workflow

A useful development loop is:

```text
1. Modify Flutter/native source
          │
          ▼
2. Run static analysis / formatting
          │
          ▼
3. Build or run on Android
          │
          ▼
4. Test model discovery
          │
          ▼
5. Test native inference
          │
          ▼
6. Inspect Android/CMake logs when native code changes
```

For Flutter-side changes:

```bash
flutter analyze
```

For dependency changes:

```bash
flutter pub get
```

For a clean Flutter build:

```bash
flutter clean
flutter pub get
flutter run
```

When changing native CMake/C++ code, a clean rebuild is often useful because CMake maintains generated build state.

---

# Important implementation notes

## llama.cpp is vendored into the application

The project contains llama.cpp directly under:

```text
android/app/src/main/cpp/llama.cpp/
```

This is important when updating llama.cpp.

Changes to the vendored llama.cpp tree can affect:

- CMake configuration
- Android ABI builds
- GGML CPU code
- compiler compatibility
- native memory usage
- model compatibility
- inference performance

Do not assume that every `x86_64`, `arm`, or other architecture reference inside the llama.cpp directory is an application ABI configuration. llama.cpp itself is a multi-platform project and contains platform-specific source, tests, documentation, CI configuration, and build scripts.

---

## The nested llama.android example is separate

There is also a llama.cpp example project under:

```text
android/app/src/main/cpp/llama.cpp/examples/llama.android/
```

Its Gradle configuration is not the same thing as:

```text
android/app/build.gradle.kts
```

The application's native integration is driven by:

```text
android/app/src/main/cpp/CMakeLists.txt
```

and the Android application's Gradle module:

```text
android/app/build.gradle.kts
```

---

# Current limitations

The following areas should currently be considered incomplete or under development.

## 1. Model downloading

The current `DownloadService` simulates a five-second download rather than performing an actual network download.

## 2. Chat history

The chat screen contains placeholder message data and does not yet maintain a real conversation history.

## 3. Model selection

The current model-list UI discovers GGUF files, but the complete workflow for selecting a model and binding that model to a native inference session is not represented in the current Flutter code available to this README.

## 4. Inference configuration

A production LLM client will eventually need configurable inference parameters such as:

- context size
- temperature
- top-k
- top-p
- repetition controls
- number of threads
- GPU/backend configuration where supported

These should be introduced deliberately rather than hard-coded throughout the UI/native bridge.

## 5. Error handling

The chat UI currently catches platform/general exceptions and logs them. A production application should expose useful, user-facing error states.

## 6. Long-running inference

LLM inference can be computationally expensive. The native inference path should eventually be designed so that long-running generation does not block the UI and can support cancellation.

---

# Suggested future architecture

As the project grows, a more complete architecture could look like:

```text
                         ModelGo
                            │
             ┌──────────────┼──────────────┐
             │              │              │
          UI Layer       State Layer    Storage Layer
             │              │              │
        ┌────┴────┐      Provider       GGUF files
        │         │          │
      Chat     Models        │
        │         │          │
        └────┬────┘──────────┘
             │
             ▼
       Inference Service
             │
             ▼
        MethodChannel
             │
             ▼
       Native JNI/bridge
             │
             ▼
          llama.cpp
             │
             ▼
        GGUF model
```

This would make it easier to separate:

- UI concerns
- model lifecycle
- model storage
- inference configuration
- native resource management
- streaming token output
- conversation history

---

# Potential roadmap

The project can evolve in roughly these stages:

### Phase 1 — Foundation

- [x] Flutter application shell
- [x] Android application module
- [x] Native CMake integration
- [x] llama.cpp source integration
- [x] GGUF model discovery
- [x] Initial chat-to-native bridge

### Phase 2 — Real model management

- [ ] Real model downloads
- [ ] Download progress
- [ ] Download cancellation
- [ ] Model deletion
- [ ] Model metadata
- [ ] Model selection
- [ ] Model validation

### Phase 3 — Complete inference

- [ ] Load selected GGUF model
- [ ] Create/release llama.cpp model contexts
- [ ] Prompt formatting
- [ ] Token generation
- [ ] Streaming responses
- [ ] Stop/cancel generation
- [ ] Proper native error propagation

### Phase 4 — Chat experience

- [ ] Persistent conversation history
- [ ] User/assistant message widgets
- [ ] Markdown rendering
- [ ] Code-block rendering
- [ ] Copy response
- [ ] Regenerate response
- [ ] Stop generation
- [ ] Clear conversation

### Phase 5 — Mobile optimization

- [ ] Memory-aware model loading
- [ ] Thread configuration
- [ ] Backend selection
- [ ] Performance metrics
- [ ] Context management
- [ ] Model unloading
- [ ] Battery/thermal considerations

### Phase 6 — Advanced features

Potential future capabilities include:

- Multiple conversations
- Model profiles
- Generation presets
- System prompts
- Prompt templates
- Model metadata inspection
- Quantization information
- Token/speed statistics
- Importing models from device storage
- Model deletion and storage management

---

# Troubleshooting native builds

When a native build fails, start with the first compiler error.

For example:

```text
FAILED: .../something.cpp.o
...
error: ...
```

The final message:

```text
Execution failed for task ':app:buildCMake...'
```

is usually only the Gradle wrapper around the underlying CMake/Ninja/compiler failure.

Useful commands include:

```bash
flutter clean
flutter pub get
flutter build apk --debug
```

and:

```bash
flutter run -v
```

For ABI-specific problems, inspect the actual CMake build directory and compiler command shown in the Gradle output.

Do not change architecture-related source code merely because an architecture name appears somewhere inside the vendored llama.cpp tree. First establish which Gradle module, CMake target, and generated native build configuration are actually producing the failing target.

---

# Design principles

ModelGo is built around several useful principles:

### Local-first inference

Models are intended to run locally on the Android device rather than requiring a remote inference server.

### Separation of concerns

Flutter handles application/UI responsibilities while C/C++ handles the computationally intensive native inference layer.

### Native performance

`llama.cpp` is used instead of implementing an LLM inference engine in Dart.

### GGUF-based model management

The application uses GGUF files as its local model artifacts.

### Minimal native build

The application's CMake configuration disables unnecessary llama.cpp components to keep the native application focused on inference.

---

# Security and privacy considerations

A local inference architecture can reduce the need to send prompts to a remote service.

However, local inference does **not automatically guarantee complete privacy**. The application may still use network access for model downloads or future services.

When implementing production model downloads:

- Use HTTPS.
- Validate download URLs.
- Handle partial downloads safely.
- Verify downloaded files where appropriate.
- Avoid logging prompts or model data unnecessarily.
- Store sensitive application data carefully.
- Avoid embedding API keys in the Flutter application.

---

# Performance considerations

Running an LLM directly on an Android device is substantially different from running one on a desktop GPU.

Important constraints include:

- RAM availability
- device thermal limits
- CPU performance
- native memory consumption
- model quantization
- context size
- number of inference threads
- Android ABI
- llama.cpp backend configuration

Model size alone is not sufficient to determine whether a model will run well. Context size and runtime memory requirements also matter.

A future performance layer should expose useful measurements such as:

```text
Model
Context size
Generation speed
Prompt processing speed
Memory usage
Tokens generated
Generation duration
```

---

# Repository maintenance

Because llama.cpp is vendored inside this repository, updating it should be treated as a deliberate dependency update.

Before updating:

1. Record the current llama.cpp revision.
2. Confirm the Android CMake integration still applies.
3. Build the native library.
4. Test GGUF model loading.
5. Test inference.
6. Check Android ABI builds.
7. Check runtime memory usage.

Avoid making unrelated changes to the vendored llama.cpp source when troubleshooting the ModelGo application.

---

# License

The ModelGo project's license should be added here once the repository has an explicit project license.

The repository also contains the `llama.cpp` source tree. `llama.cpp` has its own licensing terms, which should be reviewed and preserved when distributing the application.

---

# Project status

ModelGo is currently a **work in progress** focused on building a local LLM experience for Android using Flutter and llama.cpp.

The core direction is:

```text
Flutter UI
   +
Dart application logic
   +
local GGUF model management
   +
Android C/C++ bridge
   +
llama.cpp
   =
local Android LLM application
```

The current codebase establishes the foundation for this architecture while several production features—especially real model downloading, complete model lifecycle management, persistent chat history, and a fully developed inference workflow—remain to be implemented.
