# Retro Mesh Console 🎮✨

A high-performance, self-contained cross-platform mobile application built with **Flutter (Dart)** that transforms your mobile devices into a localized video game emulation console and wireless gamepad controller mesh network.

It projects an independent gameplay viewport to a television (via native Android Cast SDK / iOS AirPlay UIWindow structures) while transforming the handheld smartphone screen into an ultra-low-latency wireless touch controller.

---

## ⚡ Key Capabilities

* **Symmetrical Dual-Role Entry Gate**: A single unified binary package that branches execution on boot based on user selection: **Host Console System** or **Join Controller Squad**.
* **Smart Core Routing**: Hides the complexities of "emulation cores" from the user. You just pick a game file, and the internal `CoreRouter` automatically loads the optimal engine based on the extension (`.nes`, `.smc`, `.sfc`, `.md`, `.gen`, `.gba`, `.iso`, `.cue`, `.img`, `.bin`).
* **Dynamic Controller Layouts**: The virtual gamepad automatically morphs to match the console you are playing (e.g., standard D-Pad + A/B for NES, 6-button layout for Sega Genesis, 4-button + shoulder triggers for SNES/GBA/PS1).
* **Native C++ Audio Pipeline (miniaudio)**: Achieves perfect, zero-latency audio-video sync by completely bypassing Dart/Kotlin overhead and MethodChannels. The FFI Libretro core pushes audio frame batches directly into a C++ ring buffer powered by `miniaudio`, instantly consumed by Android's AAudio and iOS's CoreAudio layers.
* **Dart FFI Libretro Core Wrapper**: Direct C/C++ FFI bindings to load compiled emulator binaries (`.so` / `.dylib`), managing native callbacks for video refresh frames, audio batch samples, and input polling.
* **Player 1 (Console Host Mode)**: Serves as the central computing unit. P1 selects a local ROM, boots an embedded `HttpServer` on port 3000, starts an active mDNS broadcast (`_retroconsole._tcp`), and maps virtual touch inputs directly to Port 1 of the FFI Libretro core.
* **Player 2 (Peripheral Client Mode)**: Automatically scans the local network via mDNS service discovery, establishes a persistent `WebSocketChannel` directly to P1, and acts as a touch gamepad mapped to Port 2 of the host's emulator core.
* **Low-Latency 2-Byte Input Protocol**: Bypasses text-based JSON encoding and serialization overhead to transmit real-time button transitions.
* **Dual-Screen TV Projection**: Uses method channels to allocate native presentation boundaries:
  * **Android**: Renders on external displays using `android.app.Presentation` dialog views.
  * **iOS**: Listens for AirPlay connections to display root controllers in a secondary `UIWindow`.
* **Telemetry HUD**: Displays connection states (glowing green/red status chips), battery charge levels, and network connectivity indicators for both devices natively overlaid on the Host Gamepad interface.

---

## 📁 Project Architecture

* **[`lib/main.dart`](file:///c:/Users/gagan/Projects/retro-mesh-console/lib/main.dart)**: Bootstraps the material MaterialApp, configures a retro dark theme, and loads the role selection gate.
* **[`lib/emulation/libretro.dart`](file:///c:/Users/gagan/Projects/retro-mesh-console/lib/emulation/libretro.dart)**: Implements Dart FFI bindings for Libretro cores, manages input buffers for Port 1/2, handles the 60 FPS game loop, and hosts the graphics fallback loop.
* **[`lib/emulation/core_router.dart`](file:///c:/Users/gagan/Projects/retro-mesh-console/lib/emulation/core_router.dart)**: The Smart Core Router that maps file extensions to emulator cores (e.g., `snes9x`, `pcsx_rearmed`).
* **[`android/app/src/main/cpp/native-audio.cpp`](file:///c:/Users/gagan/Projects/retro-mesh-console/android/app/src/main/cpp/native-audio.cpp)** & **[`ios/Runner/native-audio.mm`](file:///c:/Users/gagan/Projects/retro-mesh-console/ios/Runner/native-audio.mm)**: Pure native C++ audio drivers using `miniaudio`.
* **[`lib/network/host_server.dart`](file:///c:/Users/gagan/Projects/retro-mesh-console/lib/network/host_server.dart)**: Spins up the local server, manages Player 2 client sockets, and merges telemetry metrics.
* **[`lib/network/client_socket.dart`](file:///c:/Users/gagan/Projects/retro-mesh-console/lib/network/client_socket.dart)**: Discovers the console over mDNS, runs input event deduplication caching, and maintains the telemetry status interval.
* **[`lib/views/role_gate.dart`](file:///c:/Users/gagan/Projects/retro-mesh-console/lib/views/role_gate.dart)**: Welcome gate layout featuring visual selector cards and storage picker hooks.
* **[`lib/views/gamepad_deck.dart`](file:///c:/Users/gagan/Projects/retro-mesh-console/lib/views/gamepad_deck.dart)**: Symmetrical touch controller deck featuring dynamic layouts, zero-delay multi-touch `Listener` widgets, platform-channel presentation hooks, and a live preview of the TV Canvas and Telemetry HUD.

---

## 🛠️ Getting Started & Run Guide

### 1. Prerequisite: Place Emulator Core Binaries
Place your compiled Libretro core shared libraries in the `assets/cores/` directory:
* **Android**: `assets/cores/fceumm_libretro_android.so` (NES), `assets/cores/snes9x_libretro_android.so` (SNES), `assets/cores/genesis_plus_gx_libretro_android.so` (Sega Genesis)
* **iOS**: Cores must be compiled statically and linked in the Xcode project workspace.

### 2. Build & Run the App
Connect two mobile devices to the **same Wi-Fi network**.

* **For Android**:
  ```bash
  flutter run -d <device_1_id> # Player 1 (Console Host)
  flutter run -d <device_2_id> # Player 2 (Client Controller)
  ```
* **For iOS** (Requires macOS & Xcode):
  ```bash
  flutter run -d <device_id>
  ```

---

## ⚙️ Mobile OS Configuration Details

Local network broadcasting (mDNS) and dual-device communications are fully configured in the build manifests:

### Android Manifest (`android/app/src/main/AndroidManifest.xml`)
Added permissions for internet connectivity and multicast locks:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
```

### iOS Info (`ios/Runner/Info.plist`)
Registered Bonjour service identifiers to pass iOS 14+ local network discovery sandboxing checks:
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Retro Mesh Console uses the local network to discover and connect controllers for multiplayer gameplay.</string>
<key>NSBonjourServices</key>
<array>
    <string>_retroconsole._tcp</string>
</array>
```
