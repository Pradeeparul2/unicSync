# Antigravity AI Project Rules: unicSync (Flutter Companion App)

## 1. Project Context & Vision
- **Project**: `unicSync` is the official cross-platform Flutter companion application for the **Rust Edge Sync Engine (`rSync`)** and the **Autonomous USB-C Smart Drive**.
- **Target Platforms**: Desktop (**macOS**, **Windows**, **Linux**) with system tray/menu bar integration, and Mobile (**Android**, **iOS**).
- **Core Role**: Acts as the centralized UI control hub for managing sync queues, multi-cloud destination profiles (AWS S3, Cloudflare R2, Google Drive, WebDAV), storage tiering (Local, Synced, Cloud-Only), zero-knowledge encryption vaults, and hardware companion diagnostics.

---

## 2. Architectural Boundaries (Strictly Enforced)
- **Zero Business Logic Duplication**: The Flutter app is a pure presentation and orchestration layer. All chunking, hashing, encryption, SQLite WAL transactions, and cloud network streaming are handled by the Rust `sync-agent` engine.
- **Unified Engine Communication**:
  - The Flutter app communicates with the `sync-agent` via its high-performance local REST & WebSocket API (`http://127.0.0.1:8080/api` on localhost, or `http://192.168.7.2:8080/api` when plugged into the USB-C Smart Drive).
- **Clean Architecture Directory Structure**:
  - `lib/core/`: Network clients, error handling, themes, constants, utilities.
  - `lib/features/dashboard/`: Real-time bandwidth, transfer ring charts, active chunk queue.
  - `lib/features/files/`: File browser with tiering badges (💾 Local, ✅ Synced, ☁️ CloudOnly), evict/hydrate actions.
  - `lib/features/profiles/`: Multi-cloud profile wizards (S3, GDrive, WebDAV, Mock).
  - `lib/features/security/`: PIN verification, lockout protection, and E2EE master passphrase vault.
  - `lib/features/hardware/`: USB Smart Drive detection, storage health, firmware version, and power-cut diagnostics.

---

## 3. Flutter & Dart Coding Standards
1. **Sound Null Safety & Strong Typing**:
   - Never use `dynamic` unless explicitly serializing unknown raw JSON.
   - Use immutable data models (`freezed` or standard immutable `@immutable` classes with `copyWith`).
2. **State Management**:
   - Use **Riverpod (v2.x)** as the primary reactive state management library.
   - Separate UI widgets from business logic providers (`StateNotifier` / `AsyncNotifier`).
3. **Responsive & Adaptive Design**:
   - Desktop layout: Sidebar navigation, resizable data tables, system tray popover, shortcut keys.
   - Mobile layout: Bottom navigation bar, swipe gestures, pull-to-refresh, bottom sheet dialogs.
4. **Resilience & Polling Discipline**:
   - When polling the `sync-agent` REST API for status updates, use adaptive intervals (1 sec while syncing, 5 sec when idle).
   - Gracefully handle connection drops when the USB-C Smart Drive is unplugged.

---

## 4. Development Commands & References
- Run `flutter pub get` to install dependencies.
- Run `flutter run -d macos` (or `linux`, `windows`, `chrome`) for desktop testing.
- Run `flutter analyze` and `flutter test` before committing.
- Companion Rust backend repository: `../rSync`.
